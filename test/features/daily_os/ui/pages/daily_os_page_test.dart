import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/pages/daily_os_page.dart';
import 'package:lotti/features/daily_os/ui/widgets/add_budget_sheet.dart'
    as add_block;
import 'package:lotti/features/daily_os/ui/widgets/daily_timeline.dart';
import 'package:lotti/features/daily_os/ui/widgets/day_summary.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_budget_list.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/time_history_header.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';

import '../../../../test_helper.dart';
import '../widgets/time_history_header/test_helpers.dart';

/// Mock controller that tracks agreeToPlan calls.
class _TrackingUnifiedController extends UnifiedDailyOsDataController {
  _TrackingUnifiedController(this._data);

  final DailyOsData _data;
  int agreeToPlanCallCount = 0;

  @override
  Future<DailyOsData> build() async {
    return _data;
  }

  @override
  Future<void> agreeToPlan() async {
    agreeToPlanCallCount++;
  }
}

/// Mock controller that always fails with an error.
class _ErrorUnifiedController extends UnifiedDailyOsDataController {
  @override
  Future<DailyOsData> build() async {
    throw Exception('test error');
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
    List<TimeBudgetProgress> budgetProgress = const [],
    List<Override> additionalOverrides = const [],
    UnifiedDailyOsDataController Function()? unifiedControllerFactory,
  }) {
    final effectivePlan = plan ?? createTestPlan();
    final effectiveStats =
        stats ??
        const DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );

    final unifiedData = DailyOsData(
      date: testDate,
      dayPlan: effectivePlan,
      timelineData: createTestTimelineData(),
      budgetProgress: budgetProgress,
    );

    // Create test history data for the header
    final historyData = TimeHistoryData(
      days: [
        DayTimeSummary(
          day: DateTime(testDate.year, testDate.month, testDate.day, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
      ],
      earliestDay: testDate,
      latestDay: testDate,
      maxDailyTotal: Duration.zero,
      categoryOrder: const [],
      isLoadingMore: false,
      canLoadMore: true,
      stackedHeights: const {},
    );

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWith(
          () => TestDailyOsSelectedDate(testDate),
        ),
        timeHistoryHeaderControllerProvider.overrideWith(
          () => TestTimeHistoryController(historyData),
        ),
        unifiedDailyOsDataControllerProvider(testDate).overrideWith(
          unifiedControllerFactory ?? () => TestUnifiedController(unifiedData),
        ),
        dayBudgetStatsProvider(testDate).overrideWith(
          (ref) async => effectiveStats,
        ),
        // Override stream provider to avoid timer issues in tests
        activeFocusCategoryIdProvider.overrideWith(
          (ref) => Stream.value(null),
        ),
        // Override to avoid TimeService dependency in tests
        runningTimerCategoryIdProvider.overrideWithBuild((_, _) => null),
        ...additionalOverrides,
      ],
      child: const DailyOsPage(),
    );
  }

  group('DailyOsPage', () {
    setUp(setUpEntitiesCacheService);
    tearDown(tearDownEntitiesCacheService);

    testWidgets('renders all primary structural sections', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // One pump, every structural element of the page contract: the
      // header, timeline, budget list, summary, pull-to-refresh, FAB, and
      // the scroll/safe-area shell.
      expect(find.byType(DailyOsPage), findsOneWidget);
      expect(find.byType(Scaffold), findsAtLeastNWidgets(1));
      expect(find.byType(TimeHistoryHeader), findsOneWidget);
      expect(find.byType(DailyTimeline), findsOneWidget);
      expect(find.byType(TimeBudgetList), findsOneWidget);
      expect(find.byType(DaySummary), findsOneWidget);
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(
        find.byType(DesignSystemBottomNavigationFabPadding),
        findsOneWidget,
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(find.byType(SafeArea), findsOneWidget);
      expect(find.byType(Expanded), findsAtLeastNWidgets(1));
    });

    testWidgets('shows draft banner when plan is draft', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          plan: createTestPlan(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should not show agree or re-agree buttons
      expect(find.text('Agree to Plan'), findsNothing);
      expect(find.text('Re-agree'), findsNothing);
    });

    testWidgets('agree button is tappable', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          plan: createTestPlan(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final agreeButton = find.widgetWithText(TextButton, 'Agree to Plan');
      expect(agreeButton, findsOneWidget);

      final buttonWidget = tester.widget<TextButton>(agreeButton);
      expect(buttonWidget.onPressed, isNotNull);
    });

    // --- Banner message content ---

    testWidgets('draft banner shows draft message text', (tester) async {
      await tester.pumpWidget(
        createTestWidget(plan: createTestPlan()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Plan is in draft. Agree to lock it in.'),
        findsOneWidget,
      );
      expect(find.text('Agree to Plan'), findsOneWidget);

      // Non-warning banner: clipboard icon tinted with the theme primary,
      // not the orange warning treatment.
      final icon = tester.widget<Icon>(find.byIcon(MdiIcons.clipboardCheck));
      final context = tester.element(find.byType(DailyOsPage));
      expect(icon.color, Theme.of(context).colorScheme.primary);
      expect(icon.color, isNot(Colors.orange));
    });

    testWidgets('review banner shows review message text', (tester) async {
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
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Changes detected. Review your plan.'),
        findsOneWidget,
      );
      expect(find.text('Re-agree'), findsOneWidget);

      // Warning banner: alert icon with the orange warning treatment.
      final icon = tester.widget<Icon>(find.byIcon(MdiIcons.alertCircle));
      expect(icon.color, Colors.orange);
    });

    // --- Agree button invokes agreeToPlan on draft banner ---

    testWidgets('tapping agree button on draft banner calls agreeToPlan', (
      tester,
    ) async {
      final trackingController = _TrackingUnifiedController(
        DailyOsData(
          date: testDate,
          dayPlan: createTestPlan(),
          timelineData: createTestTimelineData(),
          budgetProgress: [],
        ),
      );

      await tester.pumpWidget(
        createTestWidget(unifiedControllerFactory: () => trackingController),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(trackingController.agreeToPlanCallCount, 0);

      final agreeButton = find.widgetWithText(TextButton, 'Agree to Plan');
      expect(agreeButton, findsOneWidget);
      await tester.ensureVisible(agreeButton);
      await tester.tap(agreeButton);
      await tester.pump();

      expect(trackingController.agreeToPlanCallCount, 1);
    });

    // --- Re-agree button invokes agreeToPlan on review banner ---

    testWidgets('tapping re-agree button on review banner calls agreeToPlan', (
      tester,
    ) async {
      final trackingController = _TrackingUnifiedController(
        DailyOsData(
          date: testDate,
          dayPlan: createTestPlan(
            status: DayPlanStatus.needsReview(
              triggeredAt: testDate,
              reason: DayPlanReviewReason.blockModified,
            ),
          ),
          timelineData: createTestTimelineData(),
          budgetProgress: [],
        ),
      );

      await tester.pumpWidget(
        createTestWidget(unifiedControllerFactory: () => trackingController),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(trackingController.agreeToPlanCallCount, 0);

      final reAgreeButton = find.widgetWithText(TextButton, 'Re-agree');
      expect(reAgreeButton, findsOneWidget);
      await tester.ensureVisible(reAgreeButton);
      await tester.tap(reAgreeButton);
      await tester.pump();

      expect(trackingController.agreeToPlanCallCount, 1);
    });

    // --- Error state renders no banner (error branch) ---

    testWidgets('shows no banner when unified data controller errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(unifiedControllerFactory: _ErrorUnifiedController.new),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Error state produces SizedBox.shrink — no banner text
      expect(find.text('Agree to Plan'), findsNothing);
      expect(find.text('Re-agree'), findsNothing);
      // Page structure is still intact
      expect(find.byType(DailyOsPage), findsOneWidget);
    });

    // --- FAB tapping opens AddBlockSheet ---

    testWidgets('tapping FAB opens AddBlockSheet', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final fab = find.byType(FloatingActionButton);
      expect(fab, findsOneWidget);
      await tester.ensureVisible(fab);
      await tester.tap(fab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(add_block.AddBlockSheet), findsOneWidget);
    });

    // --- _onDragActiveChanged: drag-active prevents scroll ---

    testWidgets(
      'scroll physics switch to NeverScrollable when drag is active',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Initially scrolling is allowed (AlwaysScrollableScrollPhysics)
        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scrollView.physics,
          isA<AlwaysScrollableScrollPhysics>(),
        );

        // Locate the DailyTimeline and send a drag-start gesture via its
        // onDragActiveChanged callback.  Because DailyTimeline accepts the
        // callback, we grab the widget and invoke it directly.
        final timeline = tester.widget<DailyTimeline>(
          find.byType(DailyTimeline),
        );
        expect(timeline.onDragActiveChanged, isNotNull);

        // Simulate drag start (isDragging = true)
        timeline.onDragActiveChanged!(isDragging: true);
        await tester.pump();

        final scrollViewAfter = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scrollViewAfter.physics,
          isA<NeverScrollableScrollPhysics>(),
        );

        // Simulate drag end (isDragging = false)
        timeline.onDragActiveChanged!(isDragging: false);
        await tester.pump();

        final scrollViewRestored = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scrollViewRestored.physics,
          isA<AlwaysScrollableScrollPhysics>(),
        );
      },
    );

    // --- RefreshIndicator callback invalidates and re-fetches the controller ---

    testWidgets('pull-to-refresh triggers refresh via RefreshIndicator', (
      tester,
    ) async {
      // Use a screen large enough that the scroll view has room to overscroll.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Dispatch a fling downward to trigger the RefreshIndicator.
      await tester.fling(
        find.byType(SingleChildScrollView),
        const Offset(0, 300),
        1000,
      );
      // Let the refresh indicator settle (it runs async).
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After refresh the page structure is still intact — no crash.
      expect(find.byType(RefreshIndicator), findsOneWidget);
      expect(find.byType(DailyOsPage), findsOneWidget);
    });
  });
}
