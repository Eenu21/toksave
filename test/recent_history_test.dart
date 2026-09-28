import 'package:flutter_test/flutter_test.dart';
import 'package:toksave/models/frequent_creator.dart';
import 'package:toksave/models/recent_video.dart';

void main() {
  test('recent video history parses its cached metadata', () {
    final viewedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final video = RecentVideo.fromMap({
      'id': 'video-id',
      'title': 'A saved video',
      'author': 'Creator',
      'thumbnailUrl': 'https://example.com/thumb.jpg',
      'sourceUrl': 'https://www.tiktok.com/@creator/video/video-id',
      'authorId': 'creator',
      'authorAvatarUrl': 'https://example.com/avatar.jpg',
      'durationSeconds': 12,
      'lastViewedAt': viewedAt.millisecondsSinceEpoch,
    });

    expect(video.id, 'video-id');
    expect(video.title, 'A saved video');
    expect(video.thumbnailUrl, 'https://example.com/thumb.jpg');
    expect(video.durationSeconds, 12);
    expect(video.lastViewedAt.toUtc(), viewedAt);
  });

  test('frequent creator history parses profile visit counts', () {
    final visitedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);
    final creator = FrequentCreator.fromMap({
      'username': 'creator',
      'displayName': 'Creator',
      'avatarUrl': 'https://example.com/avatar.jpg',
      'profileUrl': 'https://www.tiktok.com/@creator',
      'visitCount': 4,
      'lastVisitedAt': visitedAt.millisecondsSinceEpoch,
    });

    expect(creator.username, 'creator');
    expect(creator.visitCount, 4);
    expect(creator.lastVisitedAt.toUtc(), visitedAt);
  });
}
