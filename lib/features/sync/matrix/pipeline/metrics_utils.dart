// Metrics snapshot helpers for the sync pipeline

class MetricsUtils {
  const MetricsUtils._();

  /// Builds the metrics snapshot map used by the UI and logs, flattening
  /// counters and including diagnostics sizes.
  static Map<String, int> buildSnapshot({
    required int processed,
    required int skipped,
    required int failures,
    required int flushes,
    required int catchupBatches,
    required int skippedByRetryLimit,
    required int retriesScheduled,
    required int circuitOpens,
    required Map<String, int> processedByType,
    required Map<String, int> droppedByType,
    required int dbApplied,
    required int dbIgnoredByVectorClock,
    required int conflictsCreated,
    required List<String> lastIgnored,
  }) {
    return <String, int>{
        'processed': processed,
        'skipped': skipped,
        'failures': failures,
        'flushes': flushes,
        'catchupBatches': catchupBatches,
        'skippedByRetryLimit': skippedByRetryLimit,
        'retriesScheduled': retriesScheduled,
        'circuitOpens': circuitOpens,
        'dbApplied': dbApplied,
        'dbIgnoredByVectorClock': dbIgnoredByVectorClock,
        'conflictsCreated': conflictsCreated,
      }
      ..addEntries(
        processedByType.entries.map(
          (e) => MapEntry('processed.${e.key}', e.value),
        ),
      )
      ..addEntries(
        droppedByType.entries.map(
          (e) => MapEntry('droppedByType.${e.key}', e.value),
        ),
      )
      ..addEntries(<MapEntry<String, int>>[
        MapEntry('lastIgnoredCount', lastIgnored.length),
      ])
      ..addEntries(
        lastIgnored.asMap().entries.map(
          (e) => MapEntry('lastIgnored.${e.key + 1}', e.value.length),
        ),
      );
  }
}
