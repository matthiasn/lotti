import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/daily_os_next/agents/service/day_agent_capture_helpers.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:meta/meta.dart';

/// Whether [entity], as a blocker, releases what it blocks (ADR 0042 §4): a
/// task that was deleted, or closed as `DONE`/`REJECTED`. Anything else keeps
/// blocking — an open task, and also an entry that is missing or not a task,
/// since a missing blocker more often means a sync gap than a removal.
bool blockerReleases(JournalEntity? entity) =>
    entity is Task && (entity.meta.deletedAt != null || isClosedTask(entity));

/// The blockers that are, in turn, blocked by the task they block, as
/// [findBlockersInCycle] resolves them.
@immutable
class BlocksCycles {
  const BlocksCycles({required this.inCycle, required this.visited});

  static const none = BlocksCycles(inCycle: {}, visited: {});

  /// Per task, the blockers the task itself blocks, directly or through
  /// other tasks. Tasks with none are absent.
  final Map<String, Set<String>> inCycle;

  /// Every task the search read, the given ones included. A reader that
  /// refreshes on updates watches these: closing any of them can break a
  /// cycle.
  final Set<String> visited;

  /// The blockers of [taskId] that it blocks in turn.
  Set<String> of(String taskId) => inCycle[taskId] ?? const {};
}

/// Finds, for each task in [blockersByTask], which of its blockers it blocks
/// in turn: the task and that blocker wait on each other, through a cycle
/// of live `blocks` links between tasks that are still blocking.
///
/// Two devices can each create a link while offline that together close a
/// cycle; the creation-time guard (`wouldCreateBlocksCycle`) only sees the
/// links its own device holds. ADR 0106 keeps both links — neither is the
/// user's mistake alone, and quietly dropping one would unblock a task the
/// user was told is blocked — and reports the cycle instead, on every device
/// the same way, because it is computed from the stored links and statuses
/// alone. Closing or deleting any task on the cycle releases the task it
/// blocks, as for every blocker.
///
/// [blockersByTask] maps each task to the ids of the blockers the caller
/// found blocking it. The search follows live `blocks` links forward from
/// the tasks, only out of tasks that still block ([blockerReleases] false),
/// one batch per hop, over every path: the visited set bounds it.
Future<BlocksCycles> findBlockersInCycle(
  JournalRepository repository, {
  required Map<String, Set<String>> blockersByTask,
}) async {
  final starts = {
    for (final entry in blockersByTask.entries)
      if (entry.value.isNotEmpty) entry.key,
  };
  if (starts.isEmpty) return BlocksCycles.none;

  final blocks = <String, Set<String>>{};
  final visited = {...starts};
  var frontier = starts;

  while (frontier.isNotEmpty) {
    final entities = await repository.getJournalEntitiesByIdsIncludingDeleted(
      frontier,
    );
    final byId = {for (final entity in entities) entity.id: entity};
    final blocking = {
      for (final id in frontier)
        if (!blockerReleases(byId[id])) id,
    };
    if (blocking.isEmpty) break;

    final links = await repository.getTypedLinksForTaskIds(
      blocking,
      linkTypes: const {'BlocksLink'},
    );
    final next = <String>{};
    for (final link in links) {
      if (link.deletedAt != null || !blocking.contains(link.fromId)) continue;
      blocks.putIfAbsent(link.fromId, () => {}).add(link.toId);
      if (visited.add(link.toId)) next.add(link.toId);
    }
    frontier = next;
  }

  final inCycle = <String, Set<String>>{};
  for (final taskId in starts) {
    final reached = _reachable(blocks, taskId);
    final mutual = blockersByTask[taskId]!.where(reached.contains).toSet();
    if (mutual.isNotEmpty) inCycle[taskId] = mutual;
  }
  return BlocksCycles(inCycle: inCycle, visited: visited);
}

/// Every task [from] reaches along [blocks].
Set<String> _reachable(Map<String, Set<String>> blocks, String from) {
  final reached = <String>{};
  final stack = [...?blocks[from]];
  while (stack.isNotEmpty) {
    final next = stack.removeLast();
    if (reached.add(next)) stack.addAll(blocks[next] ?? const {});
  }
  return reached;
}
