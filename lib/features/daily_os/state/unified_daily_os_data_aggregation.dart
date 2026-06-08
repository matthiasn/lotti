part of 'unified_daily_os_data_controller.dart';

/// Data-aggregation half of [UnifiedDailyOsDataController]: fetches the
/// day's entities and derives timeline, budget-progress, and
/// task-progress projections. Same library (part), so private state on
/// the controller stays accessible.
extension UnifiedDailyOsDataAggregation on UnifiedDailyOsDataController {
  Future<DailyOsData> _fetchAllData() async {
    if (_isDisposed) {
      return DailyOsData(
        date: _date,
        dayPlan: _createEmptyDayPlan(),
        timelineData: _createEmptyTimelineData(),
        budgetProgress: [],
      );
    }

    final db = getIt<JournalDb>();
    final dayStart = _date.dayAtMidnight;
    final dayEnd = dayStart.add(const Duration(days: 1));

    // Determine if selected date is in the future (after today)
    // Using clock.now() for testability - can be mocked with withClock()
    // Use dayAtMidnight for both to ensure consistent TZ/DST boundary semantics
    final todayStart = clock.now().dayAtMidnight;
    final isFutureDate = dayStart.isAfter(todayStart);

    // Fetch day plan, calendar entries, and due tasks in parallel.
    // LAZY CREATION: Only read the day plan, never auto-create on navigation.
    // This prevents sync conflicts when multiple devices open the same date.
    // The plan is created on first user interaction (e.g., adding a block).
    final dayPlanFuture = _dayPlanRepository.getDayPlan(_date);
    final entriesFuture = db.sortedCalendarEntries(
      rangeStart: dayStart,
      rangeEnd: dayEnd,
    );
    final dueTasksFuture = isFutureDate
        ? db.getTasksDueOn(_date)
        : db.getTasksDueOnOrBefore(_date);

    final (existingPlan, entries, dueTasks) = await (
      dayPlanFuture,
      entriesFuture,
      dueTasksFuture,
    ).wait;

    final dayPlan = existingPlan ?? _createEmptyDayPlan();

    // Fetch linked entries (parent tasks/journals) for each entry
    final entryIds = entries.map((e) => e.meta.id).toSet();
    final links = await db.basicLinksForEntryIds(entryIds);

    // Build lookup maps for linked entries
    final entryIdToLinkedFromIds = <String, Set<String>>{};
    final linkedFromIds = <String>{};

    for (final link in links) {
      entryIdToLinkedFromIds[link.toId] = {
        link.fromId,
        ...?entryIdToLinkedFromIds[link.toId],
      };
      linkedFromIds.add(link.fromId);
    }

    final linkedFromEntries = await db.getJournalEntitiesForIdsUnordered(
      linkedFromIds,
    );
    final linkedFromMap = <String, JournalEntity>{
      for (final entry in linkedFromEntries) entry.meta.id: entry,
    };

    // Build timeline data
    final timelineData = _buildTimelineData(
      dayPlan: dayPlan,
      entries: entries,
      entryIdToLinkedFromIds: entryIdToLinkedFromIds,
      linkedFromMap: linkedFromMap,
      dayStart: dayStart,
    );

    // Build budget progress
    final budgetProgress = _buildBudgetProgress(
      dayPlan: dayPlan,
      entries: entries,
      entryIdToLinkedFromIds: entryIdToLinkedFromIds,
      linkedFromMap: linkedFromMap,
      dueTasks: dueTasks,
    );

    _trackedRefreshKeys
      ..clear()
      ..add(dayPlan.meta.id)
      ..addAll(entryIds)
      ..addAll(linkedFromIds)
      ..addAll(dueTasks.map((task) => task.meta.id));

    return DailyOsData(
      date: _date,
      dayPlan: dayPlan,
      timelineData: timelineData,
      budgetProgress: budgetProgress,
    );
  }

  /// Resolves the most appropriate parent entry for a time entry.
  ///
  /// Priority:
  /// 1. `Task` parents (primary navigation target)
  /// 2. Any non-rating parent
  /// 3. `null` if only rating parents exist
  JournalEntity? _resolveLinkedFrom({
    required Set<String>? linkedFromIds,
    required Map<String, JournalEntity> linkedFromMap,
  }) {
    if (linkedFromIds == null) return null;

    JournalEntity? fallbackNonRating;

    for (final linkedFromId in linkedFromIds) {
      final linkedFrom = linkedFromMap[linkedFromId];
      if (linkedFrom == null) continue;
      if (linkedFrom is Task) return linkedFrom;
      if (linkedFrom is RatingEntry) continue;
      fallbackNonRating ??= linkedFrom;
    }

    return fallbackNonRating;
  }

