import 'package:lotti/features/sync/matrix/pipeline_v2/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline_v2/metrics_utils.dart';

class MetricsCounters {
  MetricsCounters({
    this.collect = false,
    this.lastIgnoredMax = 10,
    this.lastPrefetchedMax = 10,
  });

  final bool collect;
  final int lastIgnoredMax;
  final int lastPrefetchedMax;

  int processed = 0;
  int skipped = 0;
  int failures = 0;
  int prefetch = 0;
  int flushes = 0;
  int catchupBatches = 0;
  int skippedByRetryLimit = 0;
  int retriesScheduled = 0;
  int circuitOpens = 0;
  // Live-scan look-behind observability
  int lookBehindMerges = 0;
  int lastLookBehindTail = 0;

  int dbApplied = 0;
  int dbIgnoredByVectorClock = 0;
  int conflictsCreated = 0;
  int dbMissingBase = 0;
  int dbEntryLinkNoop = 0;

  final Map<String, int> processedByType = <String, int>{};
  final Map<String, int> droppedByType = <String, int>{};

  final List<String> lastIgnored = <String>[];
  final List<String> lastPrefetched = <String>[];

  void incProcessed() {
    if (!collect) return;
    processed++;
  }

  void incProcessedWithType(String? rt) {
    if (!collect) return;
    processed++;
    bumpProcessedType(rt);
  }

  void bumpProcessedType(String? rt) {
    if (!collect) return;
    if (rt == null || rt.isEmpty) return;
    processedByType.update(rt, (v) => v + 1, ifAbsent: () => 1);
  }

  void bumpDroppedType(String? rt) {
    if (!collect) return;
    if (rt == null || rt.isEmpty) return;
    droppedByType.update(rt, (v) => v + 1, ifAbsent: () => 1);
  }

  void incSkipped() {
    if (!collect) return;
    skipped++;
  }

  void incFailures() {
    if (!collect) return;
    failures++;
  }

  void incPrefetch() {
    if (!collect) return;
    prefetch++;
  }

  void incFlushes() {
    if (!collect) return;
    flushes++;
  }

  void incCatchupBatches() {
    if (!collect) return;
    catchupBatches++;
  }

  void incSkippedByRetryLimit() {
    if (!collect) return;
    skippedByRetryLimit++;
  }

  void incRetriesScheduled() {
    if (!collect) return;
    retriesScheduled++;
  }

  void incCircuitOpens() {
    if (!collect) return;
    circuitOpens++;
  }

  void recordLookBehindMerge(int tail) {
    if (!collect) return;
    lookBehindMerges++;
    lastLookBehindTail = tail;
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

  void addLastPrefetched(String path) {
    msh.ringBufferAdd(lastPrefetched, path, lastPrefetchedMax);
  }

  Map<String, int> snapshot({
    required int retryStateSize,
    required bool circuitIsOpen,
  }) {
    final base = MetricsUtils.buildSnapshot(
      processed: processed,
      skipped: skipped,
      failures: failures,
      prefetch: prefetch,
      flushes: flushes,
      catchupBatches: catchupBatches,
      skippedByRetryLimit: skippedByRetryLimit,
      retriesScheduled: retriesScheduled,
      circuitOpens: circuitOpens,
      processedByType: processedByType,
      droppedByType: droppedByType,
      dbApplied: dbApplied,
      dbIgnoredByVectorClock: dbIgnoredByVectorClock,
      conflictsCreated: conflictsCreated,
      lastIgnored: lastIgnored,
      lastPrefetched: lastPrefetched,
      retryStateSize: retryStateSize,
      circuitOpen: circuitIsOpen,
    )
      ..putIfAbsent('dbMissingBase', () => dbMissingBase)
      ..putIfAbsent('dbEntryLinkNoop', () => dbEntryLinkNoop)
      ..putIfAbsent('lookBehindMerges', () => lookBehindMerges)
      ..putIfAbsent('lastLookBehindTail', () => lastLookBehindTail);
    return base;
  }

  String buildFlushLog({required int retriesPending}) {
    final base =
        'v2 metrics flush=$flushes processed=$processed skipped=$skipped failures=$failures prefetch=$prefetch catchup=$catchupBatches skippedByRetry=$skippedByRetryLimit retriesScheduled=$retriesScheduled retriesPending=$retriesPending';
    // Append a compact processedByType breakdown (e.g., entryLink=3,journalEntity=10)
    if (processedByType.isEmpty) return base;
    final entries = processedByType.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final byType = entries.map((e) => '${e.key}=${e.value}').join(',');
    return '$base byType=$byType';
  }
}
