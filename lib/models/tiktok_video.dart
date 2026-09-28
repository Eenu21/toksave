import 'tiktok_download_option.dart';

class TikTokVideo {
  const TikTokVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.durationSeconds,
    required this.sourceUrl,
    required this.sizeBytes,
    this.authorId = '',
    this.authorAvatarUrl = '',
    this.downloadOptions = const [],
  });

  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String videoUrl;
  final int durationSeconds;
  final String sourceUrl;
  final int sizeBytes;
  final String authorId;
  final String authorAvatarUrl;
  final List<TikTokDownloadOption> downloadOptions;

  TikTokDownloadOption? optionFor(TikTokDownloadFormat format) {
    for (final option in downloadOptions) {
      if (option.format == format) return option;
    }
    return null;
  }

  TikTokVideo copyWith({String? sourceUrl}) => TikTokVideo(
    id: id,
    title: title,
    author: author,
    thumbnailUrl: thumbnailUrl,
    videoUrl: videoUrl,
    durationSeconds: durationSeconds,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    sizeBytes: sizeBytes,
    authorId: authorId,
    authorAvatarUrl: authorAvatarUrl,
    downloadOptions: downloadOptions,
  );
}
