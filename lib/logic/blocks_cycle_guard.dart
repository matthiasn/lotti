import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';

/// Depth cap for [wouldCreateBlocksCycle]'s local traversal. Task-relationship
/// chains are short in practice (ADR 0042 §4: readiness is one hop, chains are
/// the exception); this bounds the best-effort creation-time guard without
/// needing a real graph size limit.
const blocksCycleGuardMaxHops = 64;

/// Whether inserting `blocks` edge `fromId -> toId` would close a cycle
/// already visible on this device (ADR 0042 §5): true iff [fromId] is
/// reachable by following existing `blocks` edges forward from [toId].
///
/// Bounded breadth-first traversal via `JournalDb.typedLinksForTaskIds` —
/// batched per hop rather than per-node, and capped at
/// [blocksCycleGuardMaxHops] hops so a pathological chain cannot make link
/// creation hang.
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

  for (
    var hop = 0;
    hop < blocksCycleGuardMaxHops && frontier.isNotEmpty;
    hop++
  ) {
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
