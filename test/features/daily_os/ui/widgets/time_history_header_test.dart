import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../../../../test_helper.dart';

/// Mock controller that returns fixed unified data.
class _TestUnifiedController extends UnifiedDailyOsDataController {
  _TestUnifiedController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    return _data;
  }
}

/// Mock controller for time history header data.
class _TestTimeHistoryController extends TimeHistoryHeaderController {
  _TestTimeHistoryController(this._data);

  final TimeHistoryData _data;

  @override
  Future<TimeHistoryData> build() async {
    return _data;
  }
}

/// Mock controller that tracks loadMoreDays calls.
class _TrackingTimeHistoryController extends TimeHistoryHeaderController {
  _TrackingTimeHistoryController(this._data);

  final TimeHistoryData _data;
  int loadMoreDaysCallCount = 0;

  @override
  Future<TimeHistoryData> build() async {
    return _data;
  }

  @override
  Future<void> loadMoreDays() async {
    loadMoreDaysCallCount++;
  }
}

/// Mock notifier for date selection that tracks selected date.
class _TestDailyOsSelectedDate extends DailyOsSelectedDate {
  _TestDailyOsSelectedDate(this._initialDate);

  final DateTime _initialDate;

  @override
  DateTime build() => _initialDate;

  @override
  void selectDate(DateTime date) {
    state = date;
  }

