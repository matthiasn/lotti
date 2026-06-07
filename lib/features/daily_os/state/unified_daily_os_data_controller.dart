import 'dart:async';

import 'package:clock/clock.dart';
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:lotti/features/daily_os/state/time_budget_progress_controller.dart';
import 'package:lotti/features/daily_os/state/timeline_data_controller.dart';
import 'package:lotti/features/daily_os/util/task_sort_comparators.dart';
import 'package:lotti/features/daily_os/util/time_range_utils.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/features/tasks/util/due_date_utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/services/time_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unified_daily_os_data_controller.g.dart';
part 'unified_daily_os_data_aggregation.dart';

/// Combined data for Daily OS view - single source of truth.
///
/// This consolidates day plan, timeline data, and budget progress into
/// a single atomic state that updates together when any underlying data changes.
class DailyOsData {
  const DailyOsData({
    required this.date,
    required this.dayPlan,
    required this.timelineData,
    required this.budgetProgress,
  });

  final DateTime date;
  final DayPlanEntry dayPlan;
  final DailyTimelineData timelineData;
  final List<TimeBudgetProgress> budgetProgress;
}

/// Unified data controller for the Daily OS view.
///
/// This controller solves the auto-update problem by:
/// 1. Using `ref.keepAlive()` to prevent disposal when navigating away
/// 2. Owning a manual `StreamSubscription` to `UpdateNotifications.updateStream`
///    which is NOT affected by Riverpod 3's automatic pausing
/// 3. Fetching ALL data directly (day plan, calendar entries, links) rather
///    than watching sub-controllers
/// 4. Updating state atomically when any relevant notification arrives
///
/// This ensures that when a time entry is created or synced, all UI components
/// (timeline, budget progress bars, summary) update together.
@riverpod
class UnifiedDailyOsDataController extends _$UnifiedDailyOsDataController {
  static const Set<String> _broadRefreshKeys = {
    dayPlanNotification,
    textEntryNotification,
    taskNotification,
    workoutNotification,
    categoriesNotification,
    privateToggleNotification,
  };

  late DateTime _date;
  late DayPlanRepository _dayPlanRepository;
  late TimeService _timeService;
  StreamSubscription<Set<String>>? _updateSubscription;
  StreamSubscription<JournalEntity?>? _timerSubscription;
  final Set<String> _trackedRefreshKeys = <String>{};

  /// The currently running timer entry with live duration.
  /// Used to replace stale DB entries when calculating budget progress.
  JournalEntity? _runningEntry;

  /// Last displayed minute for the running timer (for throttling).
  /// We only update UI when the minute changes, not every second.
  int? _lastDisplayedMinute;

  bool _isDisposed = false;
  bool _hasLoadedInitialData = false;
  bool _refreshInFlight = false;
  bool _pendingRefresh = false;

  @override
  Future<DailyOsData> build({required DateTime date}) async {
    _date = date;
    _isDisposed = false;
    _dayPlanRepository = ref.read(dayPlanRepositoryProvider);
    _timeService = getIt<TimeService>();

    // CRITICAL: Keep alive to prevent disposal when navigating away.
    // This ensures data is fresh when the user returns to the page.
    ref
      ..keepAlive()
      ..onDispose(() {
        _isDisposed = true;
        _updateSubscription?.cancel();
        _timerSubscription?.cancel();
      });

    // Start listening BEFORE fetch to avoid missing updates during initial load.
    _listen();
    final data = await _fetchAllData();
    _hasLoadedInitialData = true;

    if (_pendingRefresh) {
      unawaited(_refreshFromNotifications());
    }

    return data;
  }

  void _listen() {
    final notifications = getIt<UpdateNotifications>();
    _updateSubscription = notifications.updateStream.listen((affectedIds) {
      if (_isDisposed) return;

      if (!_hasLoadedInitialData) {
        _pendingRefresh = true;
        return;
      }

      if (!_shouldRefreshFor(affectedIds)) {
        return;
      }

      unawaited(_refreshFromNotifications());
    });

    // Subscribe to timer updates for live duration tracking.
    // Throttled to only update when the displayed minute changes.
    _timerSubscription = _timeService.getStream().listen((entry) {
      if (_isDisposed) return;

      final previousEntry = _runningEntry;
      _runningEntry = entry;

      // Timer stopped - always update
      if (entry == null) {
        _lastDisplayedMinute = null;
        _updateWithRunningTimer();
        return;
      }

      // Timer just started - always update
      if (previousEntry == null) {
        _lastDisplayedMinute = entryDuration(entry).inMinutes;
        _updateWithRunningTimer();
        return;
      }

      // Only update when the minute changes (throttle per-second updates)
      final currentMinute = entryDuration(entry).inMinutes;
      if (currentMinute != _lastDisplayedMinute) {
        _lastDisplayedMinute = currentMinute;
        _updateWithRunningTimer();
      }
    });
  }

