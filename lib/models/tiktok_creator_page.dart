import 'tiktok_creator.dart';
import 'tiktok_video.dart';

class TikTokCreatorPage {
  const TikTokCreatorPage({
    required this.creator,
    required this.videos,
    required this.hasMore,
    this.nextCursor,
  });

  final TikTokCreator creator;
  final List<TikTokVideo> videos;
  final bool hasMore;
  final String? nextCursor;
}
