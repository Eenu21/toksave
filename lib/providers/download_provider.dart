import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/url_utils.dart';
import '../models/download_progress.dart';
import '../models/download_record.dart';
import '../models/saved_creator.dart';
import '../models/tiktok_creator.dart';
import '../models/tiktok_download_option.dart';
import '../models/tiktok_video.dart';
import '../services/gallery_service.dart';
import '../services/storage_service.dart';

class DownloadProvider extends ChangeNotifier {
  DownloadProvider() : _storageService = StorageService() {
    _isLoading = true;
  }

  final StorageService _storageService;
  final GalleryService _galleryService = GalleryService();
  final http.Client _downloadClient = http.Client();
  final List<DownloadRecord> _downloads = <DownloadRecord>[];
  final List<SavedCreator> _savedCreators = <SavedCreator>[];
  bool _isLoading = false;
  bool _isBusy = false;
  bool _isCancelled = false;
  DownloadProgress _currentProgress = const DownloadProgress();
  DownloadRecord? _latestDownload;
  TikTokCreator? _creator;
  List<TikTokVideo> _creatorVideos = [];
  String? _creatorCursor;
  bool _creatorHasMore = false;
  bool _isLoadingCreator = false;
  int _batchIndex = 0;
  int _batchCount = 0;
  String? _loadedCreatorUsername;

  List<DownloadRecord> get downloads =>
      List<DownloadRecord>.unmodifiable(_downloads);
  List<SavedCreator> get savedCreators =>
      List<SavedCreator>.unmodifiable(_savedCreators);
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  DownloadProgress get currentProgress => _currentProgress;
  DownloadRecord? get latestDownload => _latestDownload;
  TikTokCreator? get creator => _creator;
  List<TikTokVideo> get creatorVideos =>
      List<TikTokVideo>.unmodifiable(_creatorVideos);
  bool get hasMoreCreatorVideos => _creatorHasMore;
  bool get isLoadingCreator => _isLoadingCreator;
  String get batchProgressLabel =>
      _batchCount > 0 ? 'Video $_batchIndex of $_batchCount' : '';

  Future<void> initialize() async {
    await _storageService.initialize();
    await refreshDownloads();
  }

