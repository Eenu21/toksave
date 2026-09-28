import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/url_utils.dart';
import '../models/frequent_creator.dart';
import '../models/recent_video.dart';
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
  Timer? _autoFetchTimer;
  TikTokVideo? _video;
  TikTokDownloadFormat? _selectedFormat;
  bool _isLoading = false;
  bool _hasClipboardUrl = false;
  bool _downloadComplete = false;
  String? _errorMessage;
  String? _lastAutoFetchUrl;
  int _lookupGeneration = 0;

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
    _autoFetchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final clipboard = await Clipboard.getData('text/plain');
      final text = clipboard?.text ?? '';
      if (text.trim().isNotEmpty && isTikTokVideoUrl(text) && mounted) {
        _onVideoUrlChanged(text, fromClipboard: true);
        setState(() {
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
      });
      _onVideoUrlChanged(text, fromClipboard: true);
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
    if (!isTikTokVideoUrl(url)) {
      setState(
        () => _errorMessage = 'Paste a TikTok video link, not a profile link.',
      );
      return;
    }

    _autoFetchTimer?.cancel();
    final lookupGeneration = ++_lookupGeneration;
    final provider = context.read<DownloadProvider>();
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted || lookupGeneration != _lookupGeneration) return;
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
      if (!mounted || lookupGeneration != _lookupGeneration) return;
      setState(() {
        _video = video;
        _selectedFormat = video.downloadOptions.first.format;
        _isLoading = false;
      });
    } on AppException catch (error) {
      if (!mounted || lookupGeneration != _lookupGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.userMessage ?? error.message;
      });
    } catch (_) {
      if (!mounted || lookupGeneration != _lookupGeneration) return;
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not retrieve this video. Check the link and try again.';
      });
    }
  }

  void _onVideoUrlChanged(String value, {bool fromClipboard = false}) {
    final url = value.trim();
    final isVideoUrl = isTikTokVideoUrl(url);
    _lookupGeneration++;
    _autoFetchTimer?.cancel();
    if (!isVideoUrl) _lastAutoFetchUrl = null;

    setState(() {
      _errorMessage = null;
      _hasClipboardUrl = fromClipboard && isVideoUrl;
      _downloadComplete = false;
      _isLoading = false;
      if (_video != null && normalizeTikTokUrl(url) != _video!.sourceUrl) {
        _video = null;
        _selectedFormat = null;
      }
    });
    if (isVideoUrl) _scheduleAutomaticLookup(url);
  }

  void _scheduleAutomaticLookup(String rawUrl) {
    final url = normalizeTikTokUrl(rawUrl);
    if (!isTikTokVideoUrl(url) || url == _lastAutoFetchUrl) return;
    _autoFetchTimer?.cancel();
    _autoFetchTimer = Timer(const Duration(milliseconds: 650), () {
      if (!mounted ||
          normalizeTikTokUrl(_controller.text) != url ||
          _isLoading) {
        return;
      }
      _lastAutoFetchUrl = url;
      unawaited(_fetchVideo());
    });
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
    try {
      final provider = context.read<DownloadProvider>();
      await provider.recordCreatorVisit(
        username: video.authorId.isEmpty ? video.author : video.authorId,
        displayName: video.author,
        avatarUrl: video.authorAvatarUrl,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update creator history.')),
        );
      }
    }
    if (!mounted) return;
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

  Future<void> _openRecentVideo(RecentVideo video) async {
    _controller.text = video.sourceUrl;
    await _fetchVideo();
  }

  Future<void> _openFrequentCreator(FrequentCreator creator) async {
    try {
      final provider = context.read<DownloadProvider>();
      await provider.recordCreatorVisit(
        username: creator.username,
        displayName: creator.displayName,
        avatarUrl: creator.avatarUrl,
      );
      if (!mounted) return;
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CreatorProfileScreen(
            creatorUsername: creator.username,
            creatorDisplayName: creator.displayName,
            creatorAvatarUrl: creator.avatarUrl,
          ),
        ),
      );
      if (mounted) await provider.refreshDownloads();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open this creator profile.')),
        );
      }
    }
  }

  Widget _sectionHeading(ThemeData theme, String title, String subtitle) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );

  Widget _buildRecentVideos(ThemeData theme, DownloadProvider provider) {
    final videos = provider.recentVideos.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          theme,
          'Recent videos',
          'Your checked links are saved on this device',
        ),
        if (videos.isEmpty)
          _HomeEmptyCard(
            theme: theme,
            icon: Icons.history_rounded,
            message: 'Videos you check will show up here for quick access.',
          )
        else
          SizedBox(
            height: 202,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: videos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final video = videos[index];
                return SizedBox(
                  width: 154,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _openRecentVideo(video),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Stack(
                            children: [
                              CachedNetworkImage(
                                imageUrl: video.thumbnailUrl,
                                width: double.infinity,
                                height: 112,
                                fit: BoxFit.cover,
                                placeholder: (_, _) => Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(Icons.video_file_rounded),
                                  ),
                                ),
                                errorWidget: (_, _, _) => Container(
                                  color:
                                      theme.colorScheme.surfaceContainerHighest,
                                  child: const Center(
                                    child: Icon(Icons.video_file_rounded),
                                  ),
                                ),
                              ),
                              Positioned(
                                right: 8,
                                bottom: 8,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.68),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      formatDuration(video.durationSeconds),
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                            child: Text(
                              video.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
                            child: Text(
                              video.author,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildFrequentCreators(ThemeData theme, DownloadProvider provider) {
    final creators = provider.frequentCreators.take(8).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading(
          theme,
          'Frequently visited',
          'Creators whose profiles you open',
        ),
        if (creators.isEmpty)
          _HomeEmptyCard(
            theme: theme,
            icon: Icons.people_outline_rounded,
            message: 'Open a creator profile and it will be remembered here.',
          )
        else
          SizedBox(
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: creators.length,
              separatorBuilder: (_, _) => const SizedBox(width: 18),
              itemBuilder: (context, index) {
                final creator = creators[index];
                return SizedBox(
                  width: 78,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _openFrequentCreator(creator),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 30,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          backgroundImage: creator.avatarUrl.isEmpty
                              ? null
                              : CachedNetworkImageProvider(creator.avatarUrl),
                          child: creator.avatarUrl.isEmpty
                              ? const Icon(Icons.person_rounded)
                              : null,
                        ),
                        const SizedBox(height: 7),
                        Text(
                          creator.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${creator.visitCount} visits',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

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

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.surfaceContainerHighest,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
                child: Row(
                  children: [
                    const AppLogo(size: 54),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome to $kAppName',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            kAppTagline,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Download a video',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Paste a public TikTok link to get started.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      UrlInputField(
                        controller: _controller,
                        onPaste: _pasteFromClipboard,
                        onChanged: _onVideoUrlChanged,
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _fetchVideo,
                          icon: _isLoading
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search_rounded),
                          label: Text(
                            _isLoading
                                ? 'Checking link...'
                                : 'Get video details',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
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
              _buildRecentVideos(theme, provider),
              const SizedBox(height: 22),
              _buildFrequentCreators(theme, provider),
              if (_video != null) ...[
                const SizedBox(height: 22),
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

class _HomeEmptyCard extends StatelessWidget {
  const _HomeEmptyCard({
    required this.theme,
    required this.icon,
    required this.message,
  });

  final ThemeData theme;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    ),
  );
}