  DailyTimelineData _buildTimelineData({
    required DayPlanEntry dayPlan,
    required List<JournalEntity> entries,
    required Map<String, Set<String>> entryIdToLinkedFromIds,
    required Map<String, JournalEntity> linkedFromMap,
    required DateTime dayStart,
  }) {
    // Convert planned blocks to time slots
    final plannedSlots = <PlannedTimeSlot>[];
    for (final block in dayPlan.data.plannedBlocks) {
      plannedSlots.add(
        PlannedTimeSlot(
          startTime: block.startTime,
          endTime: block.endTime,
          block: block,
          categoryId: block.categoryId,
        ),
      );
    }

    // Convert actual entries to time slots (skip zero-duration entries)
    final actualSlots = <ActualTimeSlot>[];
    for (final entry in entries) {
      final duration = entry.meta.dateTo.difference(entry.meta.dateFrom);
      if (duration <= Duration.zero) continue;

      final linkedFrom = _resolveLinkedFrom(
        linkedFromIds: entryIdToLinkedFromIds[entry.meta.id],
        linkedFromMap: linkedFromMap,
      );
      final categoryId = linkedFrom?.meta.categoryId ?? entry.meta.categoryId;

      actualSlots.add(
        ActualTimeSlot(
          startTime: entry.meta.dateFrom,
          endTime: entry.meta.dateTo,
          entry: entry,
          categoryId: categoryId,
          linkedFrom: linkedFrom,
        ),
      );
    }

    // Sort by start time
    plannedSlots.sort((a, b) => a.startTime.compareTo(b.startTime));
    actualSlots.sort((a, b) => a.startTime.compareTo(b.startTime));

    // Calculate day bounds
    final dayStartHour = calculateDayStartHour(plannedSlots, actualSlots);
    final dayEndHour = calculateDayEndHour(
      plannedSlots,
      actualSlots,
      dayStart,
    );

    return DailyTimelineData(
      date: _date,
      plannedSlots: plannedSlots,
      actualSlots: actualSlots,
      dayStartHour: dayStartHour,
      dayEndHour: dayEndHour,
    );
  }

  /// Checks if a task was marked Done on the specified day.
  bool _wasCompletedOnDay(Task task, DateTime day) {
    final status = task.data.status;
    if (status is! TaskDone) return false;
    final doneAt = status.createdAt;
    return doneAt.year == day.year &&
        doneAt.month == day.month &&
        doneAt.day == day.day;
  }

