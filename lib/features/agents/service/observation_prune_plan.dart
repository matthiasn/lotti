import 'package:meta/meta.dart';

/// A message as the prune planner sees it: identity, age, kind, and its
/// `messagePrev` parents.
///
/// Deliberately not the domain entity — the planner is a pure function of the
/// DAG's shape, and keeping it free of `AgentDomainEntity` makes every
/// invariant below testable without a database.
@immutable
class PrunableMessage {
  const PrunableMessage({
    required this.id,
    required this.createdAt,
    required this.isObservation,
    required this.parentIds,
    this.hintedParentIds = const [],
  });

  final String id;
  final DateTime createdAt;

  /// Only observations are prunable; every other message kind is the agent's
  /// durable memory.
  final bool isObservation;

  /// Parents named by an existing `messagePrev` **link row** (0..n; n > 1
  /// denotes a join). The canonical edge — `agentEventsFromLog` builds the
  /// causal graph from exactly these.
  final List<String> parentIds;

  /// Parents named only by the message's own `prevMessageId`, with no link row
  /// backing them.
  ///
  /// The two carry different evidence, and conflating them deadlocks the
  /// sweep. A link that is present while its parent is missing means the edge
  /// synced ahead of the node, so the parent is genuinely in flight. A
  /// `prevMessageId` with *no* link means the link was deleted — which is what
  /// this sweep does to every edge pointing into what it removes — so the
  /// parent is already collected and constrains nothing.
  final List<String> hintedParentIds;
}

/// What a sweep should delete for one agent's message log.
@immutable
class ObservationPrunePlan {
  const ObservationPrunePlan({required this.messageIds});

  /// Ids to hard-delete, in an order where every id precedes its descendants.
  ///
  /// Guaranteed **ancestor-closed**: if an id is here, every one of its
  /// `messagePrev` ancestors is here too.
  final List<String> messageIds;

  bool get isEmpty => messageIds.isEmpty;
}

