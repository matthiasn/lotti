import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/time_history_header.dart';

import '../../../../../test_helper.dart';
import 'test_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(setUpEntitiesCacheService);
  tearDown(tearDownEntitiesCacheService);

  group('TimeHistoryHeader', () {
    testWidgets('renders day segments for loaded data', (tester) async {
      final days = createTestDays(count: 5);
      await tester.pumpWidget(
        createTestWidget(historyData: createTestHistoryData(days: days)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TimeHistoryHeader), findsOneWidget);

      // Should show day numbers
      expect(find.text('15'), findsOneWidget); // Today
      expect(find.text('14'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
    });

    testWidgets('tapping day segment updates selected date', (tester) async {
      final days = createTestDays(count: 5);
      await tester.pumpWidget(
        createTestWidget(historyData: createTestHistoryData(days: days)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially, day 15 should be selected - date label shows "January 15"
      expect(find.textContaining('Jan 15'), findsOneWidget);
      expect(find.textContaining('Jan 14'), findsNothing);

      // Tap on day 14 segment
      await tester.tap(find.text('14'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // After tapping, the date label should now show "January 14"
      expect(find.textContaining('Jan 14'), findsOneWidget);
    });

    testWidgets('shows selection highlight on selected day', (tester) async {
      final days = createTestDays(count: 5);
      await tester.pumpWidget(
        createTestWidget(historyData: createTestHistoryData(days: days)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The selected day (15) is wrapped in a filled, rounded pill.
      bool isSelectionPill(Widget widget) =>
          widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).color != null &&
          (widget.decoration! as BoxDecoration).borderRadius ==
              BorderRadius.circular(8);

      final selectedPill = find.ancestor(
        of: find.text('15'),
        matching: find.byWidgetPredicate(isSelectionPill),
      );
      expect(selectedPill, findsOneWidget);

      // An unselected weekday (14) carries no filled pill.
      final unselectedPill = find.ancestor(
        of: find.text('14'),
        matching: find.byWidgetPredicate(isSelectionPill),
      );
      expect(unselectedPill, findsNothing);
    });

    testWidgets('shows sticky month label for visible days', (tester) async {
      // Create days in January
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 5, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 4, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 3, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          selectedDate: DateTime(2026, 1, 5),
          historyData: createTestHistoryData(days: days),
          plan: createTestPlan(date: DateTime(2026, 1, 5)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show "Jan 2026" in the sticky month header
      expect(find.text('Jan 2026'), findsOneWidget);
    });

    testWidgets('shows loading skeleton during initial load', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            dailyOsSelectedDateProvider.overrideWith(
              () => TestDailyOsSelectedDate(testDate),
            ),
            timeHistoryHeaderControllerProvider.overrideWith(
              LoadingTimeHistoryController.new,
            ),
            unifiedDailyOsDataControllerProvider(testDate).overrideWith(
              () => TestUnifiedController(createUnifiedData()),
            ),
            dayBudgetStatsProvider(testDate).overrideWith(
              (ref) async => const DayBudgetStats(
                totalPlanned: Duration.zero,
                totalRecorded: Duration.zero,
                budgetCount: 0,
                overBudgetCount: 0,
              ),
            ),
          ],
          child: const TimeHistoryHeader(),
        ),
      );
      await tester.pump();

      // Should show loading placeholders (7 skeleton items by default)
      expect(find.byType(TimeHistoryHeader), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoadingMore is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          historyData: createTestHistoryData(isLoadingMore: true),
        ),
      );
      // Use pump() instead of pumpAndSettle() because
      // CircularProgressIndicator animates continuously
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show a loading indicator — and specifically the load-more
      // spinner built by _buildLoadingIndicator (strokeWidth 2), not some
      // other progress indicator. Asserting the strokeWidth makes the test
      // resilient against unrelated indicators appearing elsewhere.
      final spinnerFinder = find.byType(CircularProgressIndicator);
      expect(spinnerFinder, findsOneWidget);
      final spinner = tester.widget<CircularProgressIndicator>(spinnerFinder);
      expect(spinner.strokeWidth, 2);

      // The spinner is the trailing item of the horizontal day-selector
      // ListView (the scroll area), so it must sit inside a Scrollable.
      expect(
        find.ancestor(
          of: spinnerFinder,
          matching: find.byType(Scrollable),
        ),
        findsOneWidget,
      );
    });

    testWidgets('aligns stream chart to day segment centers', (tester) async {
      final days = createTestDays(count: 3);
      await tester.pumpWidget(
        createTestWidget(historyData: createTestHistoryData(days: days)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final headerWidth = tester.getSize(find.byType(TimeHistoryHeader)).width;
      final chartWidth = days.length * daySegmentWidth;
      final expectedLeft = headerWidth - chartWidth;

      final transformFinder = find.ancestor(
        of: find.byType(TimeHistoryStreamChart),
        matching: find.byType(Transform),
      );

      final transformWidget = tester.widget<Transform>(transformFinder.first);
      final actualLeft = transformWidget.transform.getTranslation().x;

      expect(actualLeft, closeTo(expectedLeft, 0.01));
    });

    testWidgets('displays formatted date with day name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // January 15, 2026 is a Thursday
      expect(find.textContaining('Thursday'), findsOneWidget);
    });

    testWidgets('triggers loadMoreDays when scrolling near end', (
      tester,
    ) async {
      // Create enough days to allow scrolling beyond 80% threshold
      final days = createTestDays(count: 50);
      final historyData = createTestHistoryData(days: days);
      final trackingController = TrackingTimeHistoryController(historyData);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            dailyOsSelectedDateProvider.overrideWith(
              () => TestDailyOsSelectedDate(testDate),
            ),
            timeHistoryHeaderControllerProvider.overrideWith(
              () => trackingController,
            ),
            unifiedDailyOsDataControllerProvider(testDate).overrideWith(
              () => TestUnifiedController(createUnifiedData()),
            ),
            dayBudgetStatsProvider(testDate).overrideWith(
              (ref) async => const DayBudgetStats(
                totalPlanned: Duration.zero,
                totalRecorded: Duration.zero,
                budgetCount: 0,
                overBudgetCount: 0,
              ),
            ),
          ],
          child: const TimeHistoryHeader(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Initially no calls
      expect(trackingController.loadMoreDaysCallCount, 0);

      // Find the scrollable ListView.builder that has the day segments
      final scrollableFinder = find.byType(Scrollable);
      expect(scrollableFinder, findsWidgets);

      // Get the first horizontal Scrollable (the day list, not skeleton)
      final scrollable = tester.widget<Scrollable>(scrollableFinder.first);

      // Scroll using the scroll controller directly via the scrollable
      final scrollController = scrollable.controller;
      if (scrollController != null && scrollController.hasClients) {
        // Jump to 85% of max scroll extent to trigger the 80% threshold
        final maxExtent = scrollController.position.maxScrollExtent;
        scrollController.jumpTo(maxExtent * 0.85);
        await tester.pump();
      }

      // Should have triggered loadMoreDays at least once
      expect(trackingController.loadMoreDaysCallCount, greaterThan(0));
    });

    testWidgets('shows multi-month label spanning different years', (
      tester,
    ) async {
      // Create days spanning Dec 2025 and Jan 2026
      final days = [
        DayTimeSummary(
          day: DateTime(2026, 1, 2, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2026, 1, 1, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2025, 12, 31, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2025, 12, 30, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          selectedDate: DateTime(2026, 1, 2),
          historyData: createTestHistoryData(days: days),
          plan: createTestPlan(date: DateTime(2026, 1, 2)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show both months with years since they span different years
      expect(find.text('Dec 2025 | Jan 2026'), findsOneWidget);
    });

    testWidgets('shows multi-month label within same year', (tester) async {
      // Create days spanning Nov and Dec 2025
      final days = [
        DayTimeSummary(
          day: DateTime(2025, 12, 2, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2025, 12, 1, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2025, 11, 30, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
        DayTimeSummary(
          day: DateTime(2025, 11, 29, 12),
          durationByCategoryId: const {},
          total: Duration.zero,
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          selectedDate: DateTime(2025, 12, 2),
          historyData: createTestHistoryData(days: days),
          plan: createTestPlan(date: DateTime(2025, 12, 2)),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Should show both months but only year on second: "Nov | Dec 2025"
      expect(find.text('Nov | Dec 2025'), findsOneWidget);
    });

    testWidgets('renders unselected day segment correctly', (tester) async {
      final days = createTestDays(count: 3);
      await tester.pumpWidget(
        createTestWidget(historyData: createTestHistoryData(days: days)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Day 14 should be visible but not selected (day 15 is selected)
      expect(find.text('14'), findsOneWidget);
      expect(find.text('13'), findsOneWidget);
    });

    testWidgets('Today button is tappable and triggers navigation', (
      tester,
    ) async {
      final fixedToday = DateTime(2026, 1, 15, 12);
      final yesterday = DateTime(2026, 1, 14);
      final todayMidnight = DateTime(2026, 1, 15);

      final historyData = createTestHistoryData(
        days: [
          DayTimeSummary(
            day: DateTime(2026, 1, 15, 12),
            durationByCategoryId: const {},
            total: Duration.zero,
          ),
          DayTimeSummary(
            day: DateTime(2026, 1, 14, 12),
            durationByCategoryId: const {},
            total: Duration.zero,
          ),
        ],
      );

      await withClock(Clock.fixed(fixedToday), () async {
        await tester.pumpWidget(
          RiverpodWidgetTestBench(
            overrides: [
              dailyOsSelectedDateProvider.overrideWith(
                () => TestDailyOsSelectedDate(yesterday, today: todayMidnight),
              ),
              timeHistoryHeaderControllerProvider.overrideWith(
                () => TestTimeHistoryController(historyData),
              ),
              unifiedDailyOsDataControllerProvider(yesterday).overrideWith(
                () => TestUnifiedController(createUnifiedData(date: yesterday)),
              ),
              unifiedDailyOsDataControllerProvider(todayMidnight).overrideWith(
                () => TestUnifiedController(
                  createUnifiedData(date: todayMidnight),
                ),
              ),
              dayBudgetStatsProvider(yesterday).overrideWith(
                (ref) async => const DayBudgetStats(
                  totalPlanned: Duration.zero,
                  totalRecorded: Duration.zero,
                  budgetCount: 0,
                  overBudgetCount: 0,
                ),
              ),
              dayBudgetStatsProvider(todayMidnight).overrideWith(
                (ref) async => const DayBudgetStats(
                  totalPlanned: Duration.zero,
                  totalRecorded: Duration.zero,
                  budgetCount: 0,
                  overBudgetCount: 0,
                ),
              ),
            ],
            child: const TimeHistoryHeader(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Initially showing yesterday - Today button should be visible
        expect(find.textContaining('Jan 14'), findsOneWidget);
        final todayButton = find.textContaining('Today');
        expect(todayButton, findsOneWidget);

        // Tap the Today button
        await tester.tap(todayButton);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // After tapping, should navigate to today (Jan 15)
        expect(find.textContaining('Jan 15'), findsOneWidget);
      });
    });
  });
}
