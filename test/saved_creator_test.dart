import 'package:flutter_test/flutter_test.dart';
import 'package:toksave/models/saved_creator.dart';

void main() {
  test('SavedCreator parses creator history from a database row', () {
    final downloadedAt = DateTime.utc(2026, 1, 2, 3, 4, 5);

    final creator = SavedCreator.fromMap({
      'username': 'sample_creator',
      'displayName': 'Sample Creator',
      'avatarUrl': 'https://example.com/avatar.jpg',
      'profileUrl': 'https://www.tiktok.com/@sample_creator',
      'lastDownloadedAt': downloadedAt.millisecondsSinceEpoch,
      'downloadCount': 3,
    });

    expect(creator.username, 'sample_creator');
    expect(creator.displayName, 'Sample Creator');
    expect(creator.avatarUrl, 'https://example.com/avatar.jpg');
    expect(creator.profileUrl, 'https://www.tiktok.com/@sample_creator');
    expect(creator.lastDownloadedAt.toUtc(), downloadedAt);
    expect(creator.downloadCount, 3);
  });
}