  bool _shouldRefreshFor(Set<String> affectedIds) {
    if (affectedIds.isEmpty) {
      return false;
    }

    return affectedIds.any(_broadRefreshKeys.contains) ||
        affectedIds.intersection(_trackedRefreshKeys).isNotEmpty;
  }

  Future<void> _refreshFromNotifications() async {
    if (_refreshInFlight) {
      _pendingRefresh = true;
      return;
    }

    _refreshInFlight = true;
    try {
      do {
        _pendingRefresh = false;
        final data = await _fetchAllData();
        _hasLoadedInitialData = true;
        if (!_isDisposed) {
          state = AsyncData(data);
        }
      } while (_pendingRefresh && !_isDisposed);
    } catch (e, stackTrace) {
      if (_isDisposed) return;
      getIt<DomainLogger>().error(
        LogDomain.dailyOs,
        e,
        stackTrace: stackTrace,
        subDomain: '_refreshFromNotifications',
      );
    } finally {
      _refreshInFlight = false;
    }
  }

  /// Updates state with the running timer's live duration.
  ///
  /// This avoids a full refetch - it just recalculates budget progress
  /// using the stored running entry's live duration.
  void _updateWithRunningTimer() {
    final currentState = state.value;
    if (currentState == null) return;

    // Check if the running entry belongs to this day
    final runningEntry = _runningEntry;
    if (runningEntry == null) {
      // Timer stopped - refetch to get final saved duration
      _fetchAllData()
          .then((data) {
            if (_isDisposed) return;
            // Only update if timer is still stopped (no new timer started during refetch)
            if (_runningEntry == null) {
              state = AsyncData(data);
            }
          })
          .catchError((Object e, StackTrace stackTrace) {
            if (_isDisposed) return;
            getIt<DomainLogger>().error(
              LogDomain.dailyOs,
              e,
              stackTrace: stackTrace,
              subDomain: '_updateWithRunningTimer',
            );
          });
      return;
    }

    // Check if the running entry is for the current day
    final entryDate = runningEntry.meta.dateFrom.dayAtMidnight;
    if (entryDate != _date) return;

    // Get the category for this entry (from linkedFrom or entry itself)
    final linkedFrom = _timeService.linkedFrom;
    final categoryId =
        linkedFrom?.meta.categoryId ?? runningEntry.meta.categoryId;
    if (categoryId == null) return;

    // Find and update the affected budget
    final updatedBudgets = currentState.budgetProgress.map((budget) {
      if (budget.categoryId != categoryId) return budget;

      // Recalculate recorded duration with the live entry
      final updatedEntries = budget.contributingEntries.map((e) {
        if (e.meta.id == runningEntry.meta.id) {
          return runningEntry;
        }
        return e;
      }).toList();

      // Check if the running entry is new (not in contributingEntries)
      final hasRunningEntry = budget.contributingEntries.any(
        (e) => e.meta.id == runningEntry.meta.id,
      );
      if (!hasRunningEntry) {
        updatedEntries.add(runningEntry);
      }

      final recordedDuration = _sumDurations(updatedEntries);

      return TimeBudgetProgress(
        categoryId: budget.categoryId,
        category: budget.category,
        plannedDuration: budget.plannedDuration,
        recordedDuration: recordedDuration,
        status: calculateBudgetProgressStatus(
          budget.plannedDuration,
          recordedDuration,
        ),
        contributingEntries: updatedEntries,
        taskProgressItems: budget.taskProgressItems,
        blocks: budget.blocks,
        hasNoBudgetWarning: budget.hasNoBudgetWarning,
      );
    }).toList();

    state = AsyncData(
      DailyOsData(
        date: currentState.date,
        dayPlan: currentState.dayPlan,
        timelineData: currentState.timelineData,
        budgetProgress: updatedBudgets,
      ),
    );
  }

