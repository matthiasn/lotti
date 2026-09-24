import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';

/// Reads of one replica's local `messagePrev` DAG that keep the agent's head
/// pointer moving forward (ADR 0076).
///
/// A message's children here are the messages whose `messagePrev` edge
/// names it and whose own row is present and live — the same edges the
/// projection folds (`agentEventsFromLog` loads edges by child id). Walks go
/// forward from a head, so they visit only what is newer than it: nothing
/// for a head that is still a tip, which is the common case.
class AgentMessageDag {
  const AgentMessageDag(this._repository);

  final AgentRepository _repository;

  /// Whether [ancestorId] is a proper ancestor of [descendantId] here.
  /// `false` also when a row or edge that would show it has not synced yet.
  Future<bool> isAncestor(String ancestorId, String descendantId) async {
    final seen = <String>{ancestorId};
    var frontier = <String>{ancestorId};
    while (frontier.isNotEmpty) {
      final next = <String>{};
      for (final children in (await _childrenOf(frontier)).values) {
        for (final child in children) {
          if (child == descendantId) return true;
          if (seen.add(child)) next.add(child);
        }
      }
      frontier = next;
    }
    return false;
  }

  /// The order between two state versions' heads that a merge needs
  /// ([mergeAgentHeads]), read before the merge so the resolver stays pure.
  /// Answers only for the pair [a], [b]; every other question, like an
  /// unknown order, is `false`.
  Future<MessageAncestry> ancestryOf(String? a, String? b) async {
    if (a == null || b == null || a == b) return noKnownAncestry;
    final aBelowB = await isAncestor(a, b);
    final bBelowA = !aBelowB && await isAncestor(b, a);
    return (String ancestorId, String descendantId) =>
        (aBelowB && ancestorId == a && descendantId == b) ||
        (bBelowA && ancestorId == b && descendantId == a);
  }

  /// A tip at or beyond [head]: [head] itself while nothing here descends
  /// from it, otherwise the end of a walk that follows, at every step, the
  /// child with the lowest id.
  ///
  /// The head pointer is a field of the synced state row, so it can trail
  /// the log: a state version resolved before the rows that order its head
  /// arrived, or a row lagging behind the messages that synced in. An
  /// append chaining off such a head would fork the log although this device
  /// already holds the head's successor.
  Future<String> tipFrom(String head) async {
    final seen = <String>{head};
    var tip = head;
    while (true) {
      final children = (await _childrenOf([tip]))[tip];
      if (children == null) return tip;
      final next = children.first;
      // A cycle synced in from a peer: stop rather than loop.
      if (!seen.add(next)) return tip;
      tip = next;
    }
  }

  /// The present, live children of each of [parents], sorted by id.
  Future<Map<String, List<String>>> _childrenOf(
    Iterable<String> parents,
  ) async {
    final links = await _repository.getLinksToMultiple(
      parents.toList(),
      type: AgentLinkTypes.messagePrev,
    );
    final childIds = {
      for (final group in links.values)
        for (final link in group) link.fromId,
    };
    if (childIds.isEmpty) return const {};
    final present = await _repository.getEntitiesByIds(childIds);
    final result = <String, List<String>>{};
    for (final MapEntry(key: parent, value: group) in links.entries) {
      final children = [
        for (final link in group)
          if (present[link.fromId] is AgentMessageEntity) link.fromId,
      ];
      if (children.isNotEmpty) result[parent] = children..sort();
    }
    return result;
  }
}
