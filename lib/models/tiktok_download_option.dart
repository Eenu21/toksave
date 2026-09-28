enum TikTokDownloadFormat { standard, hd, mp3 }

class TikTokDownloadOption {
  const TikTokDownloadOption({
    required this.format,
    required this.url,
    this.sizeBytes = 0,
  });

  final TikTokDownloadFormat format;
  final String url;
  final int sizeBytes;

  String get label => switch (format) {
    TikTokDownloadFormat.standard => 'Standard',
    TikTokDownloadFormat.hd => 'HD',
    TikTokDownloadFormat.mp3 => 'MP3 audio',
  };

  String get extension => format == TikTokDownloadFormat.mp3 ? 'mp3' : 'mp4';

  bool get isAudio => format == TikTokDownloadFormat.mp3;
}
