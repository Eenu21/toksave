import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/url_utils.dart';
import '../models/tiktok_download_option.dart';
import '../models/tiktok_video.dart';
import '../providers/download_provider.dart';
import '../services/ads_service.dart';
import '../services/sharing_service.dart';
import '../widgets/app_logo.dart';
import '../widgets/url_input_field.dart';
import 'creator_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final TextEditingController _controller = TextEditingController();
  final AdsService _adsService = AdsService(enabled: true);
  final SharingService _sharingService = SharingService();
  TikTokVideo? _video;
  TikTokDownloadFormat? _selectedFormat;
  bool _isLoading = false;
  bool _hasClipboardUrl = false;
  bool _downloadComplete = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_adsService.initialize());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkClipboard());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_checkClipboard());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final clipboard = await Clipboard.getData('text/plain');
      final text = clipboard?.text ?? '';
      if (text.trim().isNotEmpty && isTikTokUrl(text) && mounted) {
        setState(() {
          _hasClipboardUrl = true;
          _controller.text = text;
        });
      }
    } catch (_) {
      // Clipboard access is optional.
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboard = await Clipboard.getData('text/plain');
      final text = clipboard?.text ?? '';
      if (!mounted) return;
      if (text.trim().isEmpty) {
        setState(() => _errorMessage = 'Clipboard is empty.');
        return;
      }
      setState(() {
        _controller.text = text;
        _hasClipboardUrl = isTikTokUrl(text);
        _errorMessage = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Could not read your clipboard.');
      }
    }
  }

  Future<void> _fetchVideo() async {
    final url = _controller.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please paste a TikTok URL first.');
      return;
    }

    final provider = context.read<DownloadProvider>();
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;
    if (connectivityResult.contains(ConnectivityResult.none)) {
      setState(() => _errorMessage = 'No internet connection.');
      return;
    }

    setState(() {
      _isLoading = true;
      _downloadComplete = false;
      _errorMessage = null;
    });

    try {
      final video = await provider.resolveVideo(url);
      if (!mounted) return;
      setState(() {
        _video = video;
        _selectedFormat = video.downloadOptions.first.format;
        _isLoading = false;
      });
    } on AppException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.userMessage ?? error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not retrieve this video. Check the link and try again.';
      });
    }
  }

  Future<void> _downloadVideo(DownloadProvider provider) async {
    final video = _video;
    final format = _selectedFormat;
    if (video == null || format == null) return;
    final option = video.optionFor(format);
    if (option == null) return;

    setState(() {
      _downloadComplete = false;
      _errorMessage = null;
    });

    try {
      await provider.downloadVideo(video, option: option);
      if (!mounted) return;
      setState(() => _downloadComplete = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            option.isAudio
                ? 'Audio saved to Music/TokSave.'
                : 'Video saved to Gallery/Movies/TokSave.',
          ),
        ),
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _errorMessage = error.userMessage ?? error.message);
      }
    }
  }

  Future<void> _openCreatorProfile(TikTokVideo video) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CreatorProfileScreen(seedVideo: video),
      ),
    );
    if (mounted) {
      await context.read<DownloadProvider>().refreshDownloads();
    }
  }

  String _sizeLabel(int bytes) =>
      bytes > 0 ? '~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB' : '';

  Widget _buildVideoOptions(ThemeData theme, DownloadProvider provider) {
    final video = _video!;
    final selectedOption = video.optionFor(_selectedFormat!);
    final isAudio = selectedOption?.isAudio ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              video.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${video.author} • ${formatDuration(video.durationSeconds)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text('Download option', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            ...video.downloadOptions.map((option) {
              final selected = option.format == _selectedFormat;
              final sizeLabel = _sizeLabel(option.sizeBytes);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? theme.colorScheme.secondaryContainer
                      : theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: provider.isBusy
                        ? null
                        : () => setState(() {
                            _selectedFormat = option.format;
                            _downloadComplete = false;
                          }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.check_circle_rounded
                                : option.isAudio
                                ? Icons.music_note_rounded
                                : Icons.video_file_rounded,
                            color: selected ? theme.colorScheme.primary : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              option.label,
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (sizeLabel.isNotEmpty) Text(sizeLabel),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            if (provider.isBusy) ...[
              Row(
                children: [
                  Expanded(child: Text(provider.currentProgress.message)),
                  if (provider.currentProgress.totalBytes > 0)
                    Text('${provider.currentProgress.percent}%'),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: provider.currentProgress.totalBytes > 0
                    ? provider.currentProgress.percent / 100
                    : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: provider.cancelDownload,
                  child: const Text('Cancel'),
                ),
              ),
            ] else
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: selectedOption == null
                      ? null
                      : () => _downloadVideo(provider),
                  icon: Icon(
                    isAudio ? Icons.music_note_rounded : Icons.download_rounded,
                  ),
                  label: Text(isAudio ? 'Download audio' : 'Download video'),
                ),
              ),
            if (_downloadComplete)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Saved successfully • 100%')),
                  ],
                ),
              ),
            if (video.sourceUrl.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () => _sharingService.openLink(video.sourceUrl),
                  icon: const Icon(Icons.share_rounded),
                  label: const Text('Share link'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendedCreator(ThemeData theme) {
    final video = _video!;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openCreatorProfile(video),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundImage: video.authorAvatarUrl.isEmpty
                    ? null
                    : CachedNetworkImageProvider(video.authorAvatarUrl),
                child: video.authorAvatarUrl.isEmpty
                    ? const Icon(Icons.person_rounded, size: 28)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended for you',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      video.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Text('View profile and public videos'),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DownloadProvider>();
    final downloads = provider.downloads.take(3).toList();

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    const AppLogo(size: 72),
                    const SizedBox(height: 16),
                    Text(
                      kAppName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      kAppTagline,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Paste a TikTok video link',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              UrlInputField(
                controller: _controller,
                onPaste: _pasteFromClipboard,
                onChanged: (_) => setState(() {
                  _errorMessage = null;
                  _hasClipboardUrl = false;
                }),
              ),
              if (_hasClipboardUrl) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.content_paste_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text('TikTok link detected in clipboard'),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _fetchVideo,
                  icon: _isLoading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(
                    _isLoading ? 'Checking link...' : 'Get video details',
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              if (_video != null && _selectedFormat != null) ...[
                const SizedBox(height: 16),
                _buildVideoOptions(theme, provider),
              ],
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Recent downloads',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(color: theme.colorScheme.outlineVariant),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (downloads.isEmpty)
                const Text('No downloads yet.')
              else
                ...downloads.map(
                  (record) => Card(
                    child: ListTile(
                      leading: record.mediaType == 'audio'
                          ? const Icon(Icons.music_note_rounded)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: record.thumbnailUrl.isEmpty
                                  ? const Icon(Icons.video_library_rounded)
                                  : Image.file(
                                      File(record.filePath),
                                      width: 52,
                                      height: 52,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => const Icon(
                                        Icons.broken_image_rounded,
                                      ),
                                    ),
                            ),
                      title: Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        record.downloadedAt.toLocal().toString().split(' ')[0],
                      ),
                      trailing: IconButton(
                        onPressed: () => SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(record.filePath)],
                            text: 'Downloaded from TokSave',
                          ),
                        ),
                        icon: const Icon(Icons.share_rounded),
                      ),
                    ),
                  ),
                ),
              if (_video != null) ...[
                const SizedBox(height: 20),
                _buildRecommendedCreator(theme),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: theme.colorScheme.surfaceContainerHighest,
                ),
                child: Center(
                  child: Text(
                    'Ad placement',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