  List<TimeBudgetProgress> _buildBudgetProgress({
    required DayPlanEntry dayPlan,
    required List<JournalEntity> entries,
    required Map<String, Set<String>> entryIdToLinkedFromIds,
    required Map<String, JournalEntity> linkedFromMap,
    required List<Task> dueTasks,
  }) {
    final derivedBudgets = dayPlan.data.derivedBudgets;
    final budgetCategoryIds = derivedBudgets.map((b) => b.categoryId).toSet();

    // Group entries by category, using linked parent's category if available
    final entriesByCategory = <String, List<JournalEntity>>{};
    for (final entry in entries) {
      final linkedFrom = _resolveLinkedFrom(
        linkedFromIds: entryIdToLinkedFromIds[entry.meta.id],
        linkedFromMap: linkedFromMap,
      );
      final categoryId = linkedFrom?.meta.categoryId ?? entry.meta.categoryId;

      if (categoryId != null) {
        entriesByCategory.putIfAbsent(categoryId, () => []).add(entry);
      }
    }

    // Group due tasks by category
    final dueTasksByCategory = <String, List<Task>>{};
    for (final task in dueTasks) {
      final categoryId = task.meta.categoryId;
      if (categoryId != null) {
        dueTasksByCategory.putIfAbsent(categoryId, () => []).add(task);
      }
    }

    // Find categories needing synthetic budgets:
    // 1. Categories with due tasks but no budget
    // 2. Categories with time entries but no budget (for viewing past work)
    final categoriesNeedingSyntheticBudget = <String>{
      ...dueTasksByCategory.keys.where(
        (catId) => !budgetCategoryIds.contains(catId),
      ),
      ...entriesByCategory.keys.where(
        (catId) => !budgetCategoryIds.contains(catId),
      ),
    };

    final cacheService = getIt<EntitiesCacheService>();
    final results = <TimeBudgetProgress>[];

    // Build progress for existing budgets (include due tasks)
    for (final budget in derivedBudgets) {
      final categoryEntries = entriesByCategory[budget.categoryId] ?? [];
      final recordedDuration = _sumDurations(categoryEntries);
      final plannedDuration = budget.plannedDuration;

      final categoryDueTasks = dueTasksByCategory[budget.categoryId] ?? [];
      final categoryDueTaskIds = categoryDueTasks.map((t) => t.meta.id).toSet();

      // Build task progress items for this category
      final trackedTaskItems = _buildTaskProgressItems(
        categoryEntries: categoryEntries,
        entryIdToLinkedFromIds: entryIdToLinkedFromIds,
        linkedFromMap: linkedFromMap,
      );
      final trackedTaskIds = trackedTaskItems
          .map((i) => i.task.meta.id)
          .toSet();

      // DEDUPLICATION: Update tracked tasks that are also due
      final mergedTaskItems = trackedTaskItems.map((item) {
        final taskId = item.task.meta.id;
        if (categoryDueTaskIds.contains(taskId)) {
          // Task has tracked time AND is due - add due date status
          final dueStatus = getDueDateStatus(
            dueDate: item.task.data.due,
            referenceDate: _date,
          );
          return TaskDayProgress(
            task: item.task,
            timeSpentOnDay: item.timeSpentOnDay,
            wasCompletedOnDay: item.wasCompletedOnDay,
            dueDateStatus: dueStatus,
          );
        }
        return item;
      }).toList();

      // Add due tasks that have NO tracked time (not already included)
      for (final dueTask in categoryDueTasks) {
        if (!trackedTaskIds.contains(dueTask.meta.id)) {
          final dueStatus = getDueDateStatus(
            dueDate: dueTask.data.due,
            referenceDate: _date,
          );
          mergedTaskItems.add(
            TaskDayProgress(
              task: dueTask,
              timeSpentOnDay: Duration.zero,
              wasCompletedOnDay: false,
              dueDateStatus: dueStatus,
            ),
          );
        }
      }

      // Re-sort: time descending, then priority, urgency, alphabetical
      mergedTaskItems.sort(TaskSortComparators.byTimeSpentThenPriority);

      results.add(
        TimeBudgetProgress(
          categoryId: budget.categoryId,
          category: cacheService.getCategoryById(budget.categoryId),
          plannedDuration: plannedDuration,
          recordedDuration: recordedDuration,
          status: calculateBudgetProgressStatus(
            plannedDuration,
            recordedDuration,
          ),
          contributingEntries: categoryEntries,
          taskProgressItems: mergedTaskItems,
          blocks: budget.blocks,
        ),
      );
    }

    // Create synthetic budgets for categories with due tasks or time entries
    // but no planned time budget
    for (final categoryId in categoriesNeedingSyntheticBudget) {
      final category = cacheService.getCategoryById(categoryId);
      final categoryDueTasks = dueTasksByCategory[categoryId] ?? [];
      final categoryEntries = entriesByCategory[categoryId] ?? [];
      final recordedDuration = _sumDurations(categoryEntries);

      // Build task progress items from time entries (tracked work)
      final trackedTaskItems = _buildTaskProgressItems(
        categoryEntries: categoryEntries,
        entryIdToLinkedFromIds: entryIdToLinkedFromIds,
        linkedFromMap: linkedFromMap,
      );
      final trackedTaskIds = trackedTaskItems
          .map((i) => i.task.meta.id)
          .toSet();
      final categoryDueTaskIds = categoryDueTasks.map((t) => t.meta.id).toSet();

      // Merge tracked tasks with due status if applicable
      final mergedTaskItems = trackedTaskItems.map((item) {
        final taskId = item.task.meta.id;
        if (categoryDueTaskIds.contains(taskId)) {
          final dueStatus = getDueDateStatus(
            dueDate: item.task.data.due,
            referenceDate: _date,
          );
          return TaskDayProgress(
            task: item.task,
            timeSpentOnDay: item.timeSpentOnDay,
            wasCompletedOnDay: item.wasCompletedOnDay,
            dueDateStatus: dueStatus,
          );
        }
        return item;
      }).toList();

      // Add due tasks that have no tracked time
      for (final dueTask in categoryDueTasks) {
        if (!trackedTaskIds.contains(dueTask.meta.id)) {
          final dueStatus = getDueDateStatus(
            dueDate: dueTask.data.due,
            referenceDate: _date,
          );
          mergedTaskItems.add(
            TaskDayProgress(
              task: dueTask,
              timeSpentOnDay: Duration.zero,
              wasCompletedOnDay: false,
              dueDateStatus: dueStatus,
            ),
          );
        }
      }

      // Sort: time descending, then priority, urgency, alphabetical
      mergedTaskItems.sort(TaskSortComparators.byTimeSpentThenPriority);

      results.add(
        TimeBudgetProgress(
          categoryId: categoryId,
          category: category,
          plannedDuration: Duration.zero,
          recordedDuration: recordedDuration,
          status: BudgetProgressStatus.underBudget,
          contributingEntries: categoryEntries,
          taskProgressItems: mergedTaskItems,
          blocks: [],
          hasNoBudgetWarning: true,
        ),
      );
    }

    return results;
  }

