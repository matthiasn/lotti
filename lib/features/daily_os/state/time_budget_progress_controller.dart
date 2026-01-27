import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/state/unified_daily_os_data_controller.dart';
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

/// Computed progress for a category's time budget (derived from blocks).
class TimeBudgetProgress {
  const TimeBudgetProgress({
    required this.categoryId,
    required this.category,
    required this.plannedDuration,
    required this.recordedDuration,
    required this.status,
    required this.contributingEntries,
    required this.pinnedTasks,
    required this.blocks,
  });

  final String categoryId;
  final CategoryDefinition? category;
  final Duration plannedDuration;
  final Duration recordedDuration;
  final BudgetProgressStatus status;
  final List<JournalEntity> contributingEntries;

  /// Tasks pinned to this category (resolved from PinnedTaskRef).
  final List<Task> pinnedTasks;

  /// The planned blocks that contribute to this budget.
  final List<PlannedBlock> blocks;

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

/// Provides total stats for a day's budgets.
///
/// Uses the unified controller to ensure consistent updates when entries change.
@riverpod
Future<DayBudgetStats> dayBudgetStats(Ref ref, {required DateTime date}) async {
  final unifiedData = await ref.watch(
    unifiedDailyOsDataControllerProvider(date: date).future,
  );
  final progress = unifiedData.budgetProgress;

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
