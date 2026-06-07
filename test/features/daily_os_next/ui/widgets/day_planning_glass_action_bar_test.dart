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
  });
}
