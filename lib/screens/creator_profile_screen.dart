import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/errors/app_exception.dart';
import '../core/utils/url_utils.dart';
import '../models/tiktok_download_option.dart';
import '../models/tiktok_video.dart';
import '../providers/download_provider.dart';

class CreatorProfileScreen extends StatefulWidget {
  const CreatorProfileScreen({super.key, required this.seedVideo});

  final TikTokVideo seedVideo;

  @override
  State<CreatorProfileScreen> createState() => _CreatorProfileScreenState();
}

class _CreatorProfileScreenState extends State<CreatorProfileScreen> {
  final Set<String> _selectedIds = <String>{};
  final TextEditingController _linksController = TextEditingController();
  final List<TikTokVideo> _importedVideos = <TikTokVideo>[];
  TikTokDownloadFormat? _format;
  String? _loadError;
  bool _isBatchDownloading = false;
  bool _isImportingLinks = false;
  bool _downloadComplete = false;
  int _completedCount = 0;

  @override
  void initState() {
    super.initState();
    _format = widget.seedVideo.downloadOptions.isEmpty
        ? null
        : widget.seedVideo.downloadOptions.first.format;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  @override
  void dispose() {
    _linksController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      await context.read<DownloadProvider>().loadCreatorVideos(
        widget.seedVideo,
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _loadError = error.userMessage ?? error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _loadError = 'Could not load this creator profile right now.',
        );
      }
    }
  }

  Future<void> _retryProfile(DownloadProvider provider) async {
    setState(() => _loadError = null);
    try {
      await provider.loadCreatorVideos(widget.seedVideo);
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _loadError = error.userMessage ?? error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadError = 'Could not load this creator profile.');
      }
    }
  }

  List<TikTokVideo> _availableVideos(DownloadProvider provider) {
    final format = _format;
    if (format == null) return const [];
    return _allVideos(
      provider,
    ).where((video) => video.optionFor(format) != null).toList(growable: false);
  }

  List<TikTokVideo> _allVideos(DownloadProvider provider) {
    final videos = <String, TikTokVideo>{
      for (final video in provider.creatorVideos) video.id: video,
      for (final video in _importedVideos) video.id: video,
    };
    return videos.values.toList(growable: false);
  }

  Future<void> _importVideoLinks(DownloadProvider provider) async {
    final uniqueLinks = <String>{};
    for (final candidate in _linksController.text.split(RegExp(r'[\s,;]+'))) {
      final link = candidate.replaceAll(RegExp(r'[)\]}>.,]+$'), '').trim();
      if (link.isNotEmpty && isTikTokUrl(link)) {
        uniqueLinks.add(normalizeTikTokUrl(link));
      }
    }

    if (uniqueLinks.isEmpty) {
      setState(() => _loadError = 'Paste TikTok video links, one per line.');
      return;
    }

    setState(() {
      _isImportingLinks = true;
      _loadError = null;
    });
    var importedCount = 0;
    final failedMessages = <String>[];
    final links = uniqueLinks.toList(growable: false);

    try {
      for (var offset = 0; offset < links.length; offset += 3) {
        final chunk = links.skip(offset).take(3);
        final results = await Future.wait(
          chunk.map((link) async {
            try {
              return (video: await provider.resolveVideo(link), error: null);
            } on AppException catch (error) {
              return (video: null, error: error.userMessage ?? error.message);
            } catch (_) {
              return (
                video: null,
                error: 'Could not retrieve one of the pasted links.',
              );
            }
          }),
        );

        for (final result in results) {
          if (result.video == null) {
            failedMessages.add(
              result.error ?? 'A pasted link could not be loaded.',
            );
          } else if (!_allVideos(
            provider,
          ).any((video) => video.id == result.video!.id)) {
            _importedVideos.add(result.video!);
            importedCount++;
          }
        }
        if (mounted) setState(() {});
      }

      if (!mounted) return;
      setState(() {
        _loadError = failedMessages.isEmpty
            ? null
            : 'Could not load ${failedMessages.length} link(s). $importedCount video(s) were added. ${failedMessages.first}';
      });
      if (importedCount > 0) {
        _linksController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added $importedCount video(s) to this profile.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isImportingLinks = false);
    }
  }

  int? _selectedSize(DownloadProvider provider) {
    final videos = _availableVideos(
      provider,
    ).where((video) => _selectedIds.contains(video.id)).toList(growable: false);
    if (videos.isEmpty) return null;
    final sizes = videos
        .map((video) => video.optionFor(_format!)!.sizeBytes)
        .toList(growable: false);
    if (sizes.any((size) => size <= 0)) return null;
    return sizes.fold<int>(0, (total, size) => total + size);
  }

  String _sizeText(int bytes) =>
      '~${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

  Future<void> _loadMore(DownloadProvider provider) async {
    try {
      await provider.loadMoreCreatorVideos();
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _loadError = error.userMessage ?? error.message);
      }
    } catch (_) {
      if (mounted) setState(() => _loadError = 'Could not load more videos.');
    }
  }

  Future<void> _openTikTokProfile(DownloadProvider provider) async {
    final username = provider.creator?.username ?? widget.seedVideo.authorId;
    if (username.isEmpty) return;
    final uri = Uri.https('www.tiktok.com', '/@$username');
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this TikTok profile.')),
      );
    }
  }

  Future<void> _downloadSelected(DownloadProvider provider) async {
    final format = _format;
    if (format == null || provider.isBusy) return;
    final videos = _availableVideos(
      provider,
    ).where((video) => _selectedIds.contains(video.id)).toList(growable: false);
    if (videos.isEmpty) return;

    setState(() {
      _isBatchDownloading = true;
      _downloadComplete = false;
      _completedCount = 0;
    });
    try {
      await provider.downloadBatch(videos, format);
      if (!mounted) return;
      setState(() {
        _downloadComplete = true;
        _completedCount = videos.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            format == TikTokDownloadFormat.mp3
                ? 'Audio saved to Music/TokSave.'
                : 'Videos saved to Gallery/Movies/TokSave.',
          ),
        ),
      );
    } on AppException catch (error) {
      if (mounted) {
        setState(() => _loadError = error.userMessage ?? error.message);
      }
    } finally {
      if (mounted) setState(() => _isBatchDownloading = false);
    }
  }

  void _setFormat(TikTokDownloadFormat format, DownloadProvider provider) {
    setState(() {
      _format = format;
      _selectedIds.removeWhere(
        (id) =>
            !provider.creatorVideos.any(
              (video) => video.id == id && video.optionFor(format) != null,
            ) &&
            !_importedVideos.any(
              (video) => video.id == id && video.optionFor(format) != null,
            ),
      );
      _downloadComplete = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DownloadProvider>();
    final creator = provider.creator;
    final availableFormats = TikTokDownloadFormat.values
        .where(
          (format) => _allVideos(
            provider,
          ).any((video) => video.optionFor(format) != null),
        )
        .toList(growable: false);
    final videos = _availableVideos(provider);
    final selectedCount = videos
        .where((video) => _selectedIds.contains(video.id))
        .length;
    final size = _selectedSize(provider);

    return Scaffold(
      appBar: AppBar(title: const Text('Creator profile')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundImage:
                                (creator?.avatarUrl ??
                                        widget.seedVideo.authorAvatarUrl)
                                    .isEmpty
                                ? null
                                : CachedNetworkImageProvider(
                                    creator?.avatarUrl ??
                                        widget.seedVideo.authorAvatarUrl,
                                  ),
                            child:
                                (creator?.avatarUrl ??
                                        widget.seedVideo.authorAvatarUrl)
                                    .isEmpty
                                ? const Icon(Icons.person_rounded, size: 38)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  creator?.displayName ??
                                      widget.seedVideo.author,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  '@${creator?.username ?? widget.seedVideo.authorId}',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if ((creator?.signature ?? '').isNotEmpty)
                                  Text(
                                    creator!.signature,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Public videos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_allVideos(provider).length} '
                    '${_allVideos(provider).length == 1 ? 'video' : 'videos'} available',
                  ),
                  if (_loadError != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        _loadError!,
                        style: TextStyle(
                          color: theme.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: provider.isLoadingCreator
                              ? null
                              : () => _retryProfile(provider),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                        TextButton.icon(
                          onPressed: () => _openTikTokProfile(provider),
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Open profile in TikTok'),
                        ),
                      ],
                    ),
                  ],
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add videos from this profile',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'If the profile feed cannot load, paste video links from TikTok here, one per line. They will be added to the batch list.',
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _linksController,
                            minLines: 2,
                            maxLines: 5,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              hintText:
                                  'https://www.tiktok.com/@creator/video/...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed:
                                  _isImportingLinks || _isBatchDownloading
                                  ? null
                                  : () => _importVideoLinks(provider),
                              icon: _isImportingLinks
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.playlist_add_rounded),
                              label: Text(
                                _isImportingLinks
                                    ? 'Loading links...'
                                    : 'Add links to list',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (provider.isLoadingCreator && _allVideos(provider).isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_allVideos(provider).isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text('No public videos are available to show.'),
                    )
                  else ...[
                    const SizedBox(height: 12),
                    if (availableFormats.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        children: availableFormats.map((format) {
                          final label = switch (format) {
                            TikTokDownloadFormat.standard => 'Standard',
                            TikTokDownloadFormat.hd => 'HD',
                            TikTokDownloadFormat.mp3 => 'MP3 audio',
                          };
                          return ChoiceChip(
                            label: Text(label),
                            selected: _format == format,
                            onSelected: _isBatchDownloading
                                ? null
                                : (_) => _setFormat(format, provider),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text('${videos.length} in this format'),
                        ),
                        TextButton(
                          onPressed: videos.isEmpty || _isBatchDownloading
                              ? null
                              : () => setState(() {
                                  if (selectedCount == videos.length) {
                                    _selectedIds.clear();
                                  } else {
                                    _selectedIds
                                      ..clear()
                                      ..addAll(videos.map((video) => video.id));
                                  }
                                }),
                          child: Text(
                            selectedCount == videos.length
                                ? 'Clear selection'
                                : 'Select all',
                          ),
                        ),
                      ],
                    ),
                    if (videos.isNotEmpty)
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: videos.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.72,
                            ),
                        itemBuilder: (context, index) {
                          final video = videos[index];
                          final option = video.optionFor(_format!)!;
                          final selected = _selectedIds.contains(video.id);
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _isBatchDownloading
                                  ? null
                                  : () => setState(() {
                                      if (selected) {
                                        _selectedIds.remove(video.id);
                                      } else {
                                        _selectedIds.add(video.id);
                                      }
                                      _downloadComplete = false;
                                    }),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Expanded(
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        if (video.thumbnailUrl.isNotEmpty)
                                          CachedNetworkImage(
                                            imageUrl: video.thumbnailUrl,
                                            fit: BoxFit.cover,
                                            memCacheWidth: 400,
                                            memCacheHeight: 560,
                                            placeholder: (_, _) => ColoredBox(
                                              color: theme
                                                  .colorScheme
                                                  .surfaceContainerHighest,
                                            ),
                                            errorWidget: (_, _, _) =>
                                                ColoredBox(
                                                  color: theme
                                                      .colorScheme
                                                      .surfaceContainerHighest,
                                                  child: const Icon(
                                                    Icons.video_library_rounded,
                                                  ),
                                                ),
                                          )
                                        else
                                          ColoredBox(
                                            color: theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            child: Icon(
                                              option.isAudio
                                                  ? Icons.music_note_rounded
                                                  : Icons.video_library_rounded,
                                            ),
                                          ),
                                        Positioned(
                                          top: 6,
                                          right: 6,
                                          child: Icon(
                                            selected
                                                ? Icons.check_circle_rounded
                                                : Icons
                                                      .radio_button_unchecked_rounded,
                                            color: selected
                                                ? theme.colorScheme.primary
                                                : Colors.white,
                                            size: 28,
                                          ),
                                        ),
                                        Positioned(
                                          bottom: 6,
                                          right: 6,
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              color: Colors.black54,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 3,
                                                  ),
                                              child: Text(
                                                formatDuration(
                                                  video.durationSeconds,
                                                ),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          video.title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodyMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                        if (option.sizeBytes > 0)
                                          Text(
                                            _sizeText(option.sizeBytes),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    if (provider.hasMoreCreatorVideos)
                      Center(
                        child: TextButton.icon(
                          onPressed:
                              provider.isLoadingCreator || _isBatchDownloading
                              ? null
                              : () => _loadMore(provider),
                          icon: provider.isLoadingCreator
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(
                            provider.isLoadingCreator
                                ? 'Loading...'
                                : 'Load more videos',
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
            if (_isBatchDownloading || _downloadComplete)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isBatchDownloading) ...[
                      Text(
                        '${provider.batchProgressLabel} • ${provider.currentProgress.message}',
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: provider.currentProgress.totalBytes > 0
                            ? provider.currentProgress.percent / 100
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: provider.cancelDownload,
                          child: const Text('Cancel batch'),
                        ),
                      ),
                    ],
                    if (_downloadComplete)
                      Text(
                        'Downloaded $_completedCount videos successfully • 100%',
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
                  ],
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed:
                        selectedCount == 0 ||
                            _isBatchDownloading ||
                            provider.isBusy
                        ? null
                        : () => _downloadSelected(provider),
                    icon: _isBatchDownloading
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _isBatchDownloading
                          ? 'Downloading ${provider.batchProgressLabel}...'
                          : 'Download $selectedCount selected${size == null ? '' : ' • ${_sizeText(size)}'}',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