  /// Builds task progress items from entries linked to tasks.
  List<TaskDayProgress> _buildTaskProgressItems({
    required List<JournalEntity> categoryEntries,
    required Map<String, Set<String>> entryIdToLinkedFromIds,
    required Map<String, JournalEntity> linkedFromMap,
  }) {
    // Group entries by their parent task
    final taskIdToEntries = <String, List<JournalEntity>>{};
    final taskById = <String, Task>{};

    for (final entry in categoryEntries) {
      final linkedFromIds = entryIdToLinkedFromIds[entry.meta.id];
      if (linkedFromIds == null) continue;

      for (final linkedFromId in linkedFromIds) {
        final linkedFrom = linkedFromMap[linkedFromId];
        if (linkedFrom is Task) {
          taskIdToEntries.putIfAbsent(linkedFrom.meta.id, () => []).add(entry);
          taskById[linkedFrom.meta.id] = linkedFrom;
        }
      }
    }

    // Build TaskDayProgress for each task
    final items = <TaskDayProgress>[];
    for (final taskId in taskById.keys) {
      final task = taskById[taskId]!;
      final entries = taskIdToEntries[taskId] ?? [];
      final timeSpentOnDay = _sumDurations(entries);
      final wasCompletedOnDay = _wasCompletedOnDay(task, _date);

      // Include if has time OR was completed today
      if (timeSpentOnDay > Duration.zero || wasCompletedOnDay) {
        items.add(
          TaskDayProgress(
            task: task,
            timeSpentOnDay: timeSpentOnDay,
            wasCompletedOnDay: wasCompletedOnDay,
          ),
        );
      }
    }

    // Sort: time descending, zero-time completed at end
    items.sort((a, b) {
      // Both have time: sort by time descending
      if (a.timeSpentOnDay > Duration.zero &&
          b.timeSpentOnDay > Duration.zero) {
        return b.timeSpentOnDay.compareTo(a.timeSpentOnDay);
      }
      // One has time, one doesn't: time first
      if (a.timeSpentOnDay > Duration.zero) return -1;
      if (b.timeSpentOnDay > Duration.zero) return 1;
      // Both zero time: alphabetical by title
      return a.task.data.title.compareTo(b.task.data.title);
    });

    return items;
  }

  /// Calculates the total duration of entries, accounting for overlaps.
  ///
  /// When entries overlap in time (e.g., a 1.5h "Gym Trip" containing a 45m
  /// "Fitness Entry"), we calculate the **union** of time ranges to prevent
  /// double-counting. The overlapping portion is only counted once.
  ///
  /// Example:
  /// - Gym Trip: 10:00 - 11:30 (1.5h)
  /// - Fitness Entry: 10:30 - 11:15 (45m)
  /// - Simple sum: 2h 15m (incorrect - double-counts the overlap)
  /// - Union: 1h 30m (correct - covers 10:00 to 11:30)
  Duration _sumDurations(List<JournalEntity> entries) {
    if (entries.isEmpty) return Duration.zero;
    if (entries.length == 1) return entryDuration(entries.first);

    // Convert entries to time ranges for union calculation
    final ranges = entries
        .map(
          (entry) => TimeRange(
            start: entry.meta.dateFrom,
            end: entry.meta.dateTo,
          ),
        )
        .toList();

    return calculateUnionDuration(ranges);
  }

