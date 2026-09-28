import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toksave/models/download_progress.dart';
import 'package:toksave/widgets/url_input_field.dart';

void main() {
  testWidgets('TikTok URL input displays its hint and accepts a link', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UrlInputField(
            controller: controller,
            onPaste: () {},
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('https://www.tiktok.com/...'), findsOneWidget);
    await tester.enterText(
      find.byType(TextField),
      'https://www.tiktok.com/@creator/video/123',
    );
    expect(controller.text, 'https://www.tiktok.com/@creator/video/123');

    controller.dispose();
  });

  test('download progress reports percentages and caps at 100%', () {
    expect(
      const DownloadProgress(receivedBytes: 240, totalBytes: 1000).percent,
      24,
    );
    expect(
      const DownloadProgress(receivedBytes: 1200, totalBytes: 1000).percent,
      100,
    );
  });
}
