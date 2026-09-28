class SavedCreator {
  const SavedCreator({
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.profileUrl,
    required this.lastDownloadedAt,
    required this.downloadCount,
  });

  final String username;
  final String displayName;
  final String avatarUrl;
  final String profileUrl;
  final DateTime lastDownloadedAt;
  final int downloadCount;

  factory SavedCreator.fromMap(Map<String, Object?> map) => SavedCreator(
    username: map['username'] as String,
    displayName: map['displayName'] as String,
    avatarUrl: map['avatarUrl'] as String? ?? '',
    profileUrl: map['profileUrl'] as String? ?? '',
    lastDownloadedAt: DateTime.fromMillisecondsSinceEpoch(
      map['lastDownloadedAt'] as int,
    ),
    downloadCount: map['downloadCount'] as int? ?? 0,
  );
}
