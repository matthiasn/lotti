import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/ui/agent_chat_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widget_test_utils.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required VoidCallback onPressed,
    String? label,
  }) => tester.pumpWidget(
    makeTestableWidgetWithScaffold(
      Center(
        child: AgentChatButton(onPressed: onPressed, label: label),
      ),
    ),
  );

  testWidgets("wears the AI card's accent pair and the agent's sparkle", (
    tester,
  ) async {
    await pump(tester, onPressed: () {});

    final ai = tester
        .element(find.byType(AgentChatButton))
        .designTokens
        .colors
        .aiCard;
    final label = tester.widget<Text>(find.text('Talk to agent'));
    expect(label.style?.color, ai.accent);
    final glyph = tester.widget<Icon>(find.byIcon(LottiIcons.aiSpark));
    expect(glyph.color, ai.accent);
    final fill = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AgentChatButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .single;
    expect(fill.color, ai.accentSoft);
  });

  testWidgets('a tap opens the conversation', (tester) async {
    var pressed = 0;
    await pump(tester, onPressed: () => pressed++);

    await tester.tap(find.byType(AgentChatButton));
    expect(pressed, 1);
  });

  testWidgets('a host may name the agent, and the label is announced', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pump(tester, onPressed: () {}, label: 'Talk to Juno');

    expect(find.text('Talk to Juno'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(AgentChatButton)),
      matchesSemantics(
        label: 'Talk to Juno',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the whole recommended target answers, not only the pill', (
    tester,
  ) async {
    var pressed = 0;
    await pump(tester, onPressed: () => pressed++, label: 'Chat');

    final target = tester.getRect(find.byType(AgentChatButton));
    expect(target.height, greaterThanOrEqualTo(TapTargets.minimum));
    // The visible pill is shorter than the target; a tap in the margin
    // above it must still open the conversation.
    final pill = tester.getRect(
      find
          .descendant(
            of: find.byType(AgentChatButton),
            matching: find.byType(DecoratedBox),
          )
          .last,
    );
    expect(pill.height, lessThan(target.height));
    await tester.tapAt(Offset(target.center.dx, target.top + 2));
    expect(pressed, 1);
  });

  testWidgets('hovered, the border firms to the full accent', (tester) async {
    await pump(tester, onPressed: () {});
    final ai = tester
        .element(find.byType(AgentChatButton))
        .designTokens
        .colors
        .aiCard;
    ShapeDecoration pill() => tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(AgentChatButton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .single;
    Color border() => (pill().shape as RoundedRectangleBorder).side.color;
    expect(border(), ai.border);

    await _hover(tester, find.byType(AgentChatButton));

    expect(border(), ai.accent);
  });
}

/// Puts a mouse over [target] and settles, so hover styling shows.
Future<void> _hover(WidgetTester tester, Finder target) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(tester.getCenter(target));
  await tester.pumpAndSettle();
}
