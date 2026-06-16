import 'package:lotti/database/journal_update_result.dart';
import 'package:lotti/features/sync/matrix/pipeline/matrix_stream_helpers.dart'
    as msh;
import 'package:lotti/features/sync/matrix/pipeline/metrics_counters.dart';
import 'package:lotti/features/sync/matrix/sync_event_processor.dart';

/// Metrics + diagnostics aggregator for the queue pipeline.
///
/// Receives DB-apply outcomes via the `SyncEventProcessor.applyObserver`
/// hook (wired in `MatrixService`) and surfaces them as numeric snapshots
/// and textual diagnostics for the Matrix Stats UI.
class MatrixStreamProcessor {
  MatrixStreamProcessor({
    MetricsCounters? metricsCounters,
    bool collectMetrics = false,
  }) : _collectMetrics = collectMetrics,
       _metrics = metricsCounters ?? MetricsCounters(collect: collectMetrics);

  final bool _collectMetrics;
  final MetricsCounters _metrics;

  Map<String, int> metricsSnapshot() {
    final map = _metrics.snapshot();
    final processed = map['processed'] ?? 0;
    final applied = map['dbApplied'] ?? 0;
    if (processed > 0 && applied > 0) {
      map['processedPerAppliedPct'] = (processed / applied * 100).round();
    }
    return map;
  }

  /// Folds one DB-apply outcome into the metrics counters: bumps `dbApplied`
  /// when the write landed, or classifies the skip (conflict, missing base,
  /// vector-clock-ignored, entry-link no-op) into the matching dropped-by-type
  /// and `lastIgnored` diagnostics. Best-effort — never throws into the apply
  /// path.
  void reportDbApplyDiagnostics(SyncApplyDiagnostics diag) {
    try {
      final applied = diag.applied;
      final status = diag.conflictStatus;
      final rt = diag.payloadType;
      if (rt == 'entryLink') {
        if (applied) {
          _metrics.incDbApplied();
        } else {
          _metrics
            ..incDbEntryLinkNoop()
            ..bumpDroppedType('entryLink')
            ..addLastIgnored('${diag.eventId}:entryLink.noop');
        }
        return;
      }

      if (applied) {
        _metrics.incDbApplied();
        return;
      }

      String labelFor(JournalUpdateSkipReason? reason) =>
          reason == JournalUpdateSkipReason.olderOrEqual || reason == null
          ? msh.ignoredReasonFromStatus(status)
          : reason.label;

      void addIgnored(String label) {
        _metrics.addLastIgnored('${diag.eventId}:$label');
      }

      switch (diag.skipReason) {
        case JournalUpdateSkipReason.conflict:
          _metrics.incConflictsCreated();
        case JournalUpdateSkipReason.missingBase:
          _metrics.incDbMissingBase();
        case JournalUpdateSkipReason.overwritePrevented:
        case JournalUpdateSkipReason.olderOrEqual:
        case null:
          _metrics
            ..incDbIgnoredByVectorClock()
            ..bumpDroppedType(rt);
      }
      addIgnored(labelFor(diag.skipReason));
    } catch (_) {
      // best-effort only
    }
  }

  Map<String, String> diagnosticsStrings() {
    final map = <String, String>{
      'lastIgnoredCount': _metrics.lastIgnored.length.toString(),
      'entryLink.noops': _metrics.dbEntryLinkNoop.toString(),
    };
    for (var i = 0; i < _metrics.lastIgnored.length; i++) {
      map['lastIgnored.${i + 1}'] = _metrics.lastIgnored[i];
    }
    return map;
  }

  void recordConnectivitySignal() {
    if (_collectMetrics) _metrics.incSignalConnectivity();
  }
}
