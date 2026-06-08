part of 'my_daily_widgetbook.dart';

class _MyDailyPreviewFixture {
  const _MyDailyPreviewFixture({
    required this.initialDate,
    required this.now,
    required this.showFilterRow,
    required this.initialSelectedCategoryIds,
    required this.dailyDataByDate,
    required this.historyData,
  });

  final DateTime initialDate;
  final DateTime now;
  final bool showFilterRow;
  final Set<String> initialSelectedCategoryIds;
  final Map<DateTime, DailyOsData> dailyDataByDate;
  final TimeHistoryData historyData;
}

List<Override> _buildMyDailyPreviewOverrides(_MyDailyPreviewFixture fixture) {
  return [
    dailyOsSelectedDateProvider.overrideWith(
      () => _PreviewDailyOsSelectedDate(fixture.initialDate),
    ),
    dailyOsControllerProvider.overrideWith(
      () => _PreviewDailyOsController(fixture.dailyDataByDate),
    ),
    timeHistoryHeaderControllerProvider.overrideWith(
      () => _PreviewTimeHistoryHeaderController(fixture.historyData),
    ),
    for (final entry in fixture.dailyDataByDate.entries)
      unifiedDailyOsDataControllerProvider(date: entry.key).overrideWith(
        () => _PreviewUnifiedDailyOsDataController(entry.value),
      ),
  ];
}

_MyDailyPreviewFixture _buildMyDailyPreviewFixture({
  required _MyDailyPreviewVariant variant,
}) {
  final selectedDate = DateTime(2023, 10, 17);
  final visibleDates = [
    for (var offset = -2; offset <= 4; offset++)
      DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day + offset,
      ),
  ];
  final dailyDataByDate = <DateTime, DailyOsData>{
    for (final date in visibleDates) date: _buildDailyOsData(date),
  };

  return _MyDailyPreviewFixture(
    initialDate: selectedDate,
    now: DateTime(2023, 10, 17, 11),
    showFilterRow: variant != _MyDailyPreviewVariant.ongoingDay,
    initialSelectedCategoryIds: switch (variant) {
      _MyDailyPreviewVariant.ongoingDay => const {},
      _MyDailyPreviewVariant.filterByTimeBlock => {
        _holidayCategoryId,
        _tasksCategoryId,
        _hikingCategoryId,
      },
      _MyDailyPreviewVariant.filtered => {
        _holidayCategoryId,
        _hikingCategoryId,
      },
    },
    dailyDataByDate: dailyDataByDate,
    historyData: TimeHistoryData(
      days: [
        for (final date in visibleDates.reversed)
          DayTimeSummary(
            day: DateTime(date.year, date.month, date.day, 12),
            durationByCategoryId: const {},
            total: const Duration(hours: 6),
          ),
      ],
      earliestDay: visibleDates.first,
      latestDay: visibleDates.last,
      maxDailyTotal: const Duration(hours: 8),
      categoryOrder: const [
        _holidayCategoryId,
        _tasksCategoryId,
        _hikingCategoryId,
        _meetingsCategoryId,
      ],
      isLoadingMore: false,
      canLoadMore: false,
      stackedHeights: const {},
    ),
  );
}

DailyOsData _buildDailyOsData(DateTime date) {
  final categories = _buildPreviewCategories(date);
  final blocks = _buildPreviewBlocks(date);
  final actualSlots = _buildPreviewActualSlots(date);
  final budgetProgress = _buildPreviewBudgetProgress(
    date: date,
    categories: categories,
    blocks: blocks,
    actualSlots: actualSlots,
  );

  return DailyOsData(
    date: date,
    dayPlan: DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(date),
        createdAt: date,
        updatedAt: date,
        dateFrom: date,
        dateTo: date.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: date,
        status: DayPlanStatus.agreed(agreedAt: date),
        plannedBlocks: blocks,
      ),
    ),
    timelineData: DailyTimelineData(
      date: date,
      plannedSlots: [
        for (final block in blocks)
          PlannedTimeSlot(
            startTime: block.startTime,
            endTime: block.endTime,
            categoryId: block.categoryId,
            block: block,
          ),
      ],
      actualSlots: actualSlots,
      dayStartHour: 8,
      dayEndHour: 26,
    ),
    budgetProgress: budgetProgress,
  );
}

Map<String, CategoryDefinition> _buildPreviewCategories(DateTime date) {
  return {
    _holidayCategoryId: CategoryDefinition(
      id: _holidayCategoryId,
      name: _holidayCategoryId,
      color: '#8E2DE2',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
    _tasksCategoryId: CategoryDefinition(
      id: _tasksCategoryId,
      name: _tasksCategoryId,
      color: '#2ED8E2',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
    _hikingCategoryId: CategoryDefinition(
      id: _hikingCategoryId,
      name: _hikingCategoryId,
      color: '#D4B013',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
    _meetingsCategoryId: CategoryDefinition(
      id: _meetingsCategoryId,
      name: _meetingsCategoryId,
      color: '#6F6F74',
      createdAt: date,
      updatedAt: date,
      vectorClock: null,
      private: false,
      active: true,
    ),
  };
}

class _PreviewDailyOsSelectedDate extends DailyOsSelectedDate {
  _PreviewDailyOsSelectedDate(this._initialDate);

  final DateTime _initialDate;

  @override
  DateTime build() => _initialDate;
}

class _PreviewDailyOsController extends DailyOsController {
  _PreviewDailyOsController(this._dailyDataByDate);

  final Map<DateTime, DailyOsData> _dailyDataByDate;

  @override
  Future<DailyOsState> build() async {
    final selectedDate = ref.watch(dailyOsSelectedDateProvider);
    final dailyData = _dailyDataByDate[selectedDate];

    if (dailyData == null) {
      throw StateError('Missing preview data for $selectedDate.');
    }

    return DailyOsState(
      selectedDate: selectedDate,
      dayPlan: dailyData.dayPlan,
      budgetProgress: dailyData.budgetProgress,
      timelineData: dailyData.timelineData,
    );
  }
}

class _PreviewUnifiedDailyOsDataController
    extends UnifiedDailyOsDataController {
  _PreviewUnifiedDailyOsDataController(this._data);

  final DailyOsData _data;

  @override
  Future<DailyOsData> build({required DateTime date}) async => _data;
}

class _PreviewTimeHistoryHeaderController extends TimeHistoryHeaderController {
  _PreviewTimeHistoryHeaderController(this._data);

  final TimeHistoryData _data;

  @override
  Future<TimeHistoryData> build() async => _data;
}
