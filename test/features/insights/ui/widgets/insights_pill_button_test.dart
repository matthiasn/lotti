import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_pill_button.dart';

import '../../../../widget_test_utils.dart';

void main() {
  const tokens = dsTokensLight;

  Future<void> pump(
    WidgetTester tester, {
    required bool active,
    bool outlined = false,
    String? tooltip,
    VoidCallback? onTap,
  }) {
    return tester.pumpWidget(
      makeTestableWidgetWithScaffold(
        InsightsPillButton(
          label: 'Week',
          active: active,
          outlined: outlined,
          tooltip: tooltip,
          onTap: onTap ?? () {},
        ),
      ),
    );
  }

  Border borderOf(WidgetTester tester) {
    final box = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(InsightsPillButton),
        matching: find.byType(DecoratedBox),
      ),
    );
    return (box.decoration as BoxDecoration).border! as Border;
  }

  Material fillOf(WidgetTester tester) => tester.widget<Material>(
    find.descendant(
      of: find.byType(InsightsPillButton),
      matching: find.byType(Material),
    ),
  );

  Text labelOf(WidgetTester tester) => tester.widget<Text>(find.text('Week'));

  group('InsightsPillButton', () {
    testWidgets(
      'active state stacks four cues: accent fill, accent border, heavier '
      'stroke, and semibold ink',
      (tester) async {
        await pump(tester, active: true);

        // Accent fill (the stronger `active` step, not the faint `selected`).
        expect(fillOf(tester).color, tokens.colors.surface.active);
        // Brand-accent border at the heavier 1.5px stroke.
        final border = borderOf(tester);
        expect(border.top.color, tokens.colors.interactive.enabled);
        expect(border.top.width, 1.5);
        // High-emphasis semibold label (kept off the accent so it clears AA on
        // the tinted fill).
        final label = labelOf(tester);
        expect(label.style?.color, tokens.colors.text.highEmphasis);
        expect(label.style?.fontWeight, tokens.typography.weight.semiBold);
      },
    );

    testWidgets(
      'inactive outlined pill keeps a quiet resting border, no fill',
      (
        tester,
      ) async {
        await pump(tester, active: false, outlined: true);

        expect(fillOf(tester).color, Colors.transparent);
        final border = borderOf(tester);
        expect(border.top.color, tokens.colors.decorative.level02);
        expect(border.top.width, 1.0);
        expect(labelOf(tester).style?.color, tokens.colors.text.mediumEmphasis);
      },
    );

    testWidgets('inactive non-outlined pill has no border and no fill', (
      tester,
    ) async {
      await pump(tester, active: false);

      expect(fillOf(tester).color, Colors.transparent);
      expect(borderOf(tester).top.color, Colors.transparent);
    });

    testWidgets('renders the tooltip message when provided', (tester) async {
      await pump(tester, active: false, tooltip: 'This month so far');
      expect(
        find.byTooltip('This month so far'),
        findsOneWidget,
      );
    });

    testWidgets('invokes onTap when pressed', (tester) async {
      var taps = 0;
      await pump(tester, active: false, onTap: () => taps++);
      await tester.tap(find.byType(InsightsPillButton));
      expect(taps, 1);
    });
  });
}
