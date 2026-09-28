class FrequentCreator {
  const FrequentCreator({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.profileUrl,
    required this.visitCount,
    required this.lastVisitedAt,
  });

  final String username;
  final String displayName;
  final String avatarUrl;
  final String profileUrl;
  final int visitCount;
  final DateTime lastVisitedAt;

  factory FrequentCreator.fromMap(Map<String, Object?> map) => FrequentCreator(
    username: map['username'] as String,
    displayName: map['displayName'] as String,
    avatarUrl: map['avatarUrl'] as String? ?? '',
    profileUrl: map['profileUrl'] as String,
    visitCount: map['visitCount'] as int? ?? 0,
    lastVisitedAt: DateTime.fromMillisecondsSinceEpoch(
      map['lastVisitedAt'] as int,
    ),
  );
}
