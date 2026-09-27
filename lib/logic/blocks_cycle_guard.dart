import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

/// Whether inserting `blocks` edge `fromId -> toId` would close a cycle
/// already visible on this device (ADR 0042 §5): true iff [fromId] is
/// reachable by following live `blocks` edges forward from [toId].
///
/// Breadth-first via `JournalDb.typedLinksForTaskIds`, batched per hop rather
/// than per node, over every path: the visited set bounds it by the number
/// of tasks the chain reaches, so no depth cap is needed, and a cap would
/// let a long enough chain close a cycle unseen (ADR 0106).
///
/// A writer calls it once before reserving a clock, as a fast path, and
/// again inside the transaction that writes the link: only the second
/// check sees every link another writer on this device stored in between
/// (ADR 0106). Links another device writes concurrently can still close a
/// cycle; the readers report it (`findBlockersInCycle`).
///
/// [excludeLinkId], when supplied, ignores that link's own still-persisted
/// row during traversal — required when editing an existing `blocks` edge in
/// place (e.g. a direction flip), so the check doesn't see the edge's own
/// stale pre-edit state as an extra edge and reject a legitimate edit.
Future<bool> wouldCreateBlocksCycle({
  required String fromId,
  required String toId,
  String? excludeLinkId,
}) async {
  if (fromId == toId) return true;

  final journalDb = getIt<JournalDb>();
  final visited = <String>{toId};
  var frontier = <String>{toId};

  while (frontier.isNotEmpty) {
    final links = await journalDb.typedLinksForTaskIds(
      frontier,
      types: const {'BlocksLink'},
    );

    final next = <String>{};
    for (final link in links) {
      if (link.id == excludeLinkId) continue;
      if (!frontier.contains(link.fromId)) continue;
      final blocked = link.toId;
      if (blocked == fromId) return true;
      if (visited.add(blocked)) next.add(blocked);
    }
    frontier = next;
  }
  return false;
}
