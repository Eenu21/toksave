import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/url_utils.dart';
import '../models/tiktok_creator.dart';
import '../models/tiktok_creator_page.dart';
import '../models/tiktok_download_option.dart';
import '../models/download_record.dart';
import '../models/frequent_creator.dart';
import '../models/recent_video.dart';
import '../models/saved_creator.dart';
import '../models/tiktok_video.dart';

class StorageService {
  Database? _database;
  final http.Client _httpClient = http.Client();
  static const _requestTimeout = Duration(seconds: 12);

  Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'toksave.db');
    _database = await openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE downloads (
            id TEXT PRIMARY KEY,
            title TEXT,
            filePath TEXT,
            thumbnailUrl TEXT,
            originalUrl TEXT,
            fileSizeBytes INTEGER,
            downloadedAt INTEGER,
            author TEXT,
            durationSeconds INTEGER,
            galleryUri TEXT,
            mediaType TEXT NOT NULL DEFAULT 'video',
            authorId TEXT NOT NULL DEFAULT '',
            authorAvatarUrl TEXT NOT NULL DEFAULT ''
          )
        ''');
        await _createCreatorsTable(db);
        await _createRecentTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE downloads ADD COLUMN galleryUri TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE downloads ADD COLUMN mediaType TEXT NOT NULL DEFAULT 'video'",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE downloads ADD COLUMN authorId TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE downloads ADD COLUMN authorAvatarUrl TEXT NOT NULL DEFAULT ''",
          );
          await _createCreatorsTable(db);
          await db.execute('''
            INSERT INTO saved_creators (
              username, displayName, avatarUrl, profileUrl, lastDownloadedAt, downloadCount
            )
            SELECT
              authorId,
              author,
              authorAvatarUrl,
              'https://www.tiktok.com/@' || authorId,
              MAX(downloadedAt),
              COUNT(*)
            FROM downloads
            WHERE authorId != ''
            GROUP BY authorId
          ''');
        }
        if (oldVersion < 5) {
          await _createRecentTables(db);
        }
      },
    );
  }

  Future<void> _createCreatorsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE saved_creators (
        username TEXT PRIMARY KEY,
        displayName TEXT NOT NULL,
        avatarUrl TEXT NOT NULL DEFAULT '',
        profileUrl TEXT NOT NULL DEFAULT '',
        lastDownloadedAt INTEGER NOT NULL,
        downloadCount INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createRecentTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE recent_videos (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author TEXT NOT NULL,
        thumbnailUrl TEXT NOT NULL DEFAULT '',
        sourceUrl TEXT NOT NULL,
        authorId TEXT NOT NULL DEFAULT '',
        authorAvatarUrl TEXT NOT NULL DEFAULT '',
        durationSeconds INTEGER NOT NULL DEFAULT 0,
        lastViewedAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE creator_visits (
        username TEXT PRIMARY KEY,
        displayName TEXT NOT NULL,
        avatarUrl TEXT NOT NULL DEFAULT '',
        profileUrl TEXT NOT NULL,
        visitCount INTEGER NOT NULL DEFAULT 0,
        lastVisitedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<List<DownloadRecord>> loadDownloads() async {
    final db = _database;
    if (db == null) {
      await initialize();
    }
    final rows = await _database!.query(
      'downloads',
      orderBy: 'downloadedAt DESC',
    );
    return rows.map((row) => DownloadRecord.fromMap(row)).toList();
  }

  Future<void> saveDownload(
    DownloadRecord record, {
    required TikTokVideo video,
  }) async {
    final database = _database!;
    await database.transaction((txn) async {
      await txn.insert(
        'downloads',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      final username = record.authorId.replaceFirst(RegExp(r'^@'), '').trim();
      if (username.isNotEmpty &&
          !record.author.startsWith('http') &&
          record.author != 'Unknown creator') {
        final existing = await txn.query(
          'saved_creators',
          columns: ['downloadCount'],
          where: 'username = ?',
          whereArgs: [username],
          limit: 1,
        );
        final count = existing.isEmpty
            ? 1
            : (existing.first['downloadCount'] as int) + 1;
        await txn.insert('saved_creators', {
          'username': username,
          'displayName': record.author,
          'avatarUrl': record.authorAvatarUrl,
          'profileUrl': 'https://www.tiktok.com/@$username',
          'lastDownloadedAt': record.downloadedAt.millisecondsSinceEpoch,
          'downloadCount': count,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert('recent_videos', {
        'id': video.id,
        'title': video.title,
        'author': video.author,
        'thumbnailUrl': video.thumbnailUrl,
        'sourceUrl': video.sourceUrl,
        'authorId': video.authorId,
        'authorAvatarUrl': video.authorAvatarUrl,
        'durationSeconds': video.durationSeconds,
        'lastViewedAt': record.downloadedAt.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.rawDelete('''
        DELETE FROM recent_videos
        WHERE id NOT IN (
          SELECT id FROM recent_videos
          ORDER BY lastViewedAt DESC
          LIMIT 30
        )
      ''');
    });
  }

  Future<List<SavedCreator>> loadSavedCreators() async {
    final rows = await _database!.query(
      'saved_creators',
      orderBy: 'lastDownloadedAt DESC',
    );
    return rows.map(SavedCreator.fromMap).toList(growable: false);
  }

  Future<void> saveRecentVideo(TikTokVideo video) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await _database!.transaction((txn) async {
      await txn.insert('recent_videos', {
        'id': video.id,
        'title': video.title,
        'author': video.author,
        'thumbnailUrl': video.thumbnailUrl,
        'sourceUrl': video.sourceUrl,
        'authorId': video.authorId,
        'authorAvatarUrl': video.authorAvatarUrl,
        'durationSeconds': video.durationSeconds,
        'lastViewedAt': timestamp,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.rawDelete('''
        DELETE FROM recent_videos
        WHERE id NOT IN (
          SELECT id FROM recent_videos
          ORDER BY lastViewedAt DESC
          LIMIT 30
        )
      ''');
    });
  }

  Future<List<RecentVideo>> loadRecentVideos() async {
    final rows = await _database!.query(
      'recent_videos',
      orderBy: 'lastViewedAt DESC',
      limit: 12,
    );
    return rows.map(RecentVideo.fromMap).toList(growable: false);
  }

  Future<FrequentCreator> recordCreatorVisit({
    required String username,
    required String displayName,
    required String avatarUrl,
  }) async {
    final normalizedUsername = username.replaceFirst(RegExp(r'^@'), '').trim();
    if (normalizedUsername.isEmpty) {
      throw const AppException(
        message: 'The TikTok creator could not be identified.',
        userMessage: 'Couldn\'t identify this creator.',
      );
    }

    final now = DateTime.now();
    return _database!.transaction((txn) async {
      final existing = await txn.query(
        'creator_visits',
        columns: ['visitCount', 'avatarUrl'],
        where: 'username = ?',
        whereArgs: [normalizedUsername],
        limit: 1,
      );
      final visitCount = existing.isEmpty
          ? 1
          : (existing.first['visitCount'] as int) + 1;
      final existingAvatar = existing.isEmpty
          ? ''
          : existing.first['avatarUrl'] as String;
      await txn.insert('creator_visits', {
        'username': normalizedUsername,
        'displayName': displayName,
        'avatarUrl': avatarUrl.isNotEmpty ? avatarUrl : existingAvatar,
        'profileUrl': 'https://www.tiktok.com/@$normalizedUsername',
        'visitCount': visitCount,
        'lastVisitedAt': now.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
      final rows = await txn.query(
        'creator_visits',
        where: 'username = ?',
        whereArgs: [normalizedUsername],
        limit: 1,
      );
      return FrequentCreator.fromMap(rows.single);
    });
  }

  Future<List<FrequentCreator>> loadFrequentCreators() async {
    final rows = await _database!.query(
      'creator_visits',
      orderBy: 'visitCount DESC, lastVisitedAt DESC',
      limit: 12,
    );
    return rows.map(FrequentCreator.fromMap).toList(growable: false);
  }

  Future<void> deleteDownload(String id) async {
    await _database!.delete('downloads', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteAllDownloads() async {
    await _database!.delete('downloads');
  }

  Future<void> close() async {
    _httpClient.close();
    await _database?.close();
    _database = null;
  }

  Future<TikTokVideo?> fetchVideoMetadata(String rawUrl) async {
    final normalizedUrl = normalizeTikTokUrl(rawUrl);
    final response = await _post(
      Uri.parse('https://www.tikwm.com/api/'),
      {'url': normalizedUrl},
      timeoutMessage: 'Video details request timed out.',
    );

    if (response.statusCode == 403) {
      throw const AppException(
        message: 'TikWM returned HTTP 403 for video details.',
        userMessage:
            'The video service is refusing requests right now. Please try again later.',
      );
    }
    if (response.statusCode != 200) {
      throw AppException(
        message:
            'TikWM returned HTTP ${response.statusCode} for video details.',
        userMessage: 'Could not retrieve this video. Please try again.',
      );
    }

    if (response.body.isEmpty) {
      return null;
    }

    final payload = _decodePayload(response.body);
    final data = payload['data'];
    if (payload['code'] != 0 || data is! Map) {
      throw const AppException(
        message: 'Could not retrieve this video.',
        userMessage:
            'Couldn\'t retrieve this video. Please check the link and try again.',
      );
    }

    final video = _parseVideo(Map<String, dynamic>.from(data));
    if (video.downloadOptions.isEmpty) {
      throw const AppException(
        message: 'This video is not available for download.',
        userMessage: 'This video isn\'t available for downloading.',
      );
    }
    return video.copyWith(sourceUrl: normalizedUrl);
  }

  Future<TikTokCreatorPage> fetchCreatorVideos({
    required String username,
    String? cursor,
  }) async {
    final normalizedUsername = username.replaceFirst(RegExp(r'^@'), '').trim();
    if (normalizedUsername.isEmpty) {
      throw const AppException(
        message: 'The TikTok creator could not be identified.',
        userMessage: 'Couldn\'t identify this creator from the video link.',
      );
    }

    final response = await _post(
      Uri.parse('https://www.tikwm.com/api/user/posts/'),
      {'unique_id': normalizedUsername, 'count': '12', 'cursor': cursor ?? '0'},
      timeoutMessage: 'Creator videos request timed out.',
    );
    if (response.statusCode == 403) {
      throw const AppException(
        message: 'TikWM returned HTTP 403 for creator videos.',
        userMessage:
            'TikWM is refusing public creator-video lists (HTTP 403). You can still add video links below to build a batch.',
      );
    }
    if (response.statusCode != 200 || response.body.isEmpty) {
      throw AppException(
        message:
            'TikWM returned HTTP ${response.statusCode} for creator videos.',
        userMessage: 'Could not load this creator\'s videos. Please try again.',
      );
    }

    final payload = _decodePayload(response.body);
    final value = payload['data'];
    if (payload['code'] != 0 || value is! Map) {
      throw const AppException(
        message: 'Creator videos were not available from the service.',
        userMessage:
            'This creator\'s videos could not be loaded. Please try again later.',
      );
    }

    final data = Map<String, dynamic>.from(value);
    final rawVideos = data['videos'];
    final videos = rawVideos is List
        ? rawVideos
              .whereType<Map>()
              .map((item) => _parseVideo(Map<String, dynamic>.from(item)))
              .where((video) => video.downloadOptions.isNotEmpty)
              .toList(growable: false)
        : const <TikTokVideo>[];
    final authorData = data['author'] is Map
        ? Map<String, dynamic>.from(data['author'] as Map)
        : videos.isNotEmpty
        ? _authorData(
            data['videos'] is List && (data['videos'] as List).isNotEmpty
                ? (data['videos'] as List).first
                : null,
          )
        : <String, dynamic>{};
    final creatorUsername =
        _string(authorData['unique_id']) ?? normalizedUsername;
    final creator = TikTokCreator(
      username: creatorUsername.replaceFirst(RegExp(r'^@'), ''),
      displayName: _string(authorData['nickname']) ?? creatorUsername,
      avatarUrl:
          _assetUrl(
            _string(authorData['avatar']) ??
                _string(authorData['avatar_thumb']) ??
                _string(authorData['avatar_medium']),
          ) ??
          '',
      signature: _string(authorData['signature']) ?? '',
    );
    final hasMore = data['hasMore'] == true;
    final nextCursor = data['cursor']?.toString();

    return TikTokCreatorPage(
      creator: creator,
      videos: videos,
      hasMore: hasMore && nextCursor != null && nextCursor != cursor,
      nextCursor: nextCursor,
    );
  }

  Future<http.Response> _post(
    Uri uri,
    Map<String, String> body, {
    required String timeoutMessage,
  }) async {
    try {
      return await _httpClient
          .post(
            uri,
            headers: const {
              'Accept': 'application/json',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
            },
            body: body,
          )
          .timeout(_requestTimeout);
    } on TimeoutException {
      throw AppException(
        message: timeoutMessage,
        userMessage: 'The request took too long. Please try again.',
      );
    } on http.ClientException catch (error) {
      throw AppException(
        message: 'TikWM request failed: ${error.message}',
        userMessage:
            'Could not connect to the video service. Please try again.',
      );
    }
  }

  Map<String, dynamic> _decodePayload(String responseBody) {
    final value = const JsonDecoder().convert(responseBody);
    if (value is! Map) {
      throw const AppException(
        message: 'The video service returned an invalid response.',
        userMessage:
            'The video service returned an unexpected response. Please try again.',
      );
    }
    return Map<String, dynamic>.from(value);
  }

  TikTokVideo _parseVideo(Map<String, dynamic> data) {
    final author = _authorData(data['author']);
    final authorId = _string(author['unique_id']) ?? '';
    final id =
        _string(data['id']) ??
        _string(data['video_id']) ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final standardUrl = _assetUrl(_string(data['play']));
    final hdUrl = _assetUrl(_string(data['hdplay']));
    final watermarkedUrl = _assetUrl(_string(data['wmplay']));
    final musicInfo = data['music_info'] is Map
        ? Map<String, dynamic>.from(data['music_info'] as Map)
        : const <String, dynamic>{};
    final audioUrl = _assetUrl(
      _string(data['music']) ??
          _string(musicInfo['play']) ??
          _string(musicInfo['play_url']),
    );
    final options = <TikTokDownloadOption>[
      if (standardUrl != null)
        TikTokDownloadOption(
          format: TikTokDownloadFormat.standard,
          url: standardUrl,
          sizeBytes: _int(data['size']),
        ),
      if (hdUrl != null)
        TikTokDownloadOption(
          format: TikTokDownloadFormat.hd,
          url: hdUrl,
          sizeBytes: _int(data['hd_size'] ?? data['hdsize']),
        ),
      if (audioUrl != null)
        TikTokDownloadOption(
          format: TikTokDownloadFormat.mp3,
          url: audioUrl,
          sizeBytes: _int(musicInfo['size'] ?? data['music_size']),
        ),
    ];
    if (options.isEmpty && watermarkedUrl != null) {
      options.add(
        TikTokDownloadOption(
          format: TikTokDownloadFormat.standard,
          url: watermarkedUrl,
          sizeBytes: _int(data['wm_size'] ?? data['wmsize']),
        ),
      );
    }
    final primaryUrl = standardUrl ?? hdUrl ?? watermarkedUrl ?? '';
    final sourceUrl =
        _string(data['share_url']) ??
        (authorId.isNotEmpty
            ? 'https://www.tiktok.com/@$authorId/video/$id'
            : 'https://www.tiktok.com/');

    return TikTokVideo(
      id: id,
      title: _string(data['title']) ?? 'TikTok video',
      author:
          _string(author['nickname']) ??
          (authorId.isEmpty ? 'Unknown creator' : authorId),
      thumbnailUrl:
          _assetUrl(_string(data['cover']) ?? _string(data['origin_cover'])) ??
          '',
      videoUrl: primaryUrl,
      durationSeconds: _int(data['duration']),
      sourceUrl: sourceUrl,
      sizeBytes: _int(data['size'] ?? data['hd_size']),
      authorId: authorId,
      authorAvatarUrl:
          _assetUrl(
            _string(author['avatar']) ??
                _string(author['avatar_thumb']) ??
                _string(author['avatar_medium']),
          ) ??
          '',
      downloadOptions: options,
    );
  }

  Map<String, dynamic> _authorData(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String? _string(dynamic value) =>
      value is String && value.trim().isNotEmpty ? value.trim() : null;

  int _int(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  String? _assetUrl(String? value) {
    if (value == null) return null;
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return 'https://www.tikwm.com$value';
    return value;
  }
}
