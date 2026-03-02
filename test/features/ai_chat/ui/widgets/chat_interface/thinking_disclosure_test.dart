import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  testWidgets('ThinkingDisclosure toggles expansion', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ThinkingDisclosure(thinking: 'internal plan'),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ThinkingDisclosure));
    final messages = context.messages;

    // Initially shows "Show reasoning"
    expect(find.text(messages.thinkingDisclosureShow), findsOneWidget);

    // Tap to expand
    await tester.tap(find.text(messages.thinkingDisclosureShow));
    await tester.pumpAndSettle();

    expect(find.text(messages.thinkingDisclosureHide), findsOneWidget);
    // The content should become visible (rendered by GptMarkdown)
    expect(find.textContaining('internal plan'), findsOneWidget);
  });

  testWidgets('Keyboard toggles expansion and copy shows snackbar',
      (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ThinkingDisclosure(thinking: 'internal plan'),
      ),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ThinkingDisclosure));
    final messages = context.messages;

    // Toggle open via tap
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.text(messages.thinkingDisclosureHide), findsOneWidget);

    // Use copy action while expanded
    await tester.pumpAndSettle();
    // Tap the actual IconButton inside the tooltip
    final copyButton = find.descendant(
      of: find.byTooltip(messages.thinkingDisclosureCopy),
      matching: find.byType(IconButton),
    );
    await tester.tap(copyButton);
    await tester.pump();
  });
}