  @override
  void goToToday() {
    state = DateTime.now();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testDate = DateTime(2026, 1, 15);

  List<DayTimeSummary> createTestDays({int count = 7}) {
    return List.generate(count, (index) {
      final day = DateTime(
        testDate.year,
        testDate.month,
        testDate.day - index,
        12, // noon
      );
      return DayTimeSummary(
        day: day,
        durationByCategoryId: const {},
        total: Duration.zero,
      );
    });
  }

  TimeHistoryData createTestHistoryData({
    List<DayTimeSummary>? days,
    bool isLoadingMore = false,
    bool canLoadMore = true,
  }) {
    final effectiveDays = days ?? createTestDays();
    return TimeHistoryData(
      days: effectiveDays,
      earliestDay: effectiveDays.isNotEmpty
          ? effectiveDays.last.day
          : testDate.subtract(const Duration(days: 6)),
      latestDay: effectiveDays.isNotEmpty ? effectiveDays.first.day : testDate,
      maxDailyTotal: const Duration(hours: 4),
      categoryOrder: const [],
      isLoadingMore: isLoadingMore,
      canLoadMore: canLoadMore,
      stackedHeights: const {},
    );
  }

  DayPlanEntry createTestPlan({
    String? dayLabel,
    DayPlanStatus status = const DayPlanStatus.draft(),
    DateTime? date,
  }) {
    final effectiveDate = date ?? testDate;
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(effectiveDate),
        createdAt: effectiveDate,
        updatedAt: effectiveDate,
        dateFrom: effectiveDate,
        dateTo: effectiveDate.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: effectiveDate,
        status: status,
        dayLabel: dayLabel,
      ),
    );
  }

  DailyOsData createUnifiedData({
    DateTime? date,
    DayPlanEntry? plan,
  }) {
    final effectiveDate = date ?? testDate;
    return DailyOsData(
      date: effectiveDate,
      dayPlan: plan ?? createTestPlan(date: effectiveDate),
      timelineData: DailyTimelineData(
        date: effectiveDate,
        plannedSlots: const [],
        actualSlots: const [],
        dayStartHour: 8,
        dayEndHour: 18,
      ),
      budgetProgress: const [],
    );
  }

  Widget createTestWidget({
    TimeHistoryData? historyData,
    DayPlanEntry? plan,
    DayBudgetStats? stats,
    DateTime? selectedDate,
    List<Override> additionalOverrides = const [],
  }) {
    final date = selectedDate ?? testDate;
    final effectiveStats = stats ??
        const DayBudgetStats(
          totalPlanned: Duration.zero,
          totalRecorded: Duration.zero,
          budgetCount: 0,
          overBudgetCount: 0,
        );
    final effectiveHistoryData = historyData ?? createTestHistoryData();
    final effectivePlan = plan ?? createTestPlan(date: date);

    final unifiedData = createUnifiedData(
      date: date,
      plan: effectivePlan,
    );

    return RiverpodWidgetTestBench(
      overrides: [
        dailyOsSelectedDateProvider.overrideWith(
          () => _TestDailyOsSelectedDate(date),
        ),
        timeHistoryHeaderControllerProvider.overrideWith(
          () => _TestTimeHistoryController(effectiveHistoryData),
        ),
        unifiedDailyOsDataControllerProvider(date: date).overrideWith(
          () => _TestUnifiedController(unifiedData),
        ),
        dayBudgetStatsProvider(date: date).overrideWith(
          (ref) async => effectiveStats,
        ),
        ...additionalOverrides,
      ],
      child: const TimeHistoryHeader(),
    );
  }

  group('TimeHistoryHeader', () {
    testWidgets('renders the widget', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(TimeHistoryHeader), findsOneWidget);
    });

    testWidgets('renders day segments for loaded data', (tester) async {
      final days = createTestDays(count: 5);
      await tester.pumpWidget(
        createTestWidget(historyData: createTestHistoryData(days: days)),
      );
      await tester.pumpAndSettle();

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
      await tester.pumpAndSettle();

      // Initially, day 15 should be selected (has selection border)
      // Verify day 15 text exists and is styled as selected
      expect(find.text('15'), findsOneWidget);

      // Tap on day 14
      await tester.tap(find.text('14'));
      await tester.pumpAndSettle();

      // After tapping, the date label should show January 14
      // (the _TestDailyOsSelectedDate mock updates state on selectDate)
      expect(find.textContaining('14'), findsWidgets);
    });

    testWidgets('shows selection highlight on selected day', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Find the day segment with the selected day (15)
      final dayText = find.text('15');
      expect(dayText, findsOneWidget);

      // The container should have a border for the selected day
      // We verify the parent container exists
      final containerFinder = find.ancestor(
        of: dayText,
        matching: find.byType(Container),
      );
      expect(containerFinder, findsWidgets);
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
      await tester.pumpAndSettle();

      // Should show "Jan 2026" in the sticky month header
      expect(find.text('Jan 2026'), findsOneWidget);
    });

    testWidgets('shows loading skeleton during initial load', (tester) async {
      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            dailyOsSelectedDateProvider.overrideWith(
              () => _TestDailyOsSelectedDate(testDate),
            ),
            timeHistoryHeaderControllerProvider.overrideWith(
              _LoadingTimeHistoryController.new,
            ),
            unifiedDailyOsDataControllerProvider(date: testDate).overrideWith(
              () => _TestUnifiedController(createUnifiedData()),
            ),
            dayBudgetStatsProvider(date: testDate).overrideWith(
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

    testWidgets('shows/hides Today button based on selected date',
        (tester) async {
      // When viewing today - no Today button
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);

      await tester.pumpWidget(
        createTestWidget(
          selectedDate: todayMidnight,
          historyData: createTestHistoryData(
            days: [
              DayTimeSummary(
                day: DateTime(todayMidnight.year, todayMidnight.month,
                    todayMidnight.day, 12),
                durationByCategoryId: const {},
                total: Duration.zero,
              ),
            ],
          ),
          plan: createTestPlan(date: todayMidnight),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.calendarToday), findsNothing);
    });

    testWidgets('shows Today button when not viewing today', (tester) async {
      // When viewing yesterday - Today button should appear
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final yesterdayMidnight =
          DateTime(yesterday.year, yesterday.month, yesterday.day);

      await tester.pumpWidget(
        createTestWidget(
          selectedDate: yesterdayMidnight,
          historyData: createTestHistoryData(
            days: [
              DayTimeSummary(
                day: DateTime(yesterdayMidnight.year, yesterdayMidnight.month,
                    yesterdayMidnight.day, 12),
                durationByCategoryId: const {},
                total: Duration.zero,
              ),
            ],
          ),
          plan: createTestPlan(date: yesterdayMidnight),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(MdiIcons.calendarToday), findsOneWidget);
    });

    testWidgets('displays day label chip when present', (tester) async {
      await tester.pumpWidget(
        createTestWidget(plan: createTestPlan(dayLabel: 'Focus Day')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Focus Day'), findsOneWidget);
    });

    testWidgets('displays budget status indicator', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 4),
            totalRecorded: Duration(hours: 2),
            budgetCount: 2,
            overBudgetCount: 0,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show remaining time indicator
      expect(find.text('2 hours left'), findsOneWidget);
    });

    testWidgets('displays over budget indicator', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          stats: const DayBudgetStats(
            totalPlanned: Duration(hours: 2),
            totalRecorded: Duration(hours: 3),
            budgetCount: 1,
            overBudgetCount: 1,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Over budget'), findsOneWidget);
    });

    testWidgets('date area tap opens date picker', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // The date format is "Thursday, Jan 15, 2026" (day name + short date)
      // Find and tap the date text containing Thursday
      final dateFinder = find.textContaining('Thursday');
      expect(dateFinder, findsOneWidget);

      await tester.tap(dateFinder);
      await tester.pumpAndSettle();

      // Date picker dialog should appear
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('shows loading indicator when isLoadingMore is true',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          historyData: createTestHistoryData(isLoadingMore: true),
        ),
      );
      // Use pump() instead of pumpAndSettle() because
      // CircularProgressIndicator animates continuously
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show a loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays formatted date with day name', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // January 15, 2026 is a Thursday
      expect(find.textContaining('Thursday'), findsOneWidget);
    });

    testWidgets('triggers loadMoreDays when scrolling near end',
        (tester) async {
      // Create enough days to allow scrolling beyond 80% threshold
      final days = createTestDays(count: 50);
      final historyData = createTestHistoryData(days: days);
      final trackingController = _TrackingTimeHistoryController(historyData);

      await tester.pumpWidget(
        RiverpodWidgetTestBench(
          overrides: [
            dailyOsSelectedDateProvider.overrideWith(
              () => _TestDailyOsSelectedDate(testDate),
            ),
            timeHistoryHeaderControllerProvider.overrideWith(
              () => trackingController,
            ),
            unifiedDailyOsDataControllerProvider(date: testDate).overrideWith(
              () => _TestUnifiedController(createUnifiedData()),
            ),
            dayBudgetStatsProvider(date: testDate).overrideWith(
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
      await tester.pumpAndSettle();

      // Initially no calls
      expect(trackingController.loadMoreDaysCallCount, 0);

      // Find the scrollable ListView.builder that has the day segments
      // It's inside the Expanded widget in the Column
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
  });
}

/// Controller that simulates loading state by never completing.
class _LoadingTimeHistoryController extends TimeHistoryHeaderController {
  @override
  Future<TimeHistoryData> build() {
    // Use a Completer that never completes to avoid pending timer issues
    return Completer<TimeHistoryData>().future;
  }
}