  Future<void> refreshDownloads() async {
    _isLoading = true;
    notifyListeners();
    try {
      final records = await _storageService.loadDownloads();
      final creators = await _storageService.loadSavedCreators();
      _downloads
        ..clear()
        ..addAll(records);
      _savedCreators
        ..clear()
        ..addAll(creators);
      _latestDownload = records.isNotEmpty ? records.first : null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _rememberCreator(DownloadRecord record) {
    final username = record.authorId.replaceFirst(RegExp(r'^@'), '').trim();
    if (username.isEmpty) return;

    final existingIndex = _savedCreators.indexWhere(
      (creator) => creator.username.toLowerCase() == username.toLowerCase(),
    );
    final previousCount = existingIndex < 0
        ? 0
        : _savedCreators[existingIndex].downloadCount;
    if (existingIndex >= 0) _savedCreators.removeAt(existingIndex);
    _savedCreators.insert(
      0,
      SavedCreator(
        username: username,
        displayName: record.author,
        avatarUrl: record.authorAvatarUrl,
        profileUrl: 'https://www.tiktok.com/@$username',
        lastDownloadedAt: record.downloadedAt,
        downloadCount: previousCount + 1,
      ),
    );
    notifyListeners();
  }

  Future<TikTokVideo> resolveVideo(String rawUrl) async {
    final normalizedUrl = normalizeTikTokUrl(rawUrl);
    if (!isTikTokUrl(normalizedUrl)) {
      throw const AppException(
        message: 'Invalid TikTok link',
        userMessage: 'Invalid TikTok link',
      );
    }

    final result = await _storageService.fetchVideoMetadata(normalizedUrl);
    if (result == null) {
      throw const AppException(
        message: 'Could not retrieve this video.',
        userMessage:
            'Couldn\'t retrieve this video. Please check the link and try again.',
      );
    }
    return result;
  }

  Future<void> loadCreatorVideos(TikTokVideo seedVideo) async {
    final username = seedVideo.authorId.isEmpty
        ? seedVideo.author
        : seedVideo.authorId;
    final normalizedUsername = username.replaceFirst(RegExp(r'^@'), '');
    if (_loadedCreatorUsername == normalizedUsername &&
        _creatorVideos.isNotEmpty) {
      return;
    }
    _isLoadingCreator = true;
    _creator = TikTokCreator(
      username: normalizedUsername,
      displayName: seedVideo.author,
      avatarUrl: seedVideo.authorAvatarUrl,
    );
    _creatorVideos = [];
    _creatorCursor = null;
    _creatorHasMore = false;
    notifyListeners();
    try {
      final page = await _storageService.fetchCreatorVideos(username: username);
      _creator = page.creator;
      _creatorVideos = List<TikTokVideo>.of(page.videos);
      if (!_creatorVideos.any((video) => video.id == seedVideo.id)) {
        _creatorVideos.insert(0, seedVideo);
      }
      _creatorCursor = page.nextCursor;
      _creatorHasMore = page.hasMore;
      _loadedCreatorUsername = normalizedUsername;
    } on AppException {
      _creatorVideos = [seedVideo];
      rethrow;
    } finally {
      _isLoadingCreator = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreCreatorVideos() async {
    final creator = _creator;
    final cursor = _creatorCursor;
    if (creator == null ||
        cursor == null ||
        !_creatorHasMore ||
        _isLoadingCreator) {
      return;
    }

    _isLoadingCreator = true;
    notifyListeners();
    try {
      final page = await _storageService.fetchCreatorVideos(
        username: creator.username,
        cursor: cursor,
      );
      final knownIds = _creatorVideos.map((video) => video.id).toSet();
      _creatorVideos.addAll(
        page.videos.where((video) => knownIds.add(video.id)),
      );
      _creatorCursor = page.nextCursor;
      _creatorHasMore = page.hasMore;
    } finally {
      _isLoadingCreator = false;
      notifyListeners();
    }
  }

  Future<void> downloadBatch(
    List<TikTokVideo> videos,
    TikTokDownloadFormat format,
  ) async {
    if (_isBusy || videos.isEmpty) return;
    _batchCount = videos.length;
    try {
      for (var index = 0; index < videos.length; index++) {
        final video = videos[index];
        final option = video.optionFor(format);
        if (option == null) {
          throw AppException(
            message:
                'The ${format.name} format is unavailable for ${video.id}.',
            userMessage:
                'The selected format is unavailable for one of the selected videos.',
          );
        }
        _batchIndex = index + 1;
        notifyListeners();
        await downloadVideo(video, option: option);
      }
    } finally {
      _batchIndex = 0;
      _batchCount = 0;
      notifyListeners();
    }
  }

  Future<void> downloadVideo(
    TikTokVideo video, {
    TikTokDownloadOption? option,
  }) async {
    final selectedOption =
        option ??
        (video.downloadOptions.isEmpty ? null : video.downloadOptions.first);
    if (selectedOption == null) {
      throw const AppException(
        message: 'No downloadable format was provided.',
        userMessage: 'No downloadable format is available for this video.',
      );
    }
    _isBusy = true;
    _isCancelled = false;
    _currentProgress = DownloadProgress(
      message: _batchCount > 0
          ? 'Preparing video $_batchIndex of $_batchCount...'
          : 'Preparing...',
    );
    notifyListeners();

    File? destination;
    String? galleryUri;
    var savedToHistory = false;
    try {
      final dir = await _ensureDownloadDirectory();
      final downloadId = const Uuid().v4();
      final fileName =
          '${sanitizeFileName(video.title)}_${sanitizeFileName(video.id)}_${selectedOption.format.name}_$downloadId.${selectedOption.extension}';
      destination = File('${dir.path}/$fileName');
      final request = http.Request('GET', Uri.parse(selectedOption.url));
      try {
        final streamed = await _downloadClient
            .send(request)
            .timeout(const Duration(seconds: 20));
        if (streamed.statusCode != 200) {
          throw AppException(
            message: 'Download failed with HTTP ${streamed.statusCode}',
            userMessage:
                'The video could not be downloaded right now. Please try again.',
          );
        }

        final sink = destination.openWrite();
        var received = 0;
        final total = streamed.contentLength ?? 0;
        var lastReportedPercent = -1;
        final notificationClock = Stopwatch()..start();
        try {
          await for (final chunk in streamed.stream) {
            if (_isCancelled) {
              throw const AppException(
                message: 'Download cancelled',
                userMessage: 'Download cancelled.',
              );
            }

            sink.add(chunk);
            received += chunk.length;
            _currentProgress = DownloadProgress(
              state: DownloadState.downloading,
              receivedBytes: received,
              totalBytes: total,
              message: 'Downloading...',
            );
            final percent = total > 0 ? (received * 100 ~/ total) : -1;
            if (percent != lastReportedPercent ||
                notificationClock.elapsedMilliseconds >= 120) {
              notifyListeners();
              lastReportedPercent = percent;
              notificationClock
                ..reset()
                ..start();
            }
          }
          await sink.flush();
          notifyListeners();
        } finally {
          await sink.close();
        }
      } on TimeoutException {
        throw const AppException(
          message: 'The video download request timed out.',
          userMessage: 'The download took too long to start. Please try again.',
        );
      }

      if (_isCancelled) {
        throw const AppException(
          message: 'Download cancelled',
          userMessage: 'Download cancelled.',
        );
      }

      if (!await destination.exists()) {
        throw AppException(
          message: 'Could not save the video to the device.',
          userMessage: 'The video could not be saved to your device storage.',
        );
      }

      _currentProgress = const DownloadProgress(
        state: DownloadState.saving,
        message: 'Saving to Gallery...',
      );
      notifyListeners();
      final downloadedBytes = await destination.length();
      _currentProgress = DownloadProgress(
        state: DownloadState.saving,
        receivedBytes: downloadedBytes,
        totalBytes: downloadedBytes,
        message: 'Saving to Gallery...',
      );
      notifyListeners();
      galleryUri = await _galleryService.saveMedia(
        filePath: destination.path,
        displayName: fileName,
        isAudio: selectedOption.isAudio,
      );

      final record = DownloadRecord(
        id: downloadId,
        title: video.title,
        filePath: destination.path,
        thumbnailUrl: video.thumbnailUrl,
        originalUrl: video.sourceUrl,
        fileSizeBytes: downloadedBytes,
        downloadedAt: DateTime.now(),
        author: video.author,
        durationSeconds: video.durationSeconds,
        galleryUri: galleryUri,
        mediaType: selectedOption.isAudio ? 'audio' : 'video',
        authorId: _creatorUsername(video),
        authorAvatarUrl: video.authorAvatarUrl,
      );

      await _storageService.saveDownload(record);
      savedToHistory = true;
      _rememberCreator(record);
      _downloads.insert(0, record);
      _latestDownload = record;
      _currentProgress = DownloadProgress(
        state: DownloadState.completed,
        receivedBytes: record.fileSizeBytes,
        totalBytes: record.fileSizeBytes,
        message: 'Completed',
      );
      notifyListeners();
    } on AppException catch (error) {
      if (!savedToHistory) {
        await _removeIncompleteDownload(destination, galleryUri);
      }
      _currentProgress = DownloadProgress(
        state: error.message.contains('cancel')
            ? DownloadState.cancelled
            : DownloadState.failed,
        message: error.userMessage ?? 'Couldn\'t download the video',
      );
      notifyListeners();
      rethrow;
    } catch (_) {
      if (!savedToHistory) {
        await _removeIncompleteDownload(destination, galleryUri);
      }
      _currentProgress = const DownloadProgress(
        state: DownloadState.failed,
        message: 'Network connection failed. Please try again.',
      );
      notifyListeners();
      throw const AppException(
        message: 'Download or save failure',
        userMessage:
            'The video could not be downloaded or saved. Please try again.',
      );
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  String _creatorUsername(TikTokVideo video) {
    final username = video.authorId.replaceFirst(RegExp(r'^@'), '').trim();
    if (username.isNotEmpty) return username;
    final match = RegExp(
      r'(?:^|\.tiktok\.com)/@([^/?]+)',
      caseSensitive: false,
    ).firstMatch(video.sourceUrl);
    return match?.group(1) ?? '';
  }

  Future<void> _removeIncompleteDownload(
    File? destination,
    String? galleryUri,
  ) async {
    await _galleryService.deleteMedia(galleryUri);
    if (destination != null && await destination.exists()) {
      await destination.delete();
    }
  }

  Future<Directory> _ensureDownloadDirectory() async {
    if (Platform.isAndroid) {
      final externalRoot = await getExternalStorageDirectory();
      final basePath = externalRoot != null
          ? externalRoot.path
          : (await getApplicationDocumentsDirectory()).path;
      final target = Directory('$basePath/Movies/TokSave');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      return target;
    }

    final appDocs = await getApplicationDocumentsDirectory();
    final target = Directory('${appDocs.path}/TokSave');
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    return target;
  }

  Future<void> deleteDownload(String id) async {
    final record = _downloads.firstWhere(
      (item) => item.id == id,
      orElse: () => _downloads.first,
    );
    await _galleryService.deleteMedia(record.galleryUri);
    final file = File(record.filePath);
    if (await file.exists()) {
      await file.delete();
    }
    await _storageService.deleteDownload(id);
    _downloads.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  Future<void> deleteAllDownloads() async {
    for (final item in _downloads) {
      await _galleryService.deleteMedia(item.galleryUri);
      final file = File(item.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    await _storageService.deleteAllDownloads();
    _downloads.clear();
    notifyListeners();
  }

  Future<void> cancelDownload() async {
    _isCancelled = true;
    _currentProgress = const DownloadProgress(
      state: DownloadState.cancelled,
      message: 'Cancelling...',
    );
    notifyListeners();
  }

  Future<void> shareDownload(DownloadRecord record) async {
    await SharePlus.instance.share(
      ShareParams(files: [XFile(record.filePath)], text: 'Shared from TokSave'),
    );
  }

  @override
  void dispose() {
    _downloadClient.close();
    _storageService.close();
    super.dispose();
  }
}
