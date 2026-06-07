import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/day_planning_glass_action_bar.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_system_theme.dart';

import '../../../../widget_test_utils.dart';

void main() {
  group('DayPlanningGlassActionBar', () {
    testWidgets('renders the actions on a shared glass strip', (tester) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningGlassActionBar(
            actions: Text('actions-row'),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byType(DesignSystemGlassStrip), findsOneWidget);
      expect(find.text('actions-row'), findsOneWidget);
      expect(find.byKey(DayPlanningGlassActionBar.topSlotKey), findsNothing);
    });

    testWidgets('places the topSlot above the actions when provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningGlassActionBar(
            topSlot: SizedBox(height: 12, child: Text('shader')),
            actions: Text('actions-row'),
          ),
          theme: DesignSystemTheme.light(),
        ),
      );

      expect(find.byKey(DayPlanningGlassActionBar.topSlotKey), findsOneWidget);

      final shaderY = tester
          .getCenter(find.byKey(DayPlanningGlassActionBar.topSlotKey))
          .dy;
      final actionsY = tester.getCenter(find.text('actions-row')).dy;
      expect(shaderY, lessThan(actionsY));
    });

    testWidgets('extends its bottom padding by the safe-area inset', (
      tester,
    ) async {
      const inset = 34.0;
      await tester.pumpWidget(
        makeTestableWidgetWithScaffold(
          const DayPlanningGlassActionBar(actions: Text('actions-row')),
          theme: DesignSystemTheme.light(),
          mediaQueryData: const MediaQueryData(
            size: Size(420, 900),
            padding: EdgeInsets.only(bottom: inset),
          ),
        ),
      );

      // The bar's content padding: equal horizontal (step5), equal top
      // (step4), and a bottom of step4 + the system home-indicator inset.
      final padding = tester
          .widgetList<Padding>(
            find.descendant(
              of: find.byType(DayPlanningGlassActionBar),
              matching: find.byType(Padding),
            ),
          )
          .map((p) => p.padding)
          .whereType<EdgeInsets>()
          .firstWhere((e) => e.left == e.right && e.left > 0 && e.top > 0);

      expect(padding.bottom - padding.top, inset);
    });
  });
}
