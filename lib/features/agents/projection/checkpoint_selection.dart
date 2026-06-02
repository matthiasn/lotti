import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/projection/agent_event.dart';
import 'package:lotti/features/agents/projection/agent_projection.dart';

/// The compaction checkpoint a wake reads from, selected from the event DAG
/// (ADR 0017). A `summary` event's `causalParents` are the frontier it folds,
/// so its **covered set** is its inclusive ancestor set, and the **active
/// checkpoint** is the deepest summary that is an ancestor of *every* head —
/// the maximal complete materialized checkpoint ancestral to all heads.
///
/// Context for the wake is then `active summary + uncovered tail`, where the
/// uncovered tail is the **original, non-summary** events not in the covered
/// set (non-active summary events are excluded — ADR 0017 Decision 3), in
/// canonical order.
class CheckpointSelection extends Equatable {
  /// Wraps a selection. Callers obtain instances from [selectActiveCheckpoint].
  const CheckpointSelection({
    required this.activeCheckpointId,
    required this.coveredIds,
    required this.uncoveredTailIds,
  });

  /// The id of the active checkpoint, or null when no summary is ancestral to
  /// every head yet (a young agent, or branches whose only summaries are not
  /// common — the common base is then genesis, i.e. nothing covered).
  final String? activeCheckpointId;

  /// The ids the active checkpoint covers (its inclusive ancestor set),
  /// sorted. Empty when [activeCheckpointId] is null.
  final List<String> coveredIds;

  /// The original, non-summary events not covered by the active checkpoint, in
  /// canonical order — the verbatim tail to read after the summary.
  final List<String> uncoveredTailIds;

  @override
  List<Object?> get props => [activeCheckpointId, coveredIds, uncoveredTailIds];
}

/// Selects the active compaction checkpoint over [ordered] (expected to be the
/// output of `canonicalOrder`, so the result is a pure function of the event
/// *set*).
///
/// Algorithm (ADR 0017 Decision 3):
/// 1. heads = events no present event references as a causal parent;
/// 2. a summary is a *candidate* iff it is an inclusive ancestor of every head
///    (on the common trunk) — this naturally yields the **meet (common base)**
///    when branches diverged after a summary, and excludes summaries living on
///    only one branch;
/// 3. the **active** checkpoint is the candidate covering the most history
///    (largest inclusive-ancestor set); ties — concurrent summaries over the
///    same frontier — break by lowest id (a stand-in for ADR 0017's
///    `(contentDigest, id)` until materialized summaries carry a content digest
///    in C4);
/// 4. the uncovered tail is every non-summary event not in the covered set.
CheckpointSelection selectActiveCheckpoint(Iterable<AgentEvent> ordered) {
  final events = ordered.toList(growable: false);
  if (events.isEmpty) {
    return const CheckpointSelection(
      activeCheckpointId: null,
      coveredIds: [],
      uncoveredTailIds: [],
    );
  }

  // [events] is `canonicalOrder` output — every causal parent precedes its
  // child — so a single **forward pass** builds each event's inclusive ancestor
  // set by unioning its present parents' already-computed sets. This is
  // iterative by construction: no recursion, so a long linear history cannot
  // overflow the VM stack (and a cycle can't arise — `canonicalOrder` rejects
  // it upstream).
  final ancestors = <String, Set<String>>{};
  for (final event in events) {
    final set = <String>{event.id};
    for (final parentId in event.causalParents) {
      final parentAncestors = ancestors[parentId];
      if (parentAncestors != null) set.addAll(parentAncestors);
    }
    ancestors[event.id] = set;
  }

  final heads = project(events).headIds;

  // Common ancestors = intersection of every head's inclusive ancestors.
  Set<String>? common;
  for (final head in heads) {
    final headAncestors = ancestors[head] ?? <String>{head};
    common = common == null
        ? {...headAncestors}
        : (common..retainAll(headAncestors));
  }
  common ??= <String>{};

  // Candidate summaries on the common trunk, by descending coverage then id.
  AgentEvent? active;
  var bestCoverage = -1;
  for (final event in events) {
    if (event.kind != AgentEventKind.summary) continue;
    if (!common.contains(event.id)) continue;
    final coverage = (ancestors[event.id] ?? const <String>{}).length;
    if (coverage > bestCoverage ||
        (coverage == bestCoverage &&
            (active == null || event.id.compareTo(active.id) < 0))) {
      active = event;
      bestCoverage = coverage;
    }
  }

  if (active == null) {
    return CheckpointSelection(
      activeCheckpointId: null,
      coveredIds: const [],
      uncoveredTailIds: [
        for (final event in events)
          if (event.kind != AgentEventKind.summary) event.id,
      ],
    );
  }

  final covered = ancestors[active.id] ?? <String>{active.id};
  return CheckpointSelection(
    activeCheckpointId: active.id,
    coveredIds: covered.toList()..sort(),
    uncoveredTailIds: [
      for (final event in events)
        if (event.kind != AgentEventKind.summary && !covered.contains(event.id))
          event.id,
    ],
  );
}
