// Metrics snapshot helpers for the sync pipeline

/// Pure helpers that flatten the pipeline's counters into the flat
/// `Map<String, int>` snapshot the Stats UI and diagnostics logs consume.
class MetricsUtils {
  const MetricsUtils._();

  /// Builds the metrics snapshot map used by the UI and logs, flattening
  /// counters and including diagnostics sizes.
  ///
  /// Only counters with a real increment call site belong here — see the
  /// invariant documented on `MetricsCounters`.
  static Map<String, int> buildSnapshot({
    required int dbApplied,
    required int dbIgnoredByVectorClock,
    required int conflictsCreated,
    required Map<String, int> droppedByType,
    required List<String> lastIgnored,
  }) {
    return <String, int>{
        'dbApplied': dbApplied,
        'dbIgnoredByVectorClock': dbIgnoredByVectorClock,
        'conflictsCreated': conflictsCreated,
      }
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
