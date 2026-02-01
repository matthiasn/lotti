import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/daily_os_controller.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/time_history_header_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
import 'package:lotti/features/daily_os/ui/widgets/time_history_header/time_history_header.dart';

import '../../../../../test_helper.dart';

/// Default test date used across time history header tests.
final testDate = DateTime(2026, 1, 15);

/// Mock controller that returns fixed unified data.
class TestUnifiedController extends UnifiedDailyOsDataController {
  TestUnifiedController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    return _data;
  }
}

/// Mock controller for time history header data.
class TestTimeHistoryController extends TimeHistoryHeaderController {
  TestTimeHistoryController(this._data);

  final TimeHistoryData _data;

  @override
  Future<TimeHistoryData> build() async {
    return _data;
  }
}

/// Mock controller that tracks loadMoreDays calls.
class TrackingTimeHistoryController extends TimeHistoryHeaderController {
  TrackingTimeHistoryController(this._data);

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

/// Controller that simulates loading state by never completing.
class LoadingTimeHistoryController extends TimeHistoryHeaderController {
  @override
  Future<TimeHistoryData> build() {
    // Use a Completer that never completes to avoid pending timer issues
    return Completer<TimeHistoryData>().future;
  }
}

/// Mock notifier for date selection that tracks selected date.
class TestDailyOsSelectedDate extends DailyOsSelectedDate {
  TestDailyOsSelectedDate(this._initialDate, {DateTime? today})
      : _today = today ?? _initialDate;

  final DateTime _initialDate;
  final DateTime _today;

  @override
  DateTime build() => _initialDate;

  @override
  void selectDate(DateTime date) {
    state = date;
  }

  @override
  void goToToday() {
    // Use injected "today" instead of DateTime.now() for deterministic tests
    state = _today;
  }
}

/// Creates test days for the time history header.
List<DayTimeSummary> createTestDays({int count = 7, DateTime? startDate}) {
  final baseDate = startDate ?? testDate;
  return List.generate(count, (index) {
    final day = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day - index,
      12, // noon
    );
    return DayTimeSummary(
      day: day,
      durationByCategoryId: const {},
      total: Duration.zero,
    );
  });
}

/// Creates test history data for the time history header.
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

/// Creates a test day plan entry.
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

/// Creates test unified data.
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

/// Creates a test widget with the TimeHistoryHeader.
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
        () => TestDailyOsSelectedDate(date),
      ),
      timeHistoryHeaderControllerProvider.overrideWith(
        () => TestTimeHistoryController(effectiveHistoryData),
      ),
      unifiedDailyOsDataControllerProvider(date: date).overrideWith(
        () => TestUnifiedController(unifiedData),
      ),
      dayBudgetStatsProvider(date: date).overrideWith(
        (ref) async => effectiveStats,
      ),
      ...additionalOverrides,
    ],
    child: const TimeHistoryHeader(),
  );
}