  /// Creates a transient (non-persisted) empty day plan for display purposes.
  ///
  /// Uses the proper deterministic ID so that if the user later interacts
  /// with this plan (e.g., adds a block), it can be persisted correctly
  /// via [_saveDayPlan] without ID conflicts.
  DayPlanEntry _createEmptyDayPlan() {
    final dayStart = _date.dayAtMidnight;
    final now = clock.now();
    return DayPlanEntry(
      meta: Metadata(
        id: dayPlanId(dayStart),
        createdAt: now,
        updatedAt: now,
        dateFrom: dayStart,
        dateTo: dayStart.add(const Duration(days: 1)),
      ),
      data: DayPlanData(
        planDate: dayStart,
        status: const DayPlanStatus.draft(),
      ),
    );
  }

  DailyTimelineData _createEmptyTimelineData() {
    return DailyTimelineData(
      date: _date,
      plannedSlots: [],
      actualSlots: [],
      dayStartHour: 8,
      dayEndHour: 18,
    );
  }

  // =========================================================================
  // Day Plan Mutation Methods
  // =========================================================================
}

/// The hour the timeline should start rendering at.
///
/// Returns a default of `8` when there are no slots. Otherwise it takes the
/// earliest start hour across the (pre-sorted) planned and actual slots,
/// subtracts a one-hour lead-in buffer, and clamps the result to `[0, 23]` so
/// the buffer never wraps before midnight.
int calculateDayStartHour(
  List<PlannedTimeSlot> planned,
  List<ActualTimeSlot> actual,
) {
  if (planned.isEmpty && actual.isEmpty) return 8;

  var earliest = 24;

  if (planned.isNotEmpty) {
    final plannedStart = planned.first.startTime.hour;
    if (plannedStart < earliest) earliest = plannedStart;
  }

  if (actual.isNotEmpty) {
    final actualStart = actual.first.startTime.hour;
    if (actualStart < earliest) earliest = actualStart;
  }

  // Add 1 hour buffer before, but not before midnight
  return (earliest - 1).clamp(0, 23);
}

/// The hour the timeline should stop rendering at.
///
/// Returns a default of `18` when there are no slots. Otherwise it takes the
/// latest end hour across all planned and actual slots — slots whose end is on
/// or after the following midnight count as hour `24` — adds a one-hour
/// tail-out buffer, and clamps the result to `[1, 24]`.
int calculateDayEndHour(
  List<PlannedTimeSlot> planned,
  List<ActualTimeSlot> actual,
  DateTime dayStart,
) {
  if (planned.isEmpty && actual.isEmpty) return 18;

  final nextDay = dayStart.add(const Duration(days: 1));
  var latest = 0;

  // Find max end time across all planned slots
  for (final slot in planned) {
    // If entry ends on the next day (crosses midnight), treat as hour 24
    final endHour = !slot.endTime.isBefore(nextDay)
        ? 24
        : slot.endTime.hour + 1;
    if (endHour > latest) latest = endHour;
  }

  // Find max end time across all actual slots
  for (final slot in actual) {
    // If entry ends on the next day (crosses midnight), treat as hour 24
    final endHour = !slot.endTime.isBefore(nextDay)
        ? 24
        : slot.endTime.hour + 1;
    if (endHour > latest) latest = endHour;
  }

  // Add 1 hour buffer after, but not past midnight
  return (latest + 1).clamp(1, 24);
}

/// Classifies a budget by the time remaining: negative remaining is over
/// budget, exactly zero is exhausted, fifteen minutes or less (by whole
/// minutes) is near the limit, anything beyond that is under budget.
BudgetProgressStatus calculateBudgetProgressStatus(
  Duration planned,
  Duration recorded,
) {
  final remaining = planned - recorded;

  if (remaining.isNegative) {
    return BudgetProgressStatus.overBudget;
  } else if (remaining == Duration.zero) {
    return BudgetProgressStatus.exhausted;
  } else if (remaining.inMinutes <= 15) {
    return BudgetProgressStatus.nearLimit;
  } else {
    return BudgetProgressStatus.underBudget;
  }
}
