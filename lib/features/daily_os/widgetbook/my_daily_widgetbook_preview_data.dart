part of 'my_daily_widgetbook.dart';

List<PlannedBlock> _buildPreviewBlocks(DateTime date) {
  DateTime at(int hour, int minute) {
    final dayOffset = hour >= 24 ? 1 : 0;
    return DateTime(
      date.year,
      date.month,
      date.day + dayOffset,
      hour % 24,
      minute,
    );
  }

  return [
    PlannedBlock(
      id: 'skiing',
      categoryId: _holidayCategoryId,
      startTime: at(8, 5),
      endTime: at(9, 40),
    ),
    PlannedBlock(
      id: 'skiing-recap',
      categoryId: _holidayCategoryId,
      startTime: at(10, 5),
      endTime: at(10, 35),
    ),
    PlannedBlock(
      id: 'lunch-break',
      categoryId: _tasksCategoryId,
      startTime: at(12, 20),
      endTime: at(12, 55),
    ),
    PlannedBlock(
      id: 'deep-work',
      categoryId: _tasksCategoryId,
      startTime: at(15, 0),
      endTime: at(16, 0),
    ),
    PlannedBlock(
      id: 'hiking',
      categoryId: _hikingCategoryId,
      startTime: at(16, 30),
      endTime: at(17, 30),
    ),
    PlannedBlock(
      id: 'meeting',
      categoryId: _meetingsCategoryId,
      startTime: at(17, 40),
      endTime: at(18, 40),
    ),
  ];
}

List<ActualTimeSlot> _buildPreviewActualSlots(DateTime date) {
  DateTime at(int hour, int minute) {
    final dayOffset = hour >= 24 ? 1 : 0;
    return DateTime(
      date.year,
      date.month,
      date.day + dayOffset,
      hour % 24,
      minute,
    );
  }

  ActualTimeSlot slot({
    required String id,
    required String categoryId,
    required DateTime start,
    required DateTime end,
  }) {
    return ActualTimeSlot(
      startTime: start,
      endTime: end,
      categoryId: categoryId,
      entry: JournalEntity.journalEntry(
        meta: Metadata(
          id: id,
          createdAt: start,
          updatedAt: end,
          dateFrom: start,
          dateTo: end,
          categoryId: categoryId,
        ),
      ),
    );
  }

  return [
    slot(
      id: 'actual-ski-1',
      categoryId: _holidayCategoryId,
      start: at(8, 5),
      end: at(8, 20),
    ),
    slot(
      id: 'actual-ski-2',
      categoryId: _holidayCategoryId,
      start: at(8, 24),
      end: at(8, 40),
    ),
    slot(
      id: 'actual-ski-3',
      categoryId: _holidayCategoryId,
      start: at(8, 46),
      end: at(9, 5),
    ),
    slot(
      id: 'actual-ski-4',
      categoryId: _holidayCategoryId,
      start: at(9, 8),
      end: at(9, 32),
    ),
    slot(
      id: 'actual-lunch-1',
      categoryId: _tasksCategoryId,
      start: at(12, 20),
      end: at(12, 30),
    ),
    slot(
      id: 'actual-lunch-2',
      categoryId: _tasksCategoryId,
      start: at(12, 35),
      end: at(12, 45),
    ),
    slot(
      id: 'actual-lunch-3',
      categoryId: _tasksCategoryId,
      start: at(12, 47),
      end: at(12, 55),
    ),
    slot(
      id: 'actual-work-1',
      categoryId: _tasksCategoryId,
      start: at(15, 0),
      end: at(15, 20),
    ),
    slot(
      id: 'actual-work-2',
      categoryId: _tasksCategoryId,
      start: at(15, 24),
      end: at(15, 42),
    ),
    slot(
      id: 'actual-work-3',
      categoryId: _tasksCategoryId,
      start: at(15, 44),
      end: at(16, 0),
    ),
    slot(
      id: 'actual-hike-1',
      categoryId: _hikingCategoryId,
      start: at(16, 35),
      end: at(17, 25),
    ),
    slot(
      id: 'actual-meeting-1',
      categoryId: _meetingsCategoryId,
      start: at(17, 40),
      end: at(18, 20),
    ),
  ];
}

List<TimeBudgetProgress> _buildPreviewBudgetProgress({
  required DateTime date,
  required Map<String, CategoryDefinition> categories,
  required List<PlannedBlock> blocks,
  required List<ActualTimeSlot> actualSlots,
}) {
  return [
    _budgetProgressForCategory(
      date: date,
      categoryId: _holidayCategoryId,
      category: categories[_holidayCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _holidayCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _holidayCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-skiing',
          categoryId: _holidayCategoryId,
          priority: TaskPriority.p1High,
        ),
      ],
    ),
    _budgetProgressForCategory(
      date: date,
      categoryId: _tasksCategoryId,
      category: categories[_tasksCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _tasksCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _tasksCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-lunch',
          categoryId: _tasksCategoryId,
          priority: TaskPriority.p3Low,
        ),
        _task(
          date: date,
          id: 'task-deep-work',
          categoryId: _tasksCategoryId,
          priority: TaskPriority.p2Medium,
        ),
      ],
    ),
    _budgetProgressForCategory(
      date: date,
      categoryId: _hikingCategoryId,
      category: categories[_hikingCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _hikingCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _hikingCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-hiking',
          categoryId: _hikingCategoryId,
          priority: TaskPriority.p2Medium,
        ),
      ],
    ),
    _budgetProgressForCategory(
      date: date,
      categoryId: _meetingsCategoryId,
      category: categories[_meetingsCategoryId],
      blocks: blocks
          .where((block) => block.categoryId == _meetingsCategoryId)
          .toList(),
      actualSlots: actualSlots
          .where((slot) => slot.categoryId == _meetingsCategoryId)
          .toList(),
      tasks: [
        _task(
          date: date,
          id: 'task-meeting',
          categoryId: _meetingsCategoryId,
          priority: TaskPriority.p0Urgent,
        ),
      ],
    ),
  ];
}

