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
      'active state stacks three width-invariant cues: accent fill, accent '
      'border, and high-emphasis ink',
      (tester) async {
        await pump(tester, active: true);

        // Accent fill (the stronger `active` step, not the faint `selected`).
        expect(fillOf(tester).color, tokens.colors.surface.active);
        // Brand-accent border.
        final border = borderOf(tester);
        expect(border.top.color, tokens.colors.interactive.enabled);
        // High-emphasis ink (kept off the accent so it clears AA on the fill).
        expect(labelOf(tester).style?.color, tokens.colors.text.highEmphasis);
      },
    );

    testWidgets(
      'inactive outlined pill keeps a quiet resting border, no fill',
      (
        tester,
      ) async {
        await pump(tester, active: false, outlined: true);

        expect(fillOf(tester).color, Colors.transparent);
        expect(borderOf(tester).top.color, tokens.colors.decorative.level02);
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

    testWidgets(
      'toggling active does not change border width or font weight, so the '
      'pill keeps its width (no header jump)',
      (tester) async {
        await pump(tester, active: false, outlined: true);
        final inactiveWidth = borderOf(tester).top.width;
        final inactiveWeight = labelOf(tester).style?.fontWeight;

        await pump(tester, active: true, outlined: true);
        // Border stroke and label weight are identical in both states — only
        // colour/fill change — so the active pill is exactly as wide.
        expect(borderOf(tester).top.width, inactiveWidth);
        expect(labelOf(tester).style?.fontWeight, inactiveWeight);
      },
    );

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
