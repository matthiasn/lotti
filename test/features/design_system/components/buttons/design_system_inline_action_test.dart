import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_inline_action.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../widget_test_utils.dart';

void main() {
  Future<void> pumpAction(
    WidgetTester tester,
    Widget action, {
    double width = 600,
  }) {
    tester.view
      ..physicalSize = Size(width, 400)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    // A stretching parent is the case the component exists to survive: it is
    // what silently inflated the open-coded versions this replaced.
    return tester.pumpWidget(
      makeTestableWidget(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [action],
        ),
      ),
    );
  }

  DsTokens tokensOf(WidgetTester tester) =>
      tester.element(find.byType(DesignSystemInlineAction)).designTokens;

  /// The node the component annotates. Addressed through the ink rather than
  /// through the component root, which is an `Align` that owns no semantics —
  /// walking up from it lands on the test harness root instead.
  SemanticsNode actionSemantics(WidgetTester tester) =>
      tester.getSemantics(find.byType(InkWell));

  testWidgets('fires its callback and announces itself as a button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await pumpAction(
      tester,
      DesignSystemInlineAction(
        label: 'Skip once',
        semanticsLabel: 'Cancel pending automatic update',
        onTap: () => taps++,
      ),
    );

    // Tap the control, not the slot: the widget fills its parent while the
    // ink hugs its content, so the centre of the slot is deliberately dead.
    await tester.tap(find.text('Skip once'));
    expect(taps, 1);
    expect(
      actionSemantics(tester),
      matchesSemantics(
        label: 'Cancel pending automatic update',
        isButton: true,
        isEnabled: true,
        isFocusable: true,
        hasEnabledState: true,
        hasFocusAction: true,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the ink hugs its content inside a stretching parent', (
    tester,
  ) async {
    const width = 700.0;
    await pumpAction(
      tester,
      const DesignSystemInlineAction(
        label: 'Change AI setup',
        semanticsLabel: 'Change AI setup',
        leadingIcon: LottiIcons.reasoning,
        trailingIcon: LottiIcons.chevronRight,
        onTap: null,
      ),
      width: width,
    );

    final tokens = tokensOf(tester);
    final ink = tester.getRect(find.byType(InkWell));

    // The whole point: a stretching Column hands children a tight width, and
    // an open-coded row would take all of it.
    expect(ink.width, lessThan(width));
    expect(
      tester.getRect(find.byIcon(LottiIcons.reasoning)).left - ink.left,
      moreOrLessEquals(tokens.spacing.step2, epsilon: 0.5),
    );
    expect(
      ink.right - tester.getRect(find.byIcon(LottiIcons.chevronRight)).right,
      moreOrLessEquals(tokens.spacing.step2, epsilon: 0.5),
    );
    expect(ink.height, greaterThanOrEqualTo(tokens.spacing.step8));
  });

  testWidgets('tooltip and semantics bounds stop at the ink, not the slot', (
    tester,
  ) async {
    // Asserting on the InkWell alone was not enough: an earlier revision
    // wrapped the Tooltip and Semantics *around* the Align, so both inherited
    // the full stretched width. The tooltip then fired over blank space and
    // the focus rectangle covered places where a tap does nothing.
    const width = 700.0;
    final semantics = tester.ensureSemantics();
    await pumpAction(
      tester,
      const DesignSystemInlineAction(
        label: 'Change AI setup',
        semanticsLabel: 'Current setup: Qwen 3.5 Plus. Activate to change.',
        tooltip: 'Change AI setup',
        leadingIcon: LottiIcons.reasoning,
        onTap: null,
      ),
      width: width,
    );

    final ink = tester.getRect(find.byType(InkWell));
    expect(tester.getRect(find.byType(Tooltip)).width, ink.width);
    expect(
      tester
          .getRect(
            find
                .ancestor(
                  of: find.byType(Tooltip),
                  matching: find.byType(Semantics),
                )
                .first,
          )
          .width,
      ink.width,
    );
    expect(ink.width, lessThan(width));

    // The tooltip must not also announce itself: the semantics label already
    // carries the action, so publishing both reads it out twice.
    expect(
      tester.widget<Tooltip>(find.byType(Tooltip)).excludeFromSemantics,
      isTrue,
    );
    expect(
      actionSemantics(tester),
      matchesSemantics(
        label: 'Current setup: Qwen 3.5 Plus. Activate to change.',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('a disabled action still renders, and reports itself disabled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpAction(
      tester,
      const DesignSystemInlineAction(
        label: 'Skip once',
        semanticsLabel: 'Cancel pending automatic update',
        onTap: null,
      ),
    );

    // A control that vanishes when unavailable is the defect this whole
    // footer redesign started from.
    expect(find.text('Skip once'), findsOneWidget);
    expect(
      actionSemantics(tester),
      matchesSemantics(
        label: 'Cancel pending automatic update',
        isButton: true,
        hasEnabledState: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('the label and the glyph can be inked independently', (
    tester,
  ) async {
    const ink = Color(0xFF112233);
    const iconInk = Color(0xFF445566);
    await pumpAction(
      tester,
      DesignSystemInlineAction(
        label: 'Skip once',
        semanticsLabel: 'Skip once',
        leadingIcon: LottiIcons.schedule,
        ink: ink,
        iconInk: iconInk,
        onTap: () {},
      ),
    );

    final text = tester.widget<Text>(find.text('Skip once'));
    expect(text.style?.color, ink);
    expect(
      tester.widget<Icon>(find.byIcon(LottiIcons.schedule)).color,
      iconInk,
    );
  });

  testWidgets('the component never decorates its label', (tester) async {
    // One affordance language for the whole family: glyph, ink and the shared
    // hover fill. An underline here let a caption-tier action out-decorate the
    // value it acts on, so the knob is gone rather than merely unused.
    await pumpAction(
      tester,
      DesignSystemInlineAction(
        label: 'Skip once',
        semanticsLabel: 'Skip once',
        onTap: () {},
      ),
    );

    final text = tester.widget<Text>(find.text('Skip once'));
    expect(text.style?.decoration, anyOf(isNull, TextDecoration.none));
  });

  testWidgets('a labelWidget replaces the label and still shrink-wraps', (
    tester,
  ) async {
    await pumpAction(
      tester,
      const DesignSystemInlineAction(
        semanticsLabel: 'Current setup',
        leadingIcon: LottiIcons.reasoning,
        labelWidget: SizedBox(width: 80, height: 12),
        onTap: null,
      ),
    );

    final tokens = tokensOf(tester);
    final ink = tester.getRect(find.byType(InkWell));
    // icon + gap + 80 + two step2 insets — nowhere near the 600 on offer.
    expect(
      ink.width,
      moreOrLessEquals(
        tokens.spacing.step5 + tokens.spacing.step2 * 3 + 80,
        epsilon: 1,
      ),
    );
  });
}
