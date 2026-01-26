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
  late DateTime _date;
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

    // Start listening before fetch to avoid missing updates during fetch
    _listen();
    return _fetch();
  }

  Future<DayPlanEntry> _fetch() async {
    return _repository.getOrCreateDayPlan(_date);
  }

  /// Updates the day plan with new data.
  Future<void> updatePlan(DayPlanEntry updatedPlan) async {
    final savedPlan = await _repository.save(updatedPlan);
    state = AsyncData(savedPlan);
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
        triggeredAt: DateTime.now(),
        reason: reason,
        previouslyAgreedAt: agreed.agreedAt,
      ),
    );
  }

  /// Adds a planned block to the timeline.
  Future<void> addPlannedBlock(PlannedBlock block) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    var updatedData = current.data.copyWith(
      plannedBlocks: [...current.data.plannedBlocks, block],
    );
    updatedData = _transitionToNeedsReviewIfAgreed(
      updatedData,
      DayPlanReviewReason.blockModified,
    );

    final updated = current.copyWith(data: updatedData);
    await updatePlan(updated);
  }

  /// Updates an existing planned block.
  Future<void> updatePlannedBlock(PlannedBlock block) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    final updatedBlocks = current.data.plannedBlocks.map((b) {
      return b.id == block.id ? block : b;
    }).toList();

    var updatedData = current.data.copyWith(plannedBlocks: updatedBlocks);
    updatedData = _transitionToNeedsReviewIfAgreed(
      updatedData,
      DayPlanReviewReason.blockModified,
    );

    final updated = current.copyWith(data: updatedData);
    await updatePlan(updated);
  }

  /// Removes a planned block.
  Future<void> removePlannedBlock(String blockId) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    var updatedData = current.data.copyWith(
      plannedBlocks:
          current.data.plannedBlocks.where((b) => b.id != blockId).toList(),
    );
    updatedData = _transitionToNeedsReviewIfAgreed(
      updatedData,
      DayPlanReviewReason.blockModified,
    );

    final updated = current.copyWith(data: updatedData);
    await updatePlan(updated);
  }

  /// Pins a task to a category.
  Future<void> pinTask(PinnedTaskRef taskRef) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    var updatedData = current.data.copyWith(
      pinnedTasks: [...current.data.pinnedTasks, taskRef],
    );
    updatedData = _transitionToNeedsReviewIfAgreed(
      updatedData,
      DayPlanReviewReason.taskRescheduled,
    );

    final updated = current.copyWith(data: updatedData);
    await updatePlan(updated);
  }

  /// Unpins a task.
  Future<void> unpinTask(String taskId) async {
    final current = state.value;
    if (current is! DayPlanEntry) return;

    var updatedData = current.data.copyWith(
      pinnedTasks:
          current.data.pinnedTasks.where((t) => t.taskId != taskId).toList(),
    );
    updatedData = _transitionToNeedsReviewIfAgreed(
      updatedData,
      DayPlanReviewReason.taskRescheduled,
    );

    final updated = current.copyWith(data: updatedData);
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
