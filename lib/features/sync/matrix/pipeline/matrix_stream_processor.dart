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

  MetricsCounters get metrics => _metrics;
  bool get collectMetrics => _collectMetrics;

  void dispose() {}

  Map<String, int> metricsSnapshot() {
    final map = _metrics.snapshot(retryStateSize: 0, circuitIsOpen: false);
    try {
      final processed = map['processed'] ?? 0;
      final applied = map['dbApplied'] ?? 0;
      if (processed > 0 && applied > 0) {
        final ratio = processed / applied;
        map['processedPerAppliedPct'] = (ratio * 100).round();
      }
    } catch (_) {
      // best-effort only
    }
    return map;
  }

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

      String labelForSkip(JournalUpdateSkipReason reason) {
        switch (reason) {
          case JournalUpdateSkipReason.olderOrEqual:
            return msh.ignoredReasonFromStatus(status);
          case JournalUpdateSkipReason.conflict:
            return 'conflict';
          case JournalUpdateSkipReason.overwritePrevented:
            return reason.label;
          case JournalUpdateSkipReason.missingBase:
            return reason.label;
        }
      }

      void addIgnored(String label) {
        _metrics.addLastIgnored('${diag.eventId}:$label');
      }

      switch (diag.skipReason) {
        case JournalUpdateSkipReason.conflict:
          _metrics.incConflictsCreated();
          addIgnored(labelForSkip(JournalUpdateSkipReason.conflict));
        case JournalUpdateSkipReason.missingBase:
          _metrics.incDbMissingBase();
          addIgnored(labelForSkip(JournalUpdateSkipReason.missingBase));
        case JournalUpdateSkipReason.overwritePrevented:
          _metrics
            ..incDbIgnoredByVectorClock()
            ..bumpDroppedType(rt);
          addIgnored(labelForSkip(JournalUpdateSkipReason.overwritePrevented));
        case JournalUpdateSkipReason.olderOrEqual:
          _metrics
            ..incDbIgnoredByVectorClock()
            ..bumpDroppedType(rt);
          addIgnored(labelForSkip(JournalUpdateSkipReason.olderOrEqual));
        case null:
          _metrics
            ..incDbIgnoredByVectorClock()
            ..bumpDroppedType(rt);
          addIgnored(msh.ignoredReasonFromStatus(status));
      }
    } catch (_) {
      // best-effort only
    }
  }

  Map<String, String> diagnosticsStrings() {
    final map = <String, String>{
      'lastIgnoredCount': _metrics.lastIgnored.length.toString(),
    };
    try {
      final snap = _metrics.snapshot(retryStateSize: 0, circuitIsOpen: false);
      if (snap.containsKey('dbEntryLinkNoop')) {
        map['entryLink.noops'] = snap['dbEntryLinkNoop'].toString();
      }
    } catch (_) {
      // best-effort only
    }
    for (var i = 0; i < _metrics.lastIgnored.length; i++) {
      map['lastIgnored.${i + 1}'] = _metrics.lastIgnored[i];
    }
    return map;
  }

  void recordConnectivitySignal() {
    if (_collectMetrics) _metrics.incSignalConnectivity();
  }
}
