import 'package:flutter/material.dart';

enum LegalDocument { privacy, terms }

class LegalInfoScreen extends StatelessWidget {
  const LegalInfoScreen({super.key, required this.document});

  final LegalDocument document;

  String get _title => switch (document) {
    LegalDocument.privacy => 'Privacy policy',
    LegalDocument.terms => 'Terms of use',
  };

  List<_LegalSection> get _sections => switch (document) {
    LegalDocument.privacy => const [
      _LegalSection(
        'Information TokSave stores',
        'TokSave keeps download records, recent video details, saved creators, '
            'and creator profile visit counts in a local database on this '
            'device. Downloaded media is stored on this device and may also be '
            'saved to the shared media library. TokSave does not operate an '
            'account system or its own cloud service.',
      ),
      _LegalSection(
        'Requests to video services',
        'When you check a link or load a creator feed, TokSave sends the TikTok '
            'link or creator username to TikWM to request video details and '
            'media links. Video thumbnails and creator avatars are loaded from '
            'the image URLs supplied by that service. Those requests are '
            'handled under the provider’s own practices; TokSave cannot control '
            'how the provider processes them.',
      ),
      _LegalSection(
        'Advertising',
        'This build includes Google Mobile Ads using Google-provided test ad '
            'IDs. The Google Mobile Ads SDK may process device or request data '
            'as described by its own policies. Production advertising has not '
            'been configured.',
      ),
      _LegalSection(
        'Your choices and retention',
        'You can remove individual download records in TokSave. Download '
            'records, recent video lookups, saved creators, and creator visit '
            'history remain on this device until the app data is cleared or '
            'TokSave is uninstalled. Removing a download record may not delete '
            'a separate copy already saved to the shared media library.',
      ),
      _LegalSection(
        'Changes',
        'This notice describes the current app behavior and may be updated if '
            'TokSave’s features or service integrations change.',
      ),
    ],
    LegalDocument.terms => const [
      _LegalSection(
        'Use content responsibly',
        'Only download or save videos that you own or have permission to use. '
            'Respect creators’ rights, TikTok’s terms, and applicable laws. '
            'You are responsible for how you use, store, and share downloaded '
            'content.',
      ),
      _LegalSection(
        'Third-party services',
        'Video details and download links are provided by third-party '
            'services, not by TikTok or TokSave. Their availability, accuracy, '
            'and supported features may change without notice. TokSave does '
            'not bypass provider restrictions.',
      ),
      _LegalSection(
        'Local data and downloads',
        'Download history, recent video details, and creator visit history are '
            'stored on your device. You are responsible for ensuring you have '
            'enough storage and for managing downloaded files and any copies '
            'saved to the shared media library.',
      ),
      _LegalSection(
        'Availability',
        'TokSave is provided as-is for personal use. Downloads may fail or '
            'become unavailable because of network, device, provider, or '
            'platform changes. No uninterrupted service or particular '
            'download result is guaranteed.',
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'TokSave',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This information is available in the app and does not require a '
            'website.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          for (final section in _sections)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      section.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(section.body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection(this.title, this.body);

  final String title;
  final String body;
}
