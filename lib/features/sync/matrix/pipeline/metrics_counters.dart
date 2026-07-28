import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline/metrics_utils.dart';

/// Mutable counters for the sync pipeline's in-memory diagnostics.
///
/// Every counter here has a real increment call site. That is a deliberate
/// invariant, not an observation: this class used to carry a second, larger
/// set — throughput, retry, circuit-breaker and signal-ingestion tallies left
/// over from the pre-queue stream-processing architecture — whose incrementers
/// were never called after the inbound queue became the only receive path.
/// They rendered as permanent zeros in the Matrix Stats panel and read as
/// "nothing is happening", and at least one debugging session built a false
/// cold-start theory on `catchupBatches: 0`.
///
/// **A counter with no call site is worse than no counter**: it reports a
/// confident zero rather than absence. If you add one here, add its
/// incrementer at the same time — and a test that proves the increment fires.
///
/// The DB-apply counters are fed by `MatrixStreamProcessor` through the
/// `SyncEventProcessor.applyObserver` hook and are tracked regardless of
/// [collect]; `signalConnectivity` is bumped by the same processor when
/// connectivity resumes.
class MetricsCounters {
  MetricsCounters({
    this.collect = false,
    this.lastIgnoredMax = 10,
  });

  /// When false, the [collect]-gated counters stay at zero to avoid overhead
  /// outside diagnostics runs. DB-apply counters ignore this flag.
  final bool collect;
  final int lastIgnoredMax;

  int dbApplied = 0;
  int dbIgnoredByVectorClock = 0;
  int conflictsCreated = 0;
  int dbMissingBase = 0;
  int dbEntryLinkNoop = 0;

  /// Number of connectivity-driven nudges recorded when connectivity resumes.
  int signalConnectivity = 0;

  final Map<String, int> droppedByType = <String, int>{};

  final List<String> lastIgnored = <String>[];

  void bumpDroppedType(String? rt) {
    if (!collect) return;
    if (rt == null || rt.isEmpty) return;
    droppedByType.update(rt, (v) => v + 1, ifAbsent: () => 1);
  }

  void incSignalConnectivity() {
    if (!collect) return;
    signalConnectivity++;
  }

  // DB metrics are tracked regardless of collect
  void incDbApplied() => dbApplied++;
  void incDbIgnoredByVectorClock() => dbIgnoredByVectorClock++;
  void incConflictsCreated() => conflictsCreated++;
  void incDbMissingBase() => dbMissingBase++;
  void incDbEntryLinkNoop() => dbEntryLinkNoop++;

  void addLastIgnored(String entry) {
    msh.ringBufferAdd(lastIgnored, entry, lastIgnoredMax);
  }

  Map<String, int> snapshot() =>
      MetricsUtils.buildSnapshot(
          dbApplied: dbApplied,
          dbIgnoredByVectorClock: dbIgnoredByVectorClock,
          conflictsCreated: conflictsCreated,
          droppedByType: droppedByType,
          lastIgnored: lastIgnored,
        )
        ..putIfAbsent('dbMissingBase', () => dbMissingBase)
        ..putIfAbsent('dbEntryLinkNoop', () => dbEntryLinkNoop)
        ..putIfAbsent('signalConnectivity', () => signalConnectivity);
}