TimeBudgetProgress _budgetProgressForCategory({
  required DateTime date,
  required String categoryId,
  required CategoryDefinition? category,
  required List<PlannedBlock> blocks,
  required List<ActualTimeSlot> actualSlots,
  required List<Task> tasks,
}) {
  final plannedDuration = blocks.fold<Duration>(
    Duration.zero,
    (total, block) => total + block.duration,
  );
  final recordedDuration = actualSlots.fold<Duration>(
    Duration.zero,
    (total, slot) => total + slot.duration,
  );
  final remainingMinutes =
      plannedDuration.inMinutes - recordedDuration.inMinutes;
  final status = remainingMinutes < 0
      ? BudgetProgressStatus.overBudget
      : remainingMinutes <= 15
      ? BudgetProgressStatus.nearLimit
      : BudgetProgressStatus.underBudget;

  return TimeBudgetProgress(
    categoryId: categoryId,
    category: category,
    plannedDuration: plannedDuration,
    recordedDuration: recordedDuration,
    status: status,
    contributingEntries: actualSlots.map((slot) => slot.entry).toList(),
    taskProgressItems: [
      for (final task in tasks)
        TaskDayProgress(
          task: task,
          timeSpentOnDay: recordedDuration ~/ math.max(tasks.length, 1),
          wasCompletedOnDay: false,
        ),
    ],
    blocks: blocks,
  );
}

Task _task({
  required DateTime date,
  required String id,
  required String categoryId,
  required TaskPriority priority,
}) {
  final status = TaskStatus.inProgress(
    id: 'status-$id',
    createdAt: date,
    utcOffset: 0,
  );

  return Task(
    meta: Metadata(
      id: id,
      createdAt: date,
      updatedAt: date,
      dateFrom: date,
      dateTo: date,
      categoryId: categoryId,
    ),
    data: TaskData(
      status: status,
      dateFrom: date,
      dateTo: date,
      statusHistory: [status],
      title: id,
      priority: priority,
    ),
  );
}

String _formatTimelineHour(BuildContext context, int hour) {
  return _formatLocalizedPreviewTime(
    context,
    _previewClock(hour, 0),
    includeMinutes: false,
  );
}

DateTime _previewClock(int hour, int minute) {
  final dayOffset = hour >= 24 ? 1 : 0;
  return DateTime(2023, 10, 17 + dayOffset, hour % 24, minute);
}

String _formatLocalizedPreviewTime(
  BuildContext context,
  DateTime time, {
  bool includeMinutes = true,
}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final pattern = _uses24HourClock(context)
      ? (includeMinutes ? 'H:mm' : 'H')
      : (includeMinutes ? 'h:mma' : 'ha');

  return DateFormat(
    pattern,
    locale,
  ).format(time).toLowerCase().replaceAll(RegExp(r'\s+'), '');
}

String _formatLocalizedPreviewTimeRange(
  BuildContext context, {
  required int startHour,
  required int startMinute,
  required int endHour,
  required int endMinute,
}) {
  final start = _formatLocalizedPreviewTime(
    context,
    _previewClock(startHour, startMinute),
  );
  final end = _formatLocalizedPreviewTime(
    context,
    _previewClock(endHour, endMinute),
  );
  return '$start-$end';
}

bool _uses24HourClock(BuildContext context) {
  final mediaQuery = MediaQuery.maybeOf(context);
  if (mediaQuery?.alwaysUse24HourFormat ?? false) {
    return true;
  }

  final locale = Localizations.localeOf(context).toLanguageTag();
  final pattern = DateFormat.jm(locale).pattern?.toLowerCase() ?? '';
  return !pattern.contains('a');
}

String _labelForCategory(BuildContext context, String categoryId) {
  return switch (categoryId) {
    _holidayCategoryId => context.messages.designSystemNavigationHolidayLabel,
    _tasksCategoryId => context.messages.designSystemNavigationLottiTasksLabel,
    _hikingCategoryId => context.messages.designSystemNavigationHikingLabel,
    _meetingsCategoryId => context.messages.designSystemMyDailyMeetingsLabel,
    _ => categoryId,
  };
}

IconData _iconForCategory(String categoryId) {
  return switch (categoryId) {
    _holidayCategoryId => Icons.flight_takeoff_rounded,
    _tasksCategoryId => Icons.work_outline_rounded,
    _hikingCategoryId => Icons.hiking_rounded,
    _meetingsCategoryId => Icons.forum_outlined,
    _ => Icons.label_outline_rounded,
  };
}

Color _colorForCategory(String categoryId) {
  return switch (categoryId) {
    _holidayCategoryId => const Color(0xFF9127F5),
    _tasksCategoryId => const Color(0xFF2CC6D3),
    _hikingCategoryId => const Color(0xFFD2AF20),
    _meetingsCategoryId => const Color(0xFF7B7B83),
    _ => const Color(0xFF888888),
  };
}
