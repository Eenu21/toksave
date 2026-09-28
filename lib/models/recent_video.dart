class RecentVideo {
  const RecentVideo({
    required this.id,
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.sourceUrl,
    required this.authorId,
    required this.authorAvatarUrl,
    required this.durationSeconds,
    required this.lastViewedAt,
  });

  final String id;
  final String title;
  final String author;
  final String thumbnailUrl;
  final String sourceUrl;
  final String authorId;
  final String authorAvatarUrl;
  final int durationSeconds;
  final DateTime lastViewedAt;

  factory RecentVideo.fromMap(Map<String, Object?> map) => RecentVideo(
    id: map['id'] as String,
    title: map['title'] as String,
    author: map['author'] as String,
    thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
    sourceUrl: map['sourceUrl'] as String,
    authorId: map['authorId'] as String? ?? '',
    authorAvatarUrl: map['authorAvatarUrl'] as String? ?? '',
    durationSeconds: map['durationSeconds'] as int? ?? 0,
    lastViewedAt: DateTime.fromMillisecondsSinceEpoch(
      map['lastViewedAt'] as int,
    ),
  );
}