  /// Saves a day plan and updates the local state with fresh derived values.
  ///
  /// After saving, this refetches all data to ensure timelineData and
  /// budgetProgress are recomputed from the updated plan. This ensures
  /// the UI immediately reflects mutations (e.g., new planned blocks
  /// appear in the timeline).
  Future<void> _saveDayPlan(DayPlanEntry updatedPlan) async {
    await _dayPlanRepository.save(updatedPlan);

    // Refetch all data to recompute derived values (timelineData, budgetProgress)
    if (!_isDisposed) {
      final freshData = await _fetchAllData();
      if (!_isDisposed) {
        state = AsyncData(freshData);
      }
    }
  }

  /// Transitions an agreed plan to needsReview status.
  /// Returns the updated data if transition occurred, or original data if not.
  DayPlanData _transitionToNeedsReviewIfAgreed(
    DayPlanData data,
    DayPlanReviewReason reason,
  ) {
    if (data.status is! DayPlanStatusAgreed) return data;

    final agreed = data.status as DayPlanStatusAgreed;
    return data.copyWith(
      status: DayPlanStatus.needsReview(
        triggeredAt: clock.now(),
        reason: reason,
        previouslyAgreedAt: agreed.agreedAt,
      ),
    );
  }

  /// Helper to mutate the day plan with reduced boilerplate.
  ///
  /// Takes a [mutator] function that transforms the plan data, and an
  /// optional [reviewReason] to trigger needsReview transition for agreed plans.
  Future<void> _mutateDayPlan(
    DayPlanData Function(DayPlanData) mutator, {
    DayPlanReviewReason? reviewReason,
  }) async {
    final currentState = state.value;
    if (currentState == null) return;

    final dayPlan = currentState.dayPlan;
    var updatedData = mutator(dayPlan.data);

    if (reviewReason != null) {
      updatedData = _transitionToNeedsReviewIfAgreed(updatedData, reviewReason);
    }

    final updated = dayPlan.copyWith(data: updatedData);
    await _saveDayPlan(updated);
  }

  /// Agrees to the current plan.
  Future<void> agreeToPlan() async {
    final now = clock.now();
    await _mutateDayPlan(
      (data) => data.copyWith(
        status: DayPlanStatus.agreed(agreedAt: now),
        agreedAt: now,
      ),
    );
  }

  /// Marks the day as complete.
  Future<void> markComplete() async {
    final now = clock.now();
    await _mutateDayPlan(
      (data) => data.copyWith(completedAt: now),
    );
  }

  /// Replaces all planned blocks at once (batch save from manual planning).
  Future<void> setPlannedBlocks(List<PlannedBlock> blocks) async {
    await _mutateDayPlan(
      (data) => data.copyWith(plannedBlocks: blocks),
      reviewReason: DayPlanReviewReason.blockModified,
    );
  }

  /// Adds a planned block to the timeline.
  Future<void> addPlannedBlock(PlannedBlock block) async {
    await _mutateDayPlan(
      (data) => data.copyWith(
        plannedBlocks: [...data.plannedBlocks, block],
      ),
      reviewReason: DayPlanReviewReason.blockModified,
    );
  }

  /// Updates an existing planned block.
  Future<void> updatePlannedBlock(PlannedBlock block) async {
    await _mutateDayPlan(
      (data) => data.copyWith(
        plannedBlocks: data.plannedBlocks
            .map((b) => b.id == block.id ? block : b)
            .toList(),
      ),
      reviewReason: DayPlanReviewReason.blockModified,
    );
  }

  /// Removes a planned block.
  Future<void> removePlannedBlock(String blockId) async {
    await _mutateDayPlan(
      (data) => data.copyWith(
        plannedBlocks: data.plannedBlocks
            .where((b) => b.id != blockId)
            .toList(),
      ),
      reviewReason: DayPlanReviewReason.blockModified,
    );
  }

  /// Pins a task to a category.
  Future<void> pinTask(PinnedTaskRef taskRef) async {
    await _mutateDayPlan(
      (data) => data.copyWith(
        pinnedTasks: [...data.pinnedTasks, taskRef],
      ),
      reviewReason: DayPlanReviewReason.taskRescheduled,
    );
  }

  /// Unpins a task.
  Future<void> unpinTask(String taskId) async {
    await _mutateDayPlan(
      (data) => data.copyWith(
        pinnedTasks: data.pinnedTasks.where((t) => t.taskId != taskId).toList(),
      ),
      reviewReason: DayPlanReviewReason.taskRescheduled,
    );
  }

  /// Sets the day label.
  Future<void> setDayLabel(String? label) async {
    await _mutateDayPlan(
      (data) => data.copyWith(dayLabel: label),
    );
  }
}
