import 'dart:io';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class SharingService {
  Future<void> shareFile(File file, {String text = 'Shared from TokSave'}) async {
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: text));
  }

  Future<void> openLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> composeEmail(String email) async {
    final uri = Uri(scheme: 'mailto', path: email, query: 'subject=TokSave support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
