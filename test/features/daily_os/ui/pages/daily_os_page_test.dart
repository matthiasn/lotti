import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/features/daily_os/ui/widgets/daily_timeline.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_header.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_summary.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_list.dart';

import '../../../../test_helper.dart';

/// Mock controller that returns a fixed DayPlanEntry.
class _TestDayPlanController extends DayPlanController {
  _TestDayPlanController(this._entry);

  final DayPlanEntry? _entry;

  @override
  Future<JournalEntity?> build({required DateTime date}) async {
    return _entry;
  }
}

/// Mock controller that returns fixed budget progress data.
class _TestBudgetProgressController extends TimeBudgetProgressController {
  _TestBudgetProgressController(this._budgets);

  final List<TimeBudgetProgress> _budgets;

  @override
  Future<List<TimeBudgetProgress>> build({required DateTime date}) async {
    return _budgets;
  }
}

/// Mock controller that returns fixed timeline data.
class _TestTimelineController extends TimelineDataController {
  _TestTimelineController(this._data);

  final DailyTimelineData _data;

  @override
  Future<DailyTimelineData> build({required DateTime date}) async {
    return _data;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  DayPlanEntry createTestPlan({
    DayPlanStatus status = const DayPlanStatus.draft(),
    List<PlannedBlock> plannedBlocks = const [],
  }) {
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(testDate),
        createdAt: testDate,
        updatedAt: testDate,
        dateFrom: testDate,
        dateTo: testDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: testDate,
        status: status,
        plannedBlocks: plannedBlocks,
      ),
    );
  }

  DailyTimelineData createTestTimelineData() {
    return DailyTimelineData(
      date: testDate,
      plannedSlots: [],
      actualSlots: [],
      dayStartHour: 8,
      dayEndHour: 18,
    );
  }

  Widget createTestWidget({
    DayPlanEntry? plan,
    DayBudgetStats? stats,
    List<Override> additionalOverrides = const [],
  }) {
    final effectivePlan = plan ?? createTestPlan();
    final effectiveStats = stats ??
        const DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWithValue(testDate),
        dayPlanControllerProvider(date: testDate).overrideWith(
          () => _TestDayPlanController(effectivePlan),
        ),
        dayBudgetStatsProvider(date: testDate).overrideWith(
          (ref) async => effectiveStats,
        ),
        timeBudgetProgressControllerProvider(date: testDate).overrideWith(
          () => _TestBudgetProgressController([]),
        ),
        timelineDataControllerProvider(date: testDate).overrideWith(
          () => _TestTimelineController(createTestTimelineData()),
        ),
        ...additionalOverrides,
      ],
      child: const DailyOsPage(),
    );
  }

  group('DailyOsPage', () {
    testWidgets('renders main structure', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DailyOsPage), findsOneWidget);
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
    });

    testWidgets('contains DayHeader', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DayHeader), findsOneWidget);
    });

    testWidgets('contains DailyTimeline', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DailyTimeline), findsOneWidget);
    });

    testWidgets('contains TimeBudgetList', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TimeBudgetList), findsOneWidget);
    });

    testWidgets('contains DaySummary', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(DaySummary), findsOneWidget);
    });

    testWidgets('has FloatingActionButton', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    testWidgets('has RefreshIndicator for pull-to-refresh', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('shows draft banner when plan is draft', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          plan: createTestPlan(),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the draft message and agree button
      expect(find.text('Agree to Plan'), findsOneWidget);
    });

    testWidgets('shows review banner when plan needs review', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          plan: createTestPlan(
            status: DayPlanStatus.needsReview(
              triggeredAt: testDate,
              reason: DayPlanReviewReason.blockModified,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show the re-agree button
      expect(find.text('Re-agree'), findsOneWidget);
    });

    testWidgets('does not show banner when plan is agreed', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          plan: createTestPlan(
            status: DayPlanStatus.agreed(agreedAt: testDate),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should not show agree or re-agree buttons
      expect(find.text('Agree to Plan'), findsNothing);
      expect(find.text('Re-agree'), findsNothing);
    });

    testWidgets('is scrollable', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('has SafeArea', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(SafeArea), findsOneWidget);
    });

    testWidgets('FAB is tappable', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);

      // Verify the FAB has an onPressed callback
      final fabWidget = tester.widget<FloatingActionButton>(fab);
      expect(fabWidget.onPressed, isNotNull);
    });

    testWidgets('agree button is tappable', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          plan: createTestPlan(),
        ),
      );
      await tester.pumpAndSettle();

      final agreeButton = find.widgetWithText(TextButton, 'Agree to Plan');
      expect(agreeButton, findsOneWidget);

      final buttonWidget = tester.widget<TextButton>(agreeButton);
      expect(buttonWidget.onPressed, isNotNull);
    });

    testWidgets('shows correct layout structure', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Main column for header + content
      expect(find.byType(Column), findsWidgets);
      // Expanded widget for scrollable content
      expect(find.byType(Expanded), findsAtLeastNWidgets(1));
    });
  });
}
