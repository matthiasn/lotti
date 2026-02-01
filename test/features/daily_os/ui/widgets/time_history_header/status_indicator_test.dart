import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/status_indicator.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../../test_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestWidget(DayBudgetStats stats) {
    return WidgetTestBench(
      child: StatusIndicator(stats: stats),
    );
  }

  group('StatusIndicator', () {
    testWidgets('displays over budget indicator', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(hours: 2),
            totalRecorded: Duration(hours: 3),
            budgetCount: 1,
            overBudgetCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Over budget'), findsOneWidget);
      expect(find.byIcon(MdiIcons.alertCircle), findsOneWidget);
    });

    testWidgets('displays near limit indicator when close to budget',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(hours: 2),
            totalRecorded: Duration(hours: 1, minutes: 50),
            budgetCount: 1,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show "Near limit" indicator (10 mins remaining < 15)
      expect(find.text('Near limit'), findsOneWidget);
      expect(find.byIcon(MdiIcons.clockAlert), findsOneWidget);
    });

    testWidgets('displays on track indicator when progress is high',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 3, minutes: 30),
            budgetCount: 2,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3h30m / 4h = 87.5% progress, should show "On track"
      expect(find.text('On track'), findsOneWidget);
      expect(find.byIcon(MdiIcons.checkCircle), findsOneWidget);
    });

    testWidgets('displays hours in time remaining', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 1),
            budgetCount: 1,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 3 hours remaining (exact hours, no minutes)
      expect(find.text('3 hours left'), findsOneWidget);
    });

    testWidgets('displays hours with minutes in time remaining',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(hours: 3, minutes: 30),
            totalRecorded: Duration(hours: 1),
            budgetCount: 1,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 2h 30m remaining (hours and minutes)
      expect(find.text('2h 30m left'), findsOneWidget);
    });

    testWidgets('displays minutes only when less than an hour remaining',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(minutes: 60),
            totalRecorded: Duration(minutes: 25),
            budgetCount: 1,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 35 minutes remaining
      expect(find.text('35 minutes left'), findsOneWidget);
    });

    testWidgets('displays clock icon for time left state', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 1),
            budgetCount: 1,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.clockOutline), findsOneWidget);
    });

    testWidgets('has correct container styling', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          const DayBudgetStats(
            totalPlanned: Duration(hours: 2),
            totalRecorded: Duration(hours: 3),
            budgetCount: 1,
            overBudgetCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should have a container with decoration
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
    });
  });
}
