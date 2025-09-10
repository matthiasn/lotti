import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';

void main() {
  Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('ThinkingDisclosure toggles expansion', (tester) async {
    await tester
        .pumpWidget(_wrap(const ThinkingDisclosure(thinking: 'internal plan')));

    // Initially shows "Show reasoning"
    expect(find.text('Show reasoning'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('Show reasoning'));
    await tester.pumpAndSettle();

    expect(find.text('Hide reasoning'), findsOneWidget);
    // The content should become visible (rendered by GptMarkdown)
    expect(find.textContaining('internal plan'), findsOneWidget);
  });
}
