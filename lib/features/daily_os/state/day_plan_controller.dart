import 'dart:async';

import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os/repository/day_plan_repository.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/utils/cache_extension.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'day_plan_controller.g.dart';

/// Provides the day plan for a specific date.
///
/// Automatically creates a draft plan if none exists.
/// Listens for updates and refreshes when the plan changes.
@riverpod
class DayPlanController extends _$DayPlanController {
  late final DateTime _date;
  StreamSubscription<Set<String>>? _updateSubscription;
  late DayPlanRepository _repository;

  void _listen() {
    final planId = dayPlanId(_date);
    _updateSubscription = _repository.updateStream.listen((affectedIds) async {
      if (affectedIds.contains(planId) ||
          affectedIds.contains(dayPlanNotification)) {
        final latest = await _fetch();
        if (latest != state.value) {
          state = AsyncData(latest);
        }
      }
    });
  }

  @override
  Future<JournalEntity?> build({required DateTime date}) async {
    _date = date;
    _repository = ref.read(dayPlanRepositoryProvider);

    ref
      ..onDispose(() => _updateSubscription?.cancel())
      ..cacheFor(entryCacheDuration);

    final result = await _fetch();
    _listen();
    return result;
  }

  Future<DayPlanEntry> _fetch() async {
    return _repository.getOrCreateDayPlan(_date);
  }

  /// Updates the day plan with new data.
  Future<void> updatePlan(DayPlanEntry updatedPlan) async {
    await _repository.save(updatedPlan);
    state = AsyncData(updatedPlan);
  }

  /// Agrees to the current plan.
  Future<void> agreeToPlan() async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final now = DateTime.now();
    final updated = current.copyWith(
      data: current.data.copyWith(
        status: DayPlanStatus.agreed(agreedAt: now),
        agreedAt: now,
      ),
    );
    await updatePlan(updated);
  }

  /// Marks the day as complete.
  Future<void> markComplete() async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final now = DateTime.now();
    final updated = current.copyWith(
      data: current.data.copyWith(completedAt: now),
    );
    await updatePlan(updated);
  }

  /// Adds a time budget to the plan.
  Future<void> addBudget(TimeBudget budget) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updated = current.copyWith(
      data: current.data.copyWith(
        budgets: [...current.data.budgets, budget],
      ),
    );
    await updatePlan(updated);
  }

  /// Updates an existing budget.
  Future<void> updateBudget(TimeBudget budget) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updatedBudgets = current.data.budgets.map((b) {
      return b.id == budget.id ? budget : b;
    }).toList();

    final updated = current.copyWith(
      data: current.data.copyWith(budgets: updatedBudgets),
    );
    await updatePlan(updated);
  }

  /// Removes a budget from the plan.
  Future<void> removeBudget(String budgetId) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updated = current.copyWith(
      data: current.data.copyWith(
        budgets: current.data.budgets.where((b) => b.id != budgetId).toList(),
        pinnedTasks: current.data.pinnedTasks
            .where((t) => t.budgetId != budgetId)
            .toList(),
      ),
    );
    await updatePlan(updated);
  }

  /// Adds a planned block to the timeline.
  Future<void> addPlannedBlock(PlannedBlock block) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updated = current.copyWith(
      data: current.data.copyWith(
        plannedBlocks: [...current.data.plannedBlocks, block],
      ),
    );
    await updatePlan(updated);
  }

  /// Removes a planned block.
  Future<void> removePlannedBlock(String blockId) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updated = current.copyWith(
      data: current.data.copyWith(
        plannedBlocks:
            current.data.plannedBlocks.where((b) => b.id != blockId).toList(),
      ),
    );
    await updatePlan(updated);
  }

  /// Pins a task to a budget.
  Future<void> pinTask(PinnedTaskRef taskRef) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updated = current.copyWith(
      data: current.data.copyWith(
        pinnedTasks: [...current.data.pinnedTasks, taskRef],
      ),
    );
    await updatePlan(updated);
  }

  /// Unpins a task from a budget.
  Future<void> unpinTask(String taskId) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updated = current.copyWith(
      data: current.data.copyWith(
        pinnedTasks:
            current.data.pinnedTasks.where((t) => t.taskId != taskId).toList(),
      ),
    );
    await updatePlan(updated);
  }

  /// Sets the day label.
  Future<void> setDayLabel(String? label) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updated = current.copyWith(
      data: current.data.copyWith(dayLabel: label),
    );
    await updatePlan(updated);
  }
}
