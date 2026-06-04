import 'package:equatable/equatable.dart';
import 'package:lotti/features/agents/projection/content_digest.dart';

/// Domain tag isolating the join-node digest from every other
/// content-addressed use (captured payloads, summary checkpoints — ADR 0017/
/// 0020): the tag is part of the hashed content, so digests of different
/// kinds hash different shapes and can never collide or be confused
/// (ADR 0018 rule 8).
const String _joinTag = 'join-v1';

/// Content-addressed id of the join-by-continuation node over [headIds]
/// (ADR 0018 rule 8).
///
/// Computed over the **sorted, de-duplicated** head set, so two devices healing
/// the *same* fork mint a byte-identical id — the log then set-unions their
/// concurrent emissions into a single node (no join storm). The id carries no
/// wall-clock, `hostId`, or vector clock: those live in the per-device envelope,
/// which the projection reconciles separately and never folds into identity.
String computeJoinId(Iterable<String> headIds) => ContentDigest.of({
  '_tag': _joinTag,
  'parents': _sortedUnique(headIds),
});

/// The decision to heal a fork: emit a join node with [joinId] linking
/// [parentIds] (the surviving heads) via `messagePrev`. Produced by [planJoin];
/// a null plan means "do not join this wake".
class JoinPlan extends Equatable {
  /// Wraps a plan. Callers obtain instances from [planJoin].
  const JoinPlan({required this.joinId, required this.parentIds});

  /// Content-addressed id of the join node ([computeJoinId] over [parentIds]).
  final String joinId;

  /// The heads to link as the join's `messagePrev` parents — **sorted,
  /// de-duplicated**, matching the set [joinId] was computed over.
  final List<String> parentIds;

  @override
  List<Object?> get props => [joinId, parentIds];
}

/// Decides whether to heal a fork at this wake start (ADR 0018 rule 8).
///
/// Pure function of the current [headIds] and whether the local DAG view is
/// complete ([viewComplete]). Returns a [JoinPlan] when **both** hold:
/// - there are **≥2 heads** — a single head is no fork, nothing to heal; and
/// - the local view is **complete**, i.e. no dangling parents. A `messagePrev`
///   edge syncs as a message separate from its endpoint node, so a node can
///   arrive before the edge that marks its child as the real tip; on that
///   transient view a non-tip masquerades as a head and healing would mint a
///   join over the wrong parent set. Defer until the view settles.
///
/// Returns null otherwise.
///
/// **Why healing eagerly at wake start is correct — and faithful to "≥2 heads
/// survive past one wake cycle".** A fork observed at *wake start* was created
/// by a *prior* cycle (the current wake has appended nothing yet), so it has
/// already survived the cycle that created it. Forks never self-resolve — two
/// concurrent branches stay forked until a join links them — so deferring would
/// only delay bounding the context, never spare an unnecessary join. The one
/// transient worth avoiding is the partially-synced view above, which
/// [viewComplete] gates.
///
/// **Convergence (ADR 0018 rule 8).** Two devices that observe the *identical*
/// head set emit the same [JoinPlan.joinId], which set-unions into one node.
/// Devices with *different* (partial) views heal different supersets that
/// self-correct — the resulting join heads form a smaller fork the next cycle
/// heals — converging in O(branches) bounded rounds, never storming (join ids
/// are monotone children of a strictly-growing parent set, so a join can never
/// re-create an existing ancestor).
JoinPlan? planJoin({
  required List<String> headIds,
  required bool viewComplete,
}) {
  final heads = _sortedUnique(headIds);
  if (heads.length < 2) return null;
  if (!viewComplete) return null;
  return JoinPlan(joinId: computeJoinId(heads), parentIds: heads);
}

List<String> _sortedUnique(Iterable<String> ids) =>
    ids.toSet().toList()..sort();
