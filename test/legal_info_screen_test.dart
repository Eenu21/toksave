import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:toksave/screens/legal_info_screen.dart';

void main() {
  testWidgets('privacy policy explains local history and provider requests', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalInfoScreen(document: LegalDocument.privacy)),
    );

    expect(find.text('Privacy policy'), findsOneWidget);
    expect(find.text('Information TokSave stores'), findsOneWidget);
    expect(find.text('Requests to video services'), findsOneWidget);
    expect(find.textContaining('sends the TikTok link'), findsOneWidget);
    for (var scroll = 0; scroll < 4; scroll++) {
      await tester.drag(find.byType(ListView), const Offset(0, -450));
      await tester.pumpAndSettle();
    }
    expect(find.text('Advertising'), findsOneWidget);
  });

  testWidgets('terms of use are available as an in-app page', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LegalInfoScreen(document: LegalDocument.terms)),
    );

    expect(find.text('Terms of use'), findsOneWidget);
    expect(find.text('Use content responsibly'), findsOneWidget);
    expect(find.text('Third-party services'), findsOneWidget);
  });
}
