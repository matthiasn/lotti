import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_helpers.dart';
import 'package:lotti/features/tasks/repository/blocks_cycles.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:meta/meta.dart';

/// One blocker of a task, as resolved by [TaskDependencyResolver].
///
/// `title`/`status`/`categoryId` are null when the link exists but its target
/// task could not be loaded at all (sync gap) — ADR 0042 §4's "unresolvable
/// blocker keeps blocking" case. The entry is still emitted (never dropped) so
/// a task whose only blocker is unresolved still serializes to a non-empty
/// `blockedBy`, keeping it observably blocked rather than silently ready.
///
/// `categoryId` is carried because the blocked-work rule tells the model to
/// schedule the blocker itself, and `draft_day_plan` requires a `categoryId`
/// on every block. On a capture-less wake this object is the model's *only*
/// description of that blocker — it has no corpus row to read a category from
/// — so without it the model has to guess, and a blocker in a different
/// category than the task it blocks gets guessed wrong.
@immutable
class ResolvedBlocker {
  const ResolvedBlocker({
    required this.taskId,
    this.title,
    this.status,
    this.categoryId,
    this.cycle = false,
  });

  final String taskId;
  final String? title;
  final String? status;

  /// Category of the blocker task, so a plan block for it can be typed
  /// correctly rather than inheriting the blocked task's category.
  final String? categoryId;

  /// Whether the blocked task blocks this blocker in turn, directly or
  /// through other tasks (ADR 0106): the two wait on each other, so
  /// scheduling the blocker first cannot unblock anything. Serialized only
  /// when true.
  final bool cycle;

  Map<String, Object?> toJson() => {
    'taskId': taskId,
    if (title != null) 'title': title,
    if (status != null) 'status': status,
    if (categoryId != null) 'categoryId': categoryId,
    if (cycle) 'cycle': true,
  };

  @override
  bool operator ==(Object other) =>
      other is ResolvedBlocker &&
      other.taskId == taskId &&
      other.title == title &&
      other.status == status &&
      other.categoryId == categoryId &&
      other.cycle == cycle;

  @override
  int get hashCode => Object.hash(taskId, title, status, categoryId, cycle);
}

/// Batch, one-hop resolver for "which of these tasks are blocked, and by
/// what" (ADR 0043 §2). Generalizes the single-task classification
/// `TaskBlockersController._fetch` uses to N tasks: one type-scoped link
/// fetch + one batch blocker-status load for the distinct blocker ids, with
/// no per-task fan-out. Blockedness stays one hop; only the cycle report
/// (`findBlockersInCycle`, ADR 0106) follows the links further, in one
/// batch per hop for all the tasks together.
class TaskDependencyResolver {
  TaskDependencyResolver({required this.journalRepository});

  final JournalRepository journalRepository;

  /// Returns a map from blocked task id to its open/unresolved blockers.
  /// Keys are present only for tasks with at least one entry — absence means
  /// link-ready, mirroring the corpus's own "absence = ready" contract.
  ///
  /// [allowedCategoryIds] scopes what a blocker may *say about itself*, not
  /// whether it blocks. A blocker outside the caller's categories degrades to
  /// a bare `{taskId}` — the same shape as an unloadable one — so the blocked
  /// task stays observably blocked while its blocker's title, status and
  /// category stay inside the scope the caller was granted. An empty set means
  /// unrestricted, matching `categoryAllowed` elsewhere.
  ///
  /// This is not only about disclosure: the blocked-work rule tells the model
  /// to schedule the blocker, and the plan writer rejects a task id outside
  /// the agent's categories. Describing an unschedulable blocker in full
  /// invites a tool call that is guaranteed to be refused, while the bare
  /// marker steers the model to the rule's other branch — naming the blocker
  /// in the block's `reason`.
  Future<Map<String, List<ResolvedBlocker>>> resolveBlockedStatus(
    Set<String> taskIds, {
    Set<String> allowedCategoryIds = const {},
  }) async {
    if (taskIds.isEmpty) return const {};

    final links = await journalRepository.getTypedLinksForTaskIds(
      taskIds,
      linkTypes: const {'BlocksLink'},
    );

    final blockerIdsByTarget = <String, Set<String>>{};
    for (final link in links) {
      if (link.deletedAt != null) continue;
      if (!taskIds.contains(link.toId)) continue;
      blockerIdsByTarget.putIfAbsent(link.toId, () => {}).add(link.fromId);
    }
    if (blockerIdsByTarget.isEmpty) return const {};

    final blockerIds = {
      for (final ids in blockerIdsByTarget.values) ...ids,
    };
    final resolved = await journalRepository
        .getJournalEntitiesByIdsIncludingDeleted(blockerIds);
    final resolvedById = {for (final e in resolved) e.id: e};

    final stillBlocking = {
      for (final entry in blockerIdsByTarget.entries)
        entry.key: {
          for (final blockerId in entry.value)
            if (!blockerReleases(resolvedById[blockerId])) blockerId,
        },
    };
    final cycles = await findBlockersInCycle(
      journalRepository,
      blockersByTask: stillBlocking,
    );

    final result = <String, List<ResolvedBlocker>>{};
    for (final entry in stillBlocking.entries) {
      final inCycle = cycles.of(entry.key);
      final blockers = <ResolvedBlocker>[];
      for (final blockerId in entry.value) {
        final entity = resolvedById[blockerId];
        final cycle = inCycle.contains(blockerId);
        // Still blocks, but says nothing about itself: it did not resolve to
        // a task, or the caller was never granted its category, so its
        // title, status and category do not belong in whatever the caller is
        // about to render.
        if (entity is! Task ||
            !categoryAllowed(entity.meta.categoryId, allowedCategoryIds)) {
          blockers.add(ResolvedBlocker(taskId: blockerId, cycle: cycle));
          continue;
        }
        blockers.add(
          ResolvedBlocker(
            taskId: entity.id,
            title: entity.data.title,
            status: entity.data.status.toDbString,
            categoryId: entity.meta.categoryId,
            cycle: cycle,
          ),
        );
      }
      if (blockers.isNotEmpty) result[entry.key] = blockers;
    }
    return result;
  }
}

final taskDependencyResolverProvider = Provider<TaskDependencyResolver>(
  taskDependencyResolver,
  name: 'taskDependencyResolverProvider',
);
TaskDependencyResolver taskDependencyResolver(Ref ref) {
  return TaskDependencyResolver(
    journalRepository: ref.watch(journalRepositoryProvider),
  );
}
