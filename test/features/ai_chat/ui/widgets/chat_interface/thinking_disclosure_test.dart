import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface/thinking_disclosure.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

import '../../../../../widget_test_utils.dart';

void main() {
  setUp(setUpTestGetIt);
  tearDown(tearDownTestGetIt);

  // The disclosure header rotates a chevron with a 170ms AnimatedRotation; the
  // body itself appears/disappears synchronously via `if (_expanded)`. A bounded
  // pump past the rotation duration is deterministic and avoids the 10s
  // pumpAndSettle timeout risk.
  const settleRotation = Duration(milliseconds: 200);

  testWidgets('ThinkingDisclosure toggles expansion', (tester) async {
    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ThinkingDisclosure(thinking: 'internal plan'),
      ),
    );
    // Read the very first rendered tree (no animation pumped yet) to prove the
    // disclosure is collapsed by default before any interaction.
    await tester.pump();

    final context = tester.element(find.byType(ThinkingDisclosure));
    final messages = context.messages;

    // Initially shows "Show reasoning" and the thinking body is NOT in the tree.
    expect(find.text(messages.thinkingDisclosureShow), findsOneWidget);
    expect(find.text(messages.thinkingDisclosureHide), findsNothing);
    expect(find.textContaining('internal plan'), findsNothing);
    expect(
      find.bySemanticsLabel(
        '${messages.thinkingDisclosureShow}, '
        '${messages.thinkingDisclosureStateCollapsed}',
      ),
      findsOneWidget,
    );

    // Tap to expand
    await tester.tap(find.text(messages.thinkingDisclosureShow));
    await tester.pump(settleRotation);

    expect(find.text(messages.thinkingDisclosureHide), findsOneWidget);
    expect(find.text(messages.thinkingDisclosureShow), findsNothing);
    expect(
      find.bySemanticsLabel(
        '${messages.thinkingDisclosureHide}, '
        '${messages.thinkingDisclosureStateExpanded}',
      ),
      findsOneWidget,
    );
    // The content should become visible (rendered by GptMarkdown)
    expect(find.textContaining('internal plan'), findsOneWidget);

    // Collapsing again removes the body from the tree.
    await tester.tap(find.text(messages.thinkingDisclosureHide));
    await tester.pump(settleRotation);
    expect(find.text(messages.thinkingDisclosureShow), findsOneWidget);
    expect(find.textContaining('internal plan'), findsNothing);
  });

  testWidgets('Keyboard toggles expansion and copy action writes clipboard', (
    tester,
  ) async {
    String? copiedText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<dynamic, dynamic>;
            copiedText = args['text'] as String?;
          }
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );

    await tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        const ThinkingDisclosure(thinking: 'internal plan'),
      ),
    );
    await tester.pump();

    final context = tester.element(find.byType(ThinkingDisclosure));
    final messages = context.messages;

    // Toggle open via tap
    await tester.tap(find.byType(InkWell).first);
    await tester.pump(settleRotation);
    expect(find.text(messages.thinkingDisclosureHide), findsOneWidget);

    // Trigger keyboard shortcut callbacks directly to validate both bindings.
    final shortcuts = tester.widget<CallbackShortcuts>(
      find.byType(CallbackShortcuts),
    );
    shortcuts.bindings[const SingleActivator(LogicalKeyboardKey.enter)]!.call();
    await tester.pump();
    expect(find.text(messages.thinkingDisclosureShow), findsOneWidget);
    shortcuts.bindings[const SingleActivator(LogicalKeyboardKey.space)]!.call();
    await tester.pump();
    expect(find.text(messages.thinkingDisclosureHide), findsOneWidget);

    // Use copy action while expanded
    final copyButton = find.descendant(
      of: find.byTooltip(messages.thinkingDisclosureCopy),
      matching: find.byType(IconButton),
    );
    await tester.tap(copyButton);
    await tester.pump();
    expect(copiedText, 'internal plan');
  });
}
