class TikTokCreator {
  const TikTokCreator({
    required this.username,
    required this.displayName,
    this.avatarUrl = '',
    this.signature = '',
  });

  final String username;
  final String displayName;
  final String avatarUrl;
  final String signature;
}
