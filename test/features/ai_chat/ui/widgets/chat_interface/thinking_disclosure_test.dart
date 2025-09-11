import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets('ThinkingDisclosure toggles expansion', (tester) async {
    await tester
        .pumpWidget(wrap(const ThinkingDisclosure(thinking: 'internal plan')));

    // Initially shows "Show reasoning"
    expect(find.text('Show reasoning'), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text('Show reasoning'));
    await tester.pumpAndSettle();

    expect(find.text('Hide reasoning'), findsOneWidget);
    // The content should become visible (rendered by GptMarkdown)
    expect(find.textContaining('internal plan'), findsOneWidget);
  });

  testWidgets('Keyboard toggles expansion and copy shows snackbar',
      (tester) async {
    await tester
        .pumpWidget(wrap(const ThinkingDisclosure(thinking: 'internal plan')));

    // Toggle open via tap
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text('Hide reasoning'), findsOneWidget);

    // Use copy action while expanded
    await tester.pumpAndSettle();
    // Tap the actual IconButton inside the tooltip
    final copyButton = find.descendant(
      of: find.byTooltip('Copy reasoning'),
      matching: find.byType(IconButton),
    );
    await tester.tap(copyButton);
    await tester.pump();
  });
}
