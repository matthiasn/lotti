import 'package:flutter/material.dart'; // metrics section (renamed from v2_metrics_section)
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/sync/ui/matrix_stats/diagnostics_panel.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_actions.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_grid.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class SyncMetricsSection extends StatelessWidget {
  const SyncMetricsSection({
    required this.metrics,
    required this.lastUpdated,
    required this.onForceRescan,
    required this.onRetryNow,
    required this.onCopyDiagnostics,
    required this.onRefresh,
    required this.fetchDiagnostics,
    required this.title,
    required this.lastUpdatedLabel,
    super.key,
  });

  final Map<String, int> metrics;
  final DateTime? lastUpdated;
  final VoidCallback onForceRescan;
  final VoidCallback onRetryNow;
  final VoidCallback onCopyDiagnostics;
  final VoidCallback onRefresh;
  final Future<String> Function() fetchDiagnostics;
  final String title;
  final String lastUpdatedLabel;

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final t = dt.toLocal().toIso8601String();
    return t.length >= 19 ? t.substring(11, 19) : t;
  }

  List<MapEntry<String, int>> _select(
    Map<String, int> m,
    bool Function(String) pred,
  ) {
    return m.entries.where((e) => pred(e.key)).toList()
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  String _labelFor(BuildContext context, String key) {
    final messages = context.messages;
    if (key.startsWith('processed.')) {
      return messages.matrixStatsProcessedByType(
        key.substring('processed.'.length),
      );
    }
    if (key.startsWith('droppedByType.')) {
      return messages.matrixStatsDroppedByType(
        key.substring('droppedByType.'.length),
      );
    }
    return switch (key) {
      'processed' => messages.matrixStatsProcessed,
      'skipped' => messages.matrixStatsSkipped,
      'failures' => messages.matrixStatsFailures,
      'flushes' => messages.matrixStatsFlushes,
      'catchupBatches' => messages.matrixStatsCatchupBatches,
      'skippedByRetryLimit' => messages.matrixStatsSkippedRetryCap,
      'retriesScheduled' => messages.matrixStatsRetriesScheduled,
      'circuitOpens' => messages.matrixStatsCircuitOpens,
      'dbApplied' => messages.matrixStatsDbApplied,
      'dbIgnoredByVectorClock' => messages.matrixStatsDbIgnoredVectorClock,
      'conflictsCreated' => messages.matrixStatsConflicts,
      'dbMissingBase' => messages.matrixStatsDbMissingBase,
      'dbEntryLinkNoop' => messages.matrixStatsEntryLinkNoops,
      'staleAttachmentPurges' => messages.matrixStatsStaleAttachmentPurges,
      'signalClientStream' => messages.matrixStatsSignalsClientStream,
      'signalTimelineCallbacks' => messages.matrixStatsSignalsTimelineCallbacks,
      'signalConnectivity' => messages.matrixStatsSignalsConnectivity,
      'signalLatencyLastMs' => messages.matrixStatsSignalLatencyLast,
      'signalLatencyMinMs' => messages.matrixStatsSignalLatencyMin,
      'signalLatencyMaxMs' => messages.matrixStatsSignalLatencyMax,
      _ => key,
    };
  }

  Map<String, List<MapEntry<String, int>>> _grouped(
    BuildContext context,
    Map<String, int> v2,
  ) {
    final messages = context.messages;
    final throughput = _select(
      v2,
      (k) =>
          k == 'processed' ||
          k == 'flushes' ||
          k == 'catchupBatches' ||
          k == 'retriesScheduled' ||
          k.startsWith('processed.'),
    );
    final reliability = _select(
      v2,
      (k) =>
          k == 'failures' ||
          k == 'skipped' ||
          k == 'skippedByRetryLimit' ||
          k == 'circuitOpens',
    );
    final db = _select(
      v2,
      (k) =>
          k == 'dbApplied' ||
          k == 'dbIgnoredByVectorClock' ||
          k == 'conflictsCreated' ||
          k == 'dbMissingBase' ||
          k == 'dbEntryLinkNoop' ||
          k == 'staleAttachmentPurges' ||
          k.startsWith('droppedByType.'),
    );
    final signals = _select(
      v2,
      (k) =>
          k == 'signalClientStream' ||
          k == 'signalTimelineCallbacks' ||
          k == 'signalConnectivity' ||
          k == 'signalLatencyLastMs' ||
          k == 'signalLatencyMinMs' ||
          k == 'signalLatencyMaxMs',
    ).where((e) => e.value != 0).toList();
    final sections = <String, List<MapEntry<String, int>>>{
      messages.matrixStatsThroughput: throughput,
      messages.matrixStatsReliability: reliability,
      messages.matrixStatsDbApply: db,
    };
    if (signals.isNotEmpty) {
      sections[messages.matrixStatsSignals] = signals;
    }
    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: tokens.spacing.step3,
          runSpacing: tokens.spacing.step1,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              title,
              style: tokens.typography.styles.subtitle.subtitle1,
            ),
            Text(
              lastUpdated == null
                  ? '$lastUpdatedLabel —'
                  : '$lastUpdatedLabel ${_formatTime(lastUpdated)}',
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        MetricsActions(
          onForceRescan: onForceRescan,
          onRetryNow: onRetryNow,
          onCopyDiagnostics: onCopyDiagnostics,
          onRefresh: onRefresh,
        ),
        const SizedBox(height: 12),
        // Top KPIs with optional sparklines
        Builder(
          builder: (context) {
            const kpiKeys = ['processed', 'failures', 'retriesScheduled'];
            final kpiEntries =
                metrics.entries.where((e) => kpiKeys.contains(e.key)).toList()
                  ..sort(
                    (a, b) => kpiKeys
                        .indexOf(a.key)
                        .compareTo(kpiKeys.indexOf(b.key)),
                  );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kpiEntries.isNotEmpty) Text(messages.matrixStatsTopKpis),
                if (kpiEntries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 12),
                    child: MetricsGrid(
                      entries: kpiEntries,
                      labelFor: (key) => _labelFor(context, key),
                    ),
                  ),
              ],
            );
          },
        ),
        // Grouped sections
        ..._grouped(context, metrics).entries.expand(
          (section) => [
            RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  section.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            RepaintBoundary(
              child: MetricsGrid(
                entries: section.value,
                labelFor: (key) => _labelFor(context, key),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
        DiagnosticsPanel(fetchDiagnostics: fetchDiagnostics),
      ],
    );
  }
}
