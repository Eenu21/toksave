import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/utils/url_utils.dart';
import '../models/saved_creator.dart';
import '../providers/download_provider.dart';

class SavedCreatorsScreen extends StatefulWidget {
  const SavedCreatorsScreen({super.key});

  @override
  State<SavedCreatorsScreen> createState() => _SavedCreatorsScreenState();
}

class _SavedCreatorsScreenState extends State<SavedCreatorsScreen> {
  Future<void> _openCreator(SavedCreator creator) async {
    final uri = Uri.tryParse(creator.profileUrl);
    if (uri == null || !isTikTokUrl(creator.profileUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This creator profile link is invalid.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this TikTok profile.')),
      );
    }
  }

  String _dateLabel(DateTime date) {
    final local = date.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<DownloadProvider>();
    final creators = provider.savedCreators;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved creators'),
        actions: [
          IconButton(
            tooltip: 'Refresh creator history',
            onPressed: provider.refreshDownloads,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : creators.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people_outline_rounded, size: 56),
                    SizedBox(height: 12),
                    Text(
                      'Creators you download from will be saved here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: creators.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final creator = creators[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    onTap: () => _openCreator(creator),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundImage: creator.avatarUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(creator.avatarUrl),
                      child: creator.avatarUrl.isEmpty
                          ? const Icon(Icons.person_rounded)
                          : null,
                    ),
                    title: Text(
                      creator.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('@${creator.username}'),
                        Text(
                          '${creator.downloadCount} downloads • Last: ${_dateLabel(creator.lastDownloadedAt)}',
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.open_in_new_rounded),
                  ),
                );
              },
            ),
    );
  }
}
