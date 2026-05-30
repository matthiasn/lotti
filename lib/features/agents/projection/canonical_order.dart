import 'dart:collection';

import 'package:lotti/features/agents/projection/agent_event.dart';

/// Thrown when [canonicalOrder] receives two distinct events sharing an `id`.
///
/// Globally-unique `id`s are a hard invariant of the agent log; a collision
/// signals an upstream bug, so the kernel rejects the input loudly rather than
/// silently picking a winner.
class DuplicateEventIdException implements Exception {
  /// Creates the exception for the colliding [duplicateId].
  const DuplicateEventIdException(this.duplicateId);

  /// The id that appeared on more than one distinct event.
  final String duplicateId;

  @override
  String toString() =>
      'DuplicateEventIdException: more than one event carries id '
      '"$duplicateId"';
}

/// Thrown when the [AgentEvent.causalParents] edges contain a cycle.
///
/// Because edges (not vector-clock dominance) drive ordering, a malformed
/// upstream input can encode a cycle. Rather than emit a partial order, the
/// kernel fails loudly. (A vector-clock-dominance order, by contrast, is a DAG
/// by construction and could never reach this path.)
class ProjectionCycleException implements Exception {
  /// Creates the exception, capturing the [involvedIds] that never became
  /// orderable (i.e. retained an un-emitted parent).
  const ProjectionCycleException(this.involvedIds);

  /// The ids of events trapped in (or downstream of) the cycle.
  final List<String> involvedIds;

  @override
  String toString() =>
      'ProjectionCycleException: causalParents form a cycle involving '
      '${involvedIds.join(', ')}';
}

/// Produces the canonical linear extension of the causal partial order defined
/// by [AgentEvent.causalParents].
///
/// Determinism contract: the output is a pure function of the *set* of distinct
/// events. For any [Iterable] ordering of the same events, the result is
/// identical — this is the permutation-invariance the whole projection design
/// rests on.
///
/// Algorithm: Kahn-style topological sort over the parent edges. Among events
/// with no un-emitted *present* parent, the one with the smallest
/// `(hostId, id)` key is emitted next, so concurrent branches order
/// deterministically. Parents referenced but absent from the input (dangling)
/// impose no constraint — such an event is treated as a root. Cost is O(V + E).
///
/// Throws [DuplicateEventIdException] if two distinct events share an `id`, and
/// [ProjectionCycleException] if the edges contain a cycle.
List<AgentEvent> canonicalOrder(Iterable<AgentEvent> events) {
  // Validate ids on the raw Iterable, before any set membership collapses or
  // duplicates them.
  final byId = <String, AgentEvent>{};
  for (final event in events) {
    final existing = byId[event.id];
    if (existing != null && existing != event) {
      throw DuplicateEventIdException(event.id);
    }
    byId[event.id] = event;
  }

  // Build the dependency graph over *present* parents only.
  final indegree = <String, int>{for (final id in byId.keys) id: 0};
  final children = <String, List<AgentEvent>>{};
  for (final event in byId.values) {
    // causalParents is normalized sorted-unique by AgentEvent's constructor.
    for (final parentId in event.causalParents) {
      if (!byId.containsKey(parentId)) continue; // dangling — see project()
      indegree[event.id] = indegree[event.id]! + 1;
      (children[parentId] ??= <AgentEvent>[]).add(event);
    }
  }

  final ready = SplayTreeSet<AgentEvent>(_byHostThenId);
  for (final event in byId.values) {
    if (indegree[event.id] == 0) ready.add(event);
  }

  final ordered = <AgentEvent>[];
  while (ready.isNotEmpty) {
    final next = ready.first;
    ready.remove(next);
    ordered.add(next);
    for (final child in children[next.id] ?? const <AgentEvent>[]) {
      final remaining = indegree[child.id]! - 1;
      indegree[child.id] = remaining;
      if (remaining == 0) ready.add(child);
    }
  }

  if (ordered.length != byId.length) {
    final emitted = {for (final event in ordered) event.id};
    final stuck = byId.keys.where((id) => !emitted.contains(id)).toList()
      ..sort();
    throw ProjectionCycleException(stuck);
  }

  return ordered;
}

/// Total order on distinct events: `hostId` first, then `id`. Because ids are
/// globally unique (enforced by [canonicalOrder]), this never returns 0 for two
/// distinct events, so it is a strict total order safe for [SplayTreeSet].
int _byHostThenId(AgentEvent a, AgentEvent b) {
  final byHost = a.hostId.compareTo(b.hostId);
  if (byHost != 0) return byHost;
  return a.id.compareTo(b.id);
}
