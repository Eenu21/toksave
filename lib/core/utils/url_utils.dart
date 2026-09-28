import 'dart:convert';

String normalizeTikTokUrl(String rawUrl) {
  final value = rawUrl.trim();
  if (value.isEmpty) return value;

  final uri = Uri.tryParse(value);
  if (uri == null) return value;

  if (!uri.hasScheme) {
    return 'https://$value';
  }

  return uri.toString();
}

bool isTikTokUrl(String rawUrl) {
  final value = normalizeTikTokUrl(rawUrl);
  final uri = Uri.tryParse(value);
  if (uri == null) return false;

  final host = uri.host.toLowerCase();
  return host == 'tiktok.com' || host.endsWith('.tiktok.com');
}

bool isTikTokVideoUrl(String rawUrl) {
  final value = normalizeTikTokUrl(rawUrl);
  final uri = Uri.tryParse(value);
  if (uri == null || !isTikTokUrl(value)) return false;

  final host = uri.host.toLowerCase();
  if (host == 'vm.tiktok.com' || host == 'vt.tiktok.com') return true;

  final segments = uri.pathSegments;
  if (segments.length >= 3 && segments[0].startsWith('@')) {
    return segments[1] == 'video' && RegExp(r'^\d+$').hasMatch(segments[2]);
  }
  return segments.length >= 2 && segments[0] == 't' && segments[1].isNotEmpty;
}

String sanitizeFileName(String title) {
  final safe = title.replaceAll(RegExp(r'[^a-zA-Z0-9 _-]'), '').trim();
  return safe.isEmpty ? 'tiktok-video' : safe;
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '0 KB';
  const suffixes = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var index = 0;
  while (value >= 1024 && index < suffixes.length - 1) {
    value /= 1024;
    index += 1;
  }
  final number = value >= 10
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
  return '$number ${suffixes[index]}';
}

String formatDuration(int seconds) {
  final duration = seconds < 0 ? 0 : seconds;
  final hours = duration ~/ 3600;
  final minutes = (duration % 3600) ~/ 60;
  final secs = duration % 60;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
  return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
}

String toBase64Url(String value) => base64Encode(utf8.encode(value));
