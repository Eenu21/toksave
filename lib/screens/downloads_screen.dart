import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/url_utils.dart';
import '../providers/download_provider.dart';
import '../widgets/video_player_dialog.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadProvider>();
    final downloads = provider.downloads;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            onPressed: provider.refreshDownloads,
            icon: const Icon(Icons.refresh_rounded),
          ),
          if (downloads.isNotEmpty)
            IconButton(
              onPressed: provider.deleteAllDownloads,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : downloads.isEmpty
          ? const Center(child: Text('No downloaded videos yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: downloads.length,
              itemBuilder: (context, index) {
                final record = downloads[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: record.mediaType == 'audio'
                              ? _DownloadThumbnail(
                                  theme: theme,
                                  icon: Icons.music_note_rounded,
                                )
                              : CachedNetworkImage(
                                  imageUrl: record.thumbnailUrl,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  placeholder: (_, _) => _DownloadThumbnail(
                                    theme: theme,
                                    icon: Icons.video_file_rounded,
                                  ),
                                  errorWidget: (_, _, _) => _DownloadThumbnail(
                                    theme: theme,
                                    icon: Icons.video_file_rounded,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${record.downloadedAt.toLocal().toString().split(' ')[0]} • ${formatBytes(record.fileSizeBytes)}',
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  IconButton.outlined(
                                    onPressed: record.mediaType == 'audio'
                                        ? null
                                        : () => showDialog<void>(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (_) =>
                                                VideoPlayerDialog.file(
                                                  filePath: record.filePath,
                                                  title: record.title,
                                                ),
                                          ),
                                    icon: Icon(
                                      record.mediaType == 'audio'
                                          ? Icons.music_note_rounded
                                          : Icons.play_arrow_rounded,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.outlined(
                                    onPressed: () => SharePlus.instance.share(
                                      ShareParams(
                                        files: [XFile(record.filePath)],
                                        text: 'Downloaded from TokSave',
                                      ),
                                    ),
                                    icon: const Icon(Icons.share_rounded),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.outlined(
                                    onPressed: () =>
                                        provider.deleteDownload(record.id),
                                    icon: const Icon(Icons.delete_rounded),
                                  ),
                                ],
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
    );
  }
}

class _DownloadThumbnail extends StatelessWidget {
  const _DownloadThumbnail({required this.theme, required this.icon});

  final ThemeData theme;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    width: 90,
    height: 90,
    color: theme.colorScheme.surfaceContainerHighest,
    child: Icon(icon),
  );
}
