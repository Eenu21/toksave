import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_constants.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Appearance', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_rounded)),
              ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_rounded)),
              ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_rounded)),
            ],
            selected: <ThemeMode>{settings.themeMode},
            onSelectionChanged: (values) async {
              await settings.setThemeMode(values.first);
            },
          ),
          const SizedBox(height: 24),
          const Text('Downloads', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          SwitchListTile(
            title: const Text('Wi‑Fi only'),
            subtitle: const Text('Only download when connected to Wi‑Fi.'),
            value: settings.wifiOnly,
            onChanged: (value) async => settings.setWifiOnly(value),
          ),
          SwitchListTile(
            title: const Text('Auto-save'),
            subtitle: const Text('Automatically save and track every download.'),
            value: settings.autoSave,
            onChanged: (value) async => settings.setAutoSave(value),
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_rounded),
            title: const Text('Download location'),
            subtitle: Text(settings.downloadDirectory),
            onTap: () => _showLocationDialog(context),
          ),
          const SizedBox(height: 24),
          const Text('App', style: TextStyle(fontWeight: FontWeight.w700)),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _openUrl(kPrivacyUrl),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of Use'),
            onTap: () => _openUrl(kTermsUrl),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('About'),
            onTap: () => _showAboutDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.balance_rounded),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(context: context),
          ),
          ListTile(
            leading: const Icon(Icons.app_registration_rounded),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          const SizedBox(height: 24),
          const Text('Support', style: TextStyle(fontWeight: FontWeight.w700)),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Report a problem'),
            onTap: () => _openUrl('https://example.com/support'),
          ),
          ListTile(
            leading: const Icon(Icons.email_outlined),
            title: const Text('Contact developer'),
            onTap: () => _openUrl('mailto:$kSupportEmail'),
          ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not open URL');
    }
  }

  Future<void> _showLocationDialog(BuildContext context) async {
    final controller = TextEditingController(text: 'Movies/TokSave');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download location'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Movies/TokSave'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && context.mounted) {
      await context.read<SettingsProvider>().setDownloadDirectory(result);
    }
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: kAppName,
      applicationVersion: '1.0.0',
      applicationLegalese: 'TokSave is an original app for downloading videos when legally permitted. Use only with permission and respect platform rules.',
    );
  }
}
