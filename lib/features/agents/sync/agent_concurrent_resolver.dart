import 'package:lotti/features/sync/vector_clock.dart';

/// Which of two concurrent versions of the same entity/link id should win.
enum ConcurrentWinner {
  /// Keep the version already stored locally.
  local,

  /// Apply the version received over sync.
  incoming,
}

/// Deterministically resolves two **concurrent** versions of one id into a
/// single winner, so every replica converges on the same version regardless of
/// arrival order.
///
/// Consulted only when [VectorClock.compare] returns `VclockStatus.concurrent`
/// (neither version dominates). Resolution order:
///
/// 1. **Last-writer-wins on `updatedAt`** — the strictly-newer write wins.
/// 2. **Equal `updatedAt` → stable tiebreak** — a replica-independent canonical
///    comparison of the two vector clocks. Both replicas hold both clocks, so
///    both compute the same winner; on genuinely concurrent clocks this always
///    discriminates. The degenerate equal-clock case falls back to `local` so
///    the result is total.
///
/// Pure: depends only on its arguments and performs no I/O, so identical inputs
/// yield the same winner on every device — the convergence guarantee. (Bounding
/// a skewed physical clock that wins outright by a strictly-greater `updatedAt`
/// is a separate concern requiring a monotonic/hybrid clock; out of scope here.)
///
/// **Convergent but lossy.** This picks a whole-version winner and discards the
/// loser; it does not merge. For a register that bundles *cumulative* fields —
/// notably `AgentStateEntity`'s `wakeCounter` / `processedCounterByHost` /
/// `toolCounterByKey` — the losing side's increments are lost under concurrent
/// (partition/split-brain) writes. The deterministic tiebreak only makes the
/// loser agree across replicas; it does not make the result non-lossy. Counter
/// fields should instead be derived from the append-only log or use a
/// counter-CRDT (roadmap PR 4 field-classification / PR 10); until then this is
/// a deliberate, lease-guarded (PR 7) bridge, not a "nothing is lost" merge.
ConcurrentWinner resolveConcurrent({
  required VectorClock localVc,
  required VectorClock incomingVc,
  required DateTime localUpdatedAt,
  required DateTime incomingUpdatedAt,
}) {
  if (incomingUpdatedAt.isAfter(localUpdatedAt)) {
    return ConcurrentWinner.incoming;
  }
  if (localUpdatedAt.isAfter(incomingUpdatedAt)) {
    return ConcurrentWinner.local;
  }
  return compareClocksCanonically(incomingVc, localVc) > 0
      ? ConcurrentWinner.incoming
      : ConcurrentWinner.local;
}

/// A total, replica-independent ordering of two vector clocks. Compares each
/// host's counter (0 when a host is absent) in sorted host order and returns
/// the sign of the first difference: `1` if [a] is greater, `-1` if [b] is
/// greater, `0` if the clocks are identical. Independent of map iteration
/// order, so two devices comparing the same pair agree.
int compareClocksCanonically(VectorClock a, VectorClock b) {
  final hosts = <String>{...a.vclock.keys, ...b.vclock.keys}.toList()..sort();
  for (final host in hosts) {
    final counterA = a.get(host);
    final counterB = b.get(host);
    if (counterA != counterB) return counterA > counterB ? 1 : -1;
  }
  return 0;
}