/// Chooses the observations an agent may forget, without disturbing the shape
/// of its `messagePrev` DAG.
///
/// Three invariants make this safe, each guarding a distinct failure:
///
/// **1. The result is ancestor-closed, so pruning never manufactures a head.**
/// `project()` calls every event that nothing references a head. For a chain
/// `A <- B <- C` the head is `C`; delete `B` alone and `A` loses its only
/// child, so the projection reports two heads where the agent has one branch —
/// a fork out of thin air, which fork healing would then "heal" with a
/// pointless join. Deleting only ancestor-closed sets rules this out by
/// construction: if `X` is deleted, so is every parent of `X`, therefore no
/// surviving message can lose a child. A message is prunable only when it is
/// an old observation **and every one of its parents is prunable**, which
/// stops the moment a summary or a still-young observation is reached.
///
/// **2. Age alone is not the test.** Causal order and wall-clock order diverge
/// across devices, so "older than the cutoff" can select a message whose parent
/// is younger. The recursion above, not the timestamp, decides — the cutoff
/// only marks candidates.
///
/// **3. [protectedIds] are never pruned, nor is anything downstream of them.**
/// `agentState.recentHeadMessageId` and `latestSummaryMessageId` point into
/// this log; a log whose messages are *all* old observations would otherwise
/// be deleted whole, leaving live state pointing at a row that no longer
/// exists.
///
/// [limit] caps the plan while preserving closure: the result is built in
/// topological order, and a prefix of a topological order is always
/// ancestor-closed. Truncating a set sorted by age would not be.
///
/// **A message with an absent parent is never pruned.** Absence is not
/// evidence that the parent is gone: a `messagePrev` link can sync before the
/// entity it points at, so a parent still in flight looks identical to one an
/// earlier sweep took. Pruning on that guess deletes the child, drops the
/// edge, and forks the moment the parent lands. A parent an earlier sweep
/// really did take leaves no edge behind at all — the sweep deletes the edges
/// into whatever it deletes — so the honest reading of a dangling edge is
/// "not yet", and the row is simply collected on a later pass.
///
/// Pure: no clocks, no I/O. [cutoff] is supplied by the caller.
ObservationPrunePlan planObservationPrune({
  required Iterable<PrunableMessage> messages,
  required DateTime cutoff,
  required Set<String> protectedIds,
  required int limit,
}) {
  final byId = <String, PrunableMessage>{
    for (final message in messages) message.id: message,
  };

  /// Linked parents, plus hinted parents whose row is actually present — a
  /// hint that resolves is as binding as an edge, and one that does not names
  /// a row an earlier sweep took.
  List<String> effectiveParents(PrunableMessage message) => [
    ...message.parentIds,
    for (final id in message.hintedParentIds)
      if (byId.containsKey(id) && !message.parentIds.contains(id)) id,
  ];

  // Deterministic iteration order, so two devices with the same log produce
  // the same plan and a truncated sweep resumes predictably.
  final ordered = byId.values.toList()
    ..sort((a, b) {
      final byAge = a.createdAt.compareTo(b.createdAt);
      return byAge != 0 ? byAge : a.id.compareTo(b.id);
    });

  // Resolved lazily with an explicit stack: recursion would blow the frame
  // budget on a long-lived agent, which is exactly the case this exists for.
  final prunable = <String, bool>{};

  bool candidate(PrunableMessage message) =>
      message.isObservation &&
      message.createdAt.isBefore(cutoff) &&
      !protectedIds.contains(message.id);

  for (final root in ordered) {
    if (prunable.containsKey(root.id)) continue;
    final stack = <String>[root.id];
    final onStack = <String>{root.id};

    while (stack.isNotEmpty) {
      final id = stack.last;
      final message = byId[id];

      // A parent outside [messages] constrains nothing — see the doc comment.
      // Its entry is never read back (the `containsKey` guard short-circuits
      // first); it exists only to terminate the walk.
      if (message == null || !candidate(message)) {
        prunable[id] = false;
        stack.removeLast();
        onStack.remove(id);
        continue;
      }

      // A *linked* edge pointing at a row we cannot see: the node is still in
      // flight, so refuse rather than guess. A hinted parent that is absent
      // was collected by an earlier sweep and is ignored — otherwise the
      // oldest survivor, which keeps `prevMessageId` naming the row just
      // deleted, would block itself and everything after it forever.
      if (message.parentIds.any((parentId) => !byId.containsKey(parentId))) {
        prunable[id] = false;
        stack.removeLast();
        onStack.remove(id);
        continue;
      }

      final unresolved = [
        for (final parentId in effectiveParents(message))
          if (!prunable.containsKey(parentId) && !onStack.contains(parentId))
            parentId,
      ];
      if (unresolved.isNotEmpty) {
        stack.addAll(unresolved);
        onStack.addAll(unresolved);
        continue;
      }

      // A parent still on the stack — including this message itself — is a
      // cycle, so the log is malformed. Refuse to prune rather than reason
      // about it; the sweep is best-effort and a wrong delete is permanent.
      final cyclic = effectiveParents(message).any(onStack.contains);
      prunable[id] =
          !cyclic &&
          effectiveParents(
            message,
          ).every((parentId) => prunable[parentId] ?? false);
      stack.removeLast();
      onStack.remove(id);
    }
  }

  // Topological emission: a message is appended only once every prunable
  // parent has been, so any prefix of this list is ancestor-closed.
  final planned = <String>[];
  final emitted = <String>{};
  var progressed = true;
  while (progressed && planned.length < limit) {
    progressed = false;
    for (final message in ordered) {
      if (planned.length >= limit) break;
      if (emitted.contains(message.id)) continue;
      if (!(prunable[message.id] ?? false)) continue;
      final parentsReady = effectiveParents(message).every(emitted.contains);
      if (!parentsReady) continue;
      planned.add(message.id);
      emitted.add(message.id);
      progressed = true;
    }
  }

  return ObservationPrunePlan(messageIds: planned);
}
