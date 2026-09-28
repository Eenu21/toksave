class DownloadRecord {
  const DownloadRecord({
    required this.id,
    required this.title,
    required this.filePath,
    required this.thumbnailUrl,
    required this.originalUrl,
    required this.fileSizeBytes,
    required this.downloadedAt,
    required this.author,
    required this.durationSeconds,
    this.galleryUri,
    this.mediaType = 'video',
    this.authorId = '',
    this.authorAvatarUrl = '',
  });

  final String id;
  final String title;
  final String filePath;
  final String thumbnailUrl;
  final String originalUrl;
  final int fileSizeBytes;
  final DateTime downloadedAt;
  final String author;
  final int durationSeconds;
  final String? galleryUri;
  final String mediaType;
  final String authorId;
  final String authorAvatarUrl;

  factory DownloadRecord.fromMap(Map<String, dynamic> map) {
    return DownloadRecord(
      id: map['id'] as String,
      title: map['title'] as String,
      filePath: map['filePath'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      originalUrl: map['originalUrl'] as String? ?? '',
      fileSizeBytes: map['fileSizeBytes'] as int? ?? 0,
      downloadedAt: DateTime.fromMillisecondsSinceEpoch(
        map['downloadedAt'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
      author: map['author'] as String? ?? 'Unknown creator',
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      galleryUri: map['galleryUri'] as String?,
      mediaType: map['mediaType'] as String? ?? 'video',
      authorId: map['authorId'] as String? ?? '',
      authorAvatarUrl: map['authorAvatarUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'filePath': filePath,
    'thumbnailUrl': thumbnailUrl,
    'originalUrl': originalUrl,
    'fileSizeBytes': fileSizeBytes,
    'downloadedAt': downloadedAt.millisecondsSinceEpoch,
    'author': author,
    'durationSeconds': durationSeconds,
    'galleryUri': galleryUri,
    'mediaType': mediaType,
    'authorId': authorId,
    'authorAvatarUrl': authorAvatarUrl,
  };
}
