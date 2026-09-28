import 'package:flutter_test/flutter_test.dart';
import 'package:toksave/core/utils/url_utils.dart';

void main() {
  test('accepts TikTok video and short-link hosts', () {
    expect(isTikTokUrl('https://www.tiktok.com/@creator/video/123'), isTrue);
    expect(isTikTokUrl('https://vt.tiktok.com/abc123/'), isTrue);
  });

  test('rejects lookalike non-TikTok hosts', () {
    expect(isTikTokUrl('https://not-tiktok.com/@creator/video/123'), isFalse);
    expect(isTikTokUrl('https://tiktok.com.example.org/@creator'), isFalse);
  });

  test('recognizes video links but not creator profile URLs', () {
    expect(
      isTikTokVideoUrl('https://www.tiktok.com/@creator/video/123456'),
      isTrue,
    );
    expect(isTikTokVideoUrl('https://vm.tiktok.com/abc123/'), isTrue);
    expect(isTikTokVideoUrl('https://www.tiktok.com/@creator'), isFalse);
    expect(isTikTokVideoUrl('https://example.com/@creator/video/123'), isFalse);
  });
}
