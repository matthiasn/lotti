import 'dart:async';

import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/daily_os/state/day_plan_controller.dart';
import 'package:lotti/features/journal/util/entry_tools.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/date_utils_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'time_budget_progress_controller.g.dart';

/// Status of budget consumption.
enum BudgetProgressStatus {
  /// More than 15 minutes remaining
  underBudget,

  /// 0-15 minutes remaining
  nearLimit,

  /// Exactly at budget
  exhausted,

  /// Spent more than budgeted
  overBudget,
}

/// Computed progress for a single time budget.
class TimeBudgetProgress {
  const TimeBudgetProgress({
    required this.budget,
    required this.category,
    required this.plannedDuration,
    required this.recordedDuration,
    required this.status,
    required this.contributingEntries,
    required this.pinnedTasks,
  });

  final TimeBudget budget;
  final CategoryDefinition? category;
  final Duration plannedDuration;
  final Duration recordedDuration;
  final BudgetProgressStatus status;
  final List<JournalEntity> contributingEntries;

  /// Tasks pinned to this budget (resolved from PinnedTaskRef).
  final List<Task> pinnedTasks;

  /// Tasks that contributed time to this budget (from contributingEntries).
  List<Task> get contributingTasks =>
      contributingEntries.whereType<Task>().toList();

  Duration get remainingDuration => plannedDuration - recordedDuration;

  double get progressFraction {
    if (plannedDuration.inMinutes == 0) return 0;
    return recordedDuration.inMinutes / plannedDuration.inMinutes;
  }

  bool get isOverBudget => recordedDuration > plannedDuration;
}

/// Provides aggregated budget progress for a day.
///
/// Combines the day's time budgets with actual recorded time entries
/// to calculate progress for each budget category.
@riverpod
class TimeBudgetProgressController extends _$TimeBudgetProgressController {
  @override
  Future<List<TimeBudgetProgress>> build({required DateTime date}) async {
    final dayPlanEntity = await ref.watch(
      dayPlanControllerProvider(date: date).future,
    );

    if (dayPlanEntity is! DayPlanEntry) {
      return [];
    }

    final dayPlanData = dayPlanEntity.data;
    final budgets = [...dayPlanData.budgets]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    if (budgets.isEmpty) {
      return [];
    }

    // Fetch actual time entries for this day
    final db = getIt<JournalDb>();
    final dayStart = date.dayAtMidnight;
    final dayEnd = dayStart.add(const Duration(days: 1));

    final entries = await db.sortedCalendarEntries(
      rangeStart: dayStart,
      rangeEnd: dayEnd,
    );

    // Group entries by category
    final entriesByCategory = <String, List<JournalEntity>>{};
    for (final entry in entries) {
      final categoryId = entry.meta.categoryId;
      if (categoryId != null) {
        entriesByCategory.putIfAbsent(categoryId, () => []).add(entry);
      }
    }

    // Fetch all pinned tasks
    final allPinnedTaskIds =
        dayPlanData.pinnedTasks.map((ref) => ref.taskId).toSet();
    final pinnedTaskEntities =
        await db.getJournalEntitiesForIds(allPinnedTaskIds);
    final pinnedTasksById = <String, Task>{
      for (final entity in pinnedTaskEntities)
        if (entity is Task) entity.meta.id: entity,
    };

    // Group pinned tasks by budget ID
    final pinnedTasksByBudgetId = <String, List<Task>>{};
    for (final budget in budgets) {
      final taskRefs = dayPlanData.pinnedTasksForBudget(budget.id);
      final tasks = <Task>[];
      for (final ref in taskRefs) {
        final task = pinnedTasksById[ref.taskId];
        if (task != null) {
          tasks.add(task);
        }
      }
      pinnedTasksByBudgetId[budget.id] = tasks;
    }

    // Calculate progress for each budget
    final cacheService = getIt<EntitiesCacheService>();
    final results = <TimeBudgetProgress>[];

    for (final budget in budgets) {
      final categoryEntries = entriesByCategory[budget.categoryId] ?? [];
      final recordedDuration = _sumDurations(categoryEntries);
      final plannedDuration = budget.plannedDuration;

      results.add(
        TimeBudgetProgress(
          budget: budget,
          category: cacheService.getCategoryById(budget.categoryId),
          plannedDuration: plannedDuration,
          recordedDuration: recordedDuration,
          status: _calculateStatus(plannedDuration, recordedDuration),
          contributingEntries: categoryEntries,
          pinnedTasks: pinnedTasksByBudgetId[budget.id] ?? [],
        ),
      );
    }

    return results;
  }

  Duration _sumDurations(List<JournalEntity> entries) {
    return entries.fold(
      Duration.zero,
      (total, entry) => total + entryDuration(entry),
    );
  }

  BudgetProgressStatus _calculateStatus(
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
}

/// Provides total stats for a day's budgets.
@riverpod
Future<DayBudgetStats> dayBudgetStats(Ref ref, {required DateTime date}) async {
  final progress = await ref.watch(
    timeBudgetProgressControllerProvider(date: date).future,
  );

  final totalPlanned = progress.fold(
    Duration.zero,
    (total, p) => total + p.plannedDuration,
  );

  final totalRecorded = progress.fold(
    Duration.zero,
    (total, p) => total + p.recordedDuration,
  );

  final overBudgetCount =
      progress.where((p) => p.status == BudgetProgressStatus.overBudget).length;

  return DayBudgetStats(
    totalPlanned: totalPlanned,
    totalRecorded: totalRecorded,
    budgetCount: progress.length,
    overBudgetCount: overBudgetCount,
  );
}

/// Summary stats for a day's budgets.
class DayBudgetStats {
  const DayBudgetStats({
    required this.totalPlanned,
    required this.totalRecorded,
    required this.budgetCount,
    required this.overBudgetCount,
  });

  final Duration totalPlanned;
  final Duration totalRecorded;
  final int budgetCount;
  final int overBudgetCount;

  Duration get totalRemaining => totalPlanned - totalRecorded;
  bool get isOverBudget => totalRecorded > totalPlanned;

  double get progressFraction {
    if (totalPlanned.inMinutes == 0) return 0;
    return totalRecorded.inMinutes / totalPlanned.inMinutes;
  }
}
