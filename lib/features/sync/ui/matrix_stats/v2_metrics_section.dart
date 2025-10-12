import 'package:flutter/material.dart';
import 'package:lotti/features/sync/ui/matrix_stats/diagnostics_panel.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_actions.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_grid.dart';

class V2MetricsSection extends StatelessWidget {
  const V2MetricsSection({
    required this.metrics,
    required this.lastUpdated,
    required this.onForceRescan,
    required this.onRetryNow,
    required this.onCopyDiagnostics,
    required this.onRefresh,
    required this.fetchDiagnostics,
    required this.title,
    required this.lastUpdatedLabel,
    this.history,
    super.key,
  });

  final Map<String, int> metrics;
  final DateTime? lastUpdated;
  final Map<String, List<int>>? history;
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
      Map<String, int> m, bool Function(String) pred) {
    return m.entries.where((e) => pred(e.key)).toList();
  }

  String _labelFor(String key) {
    if (key.startsWith('processed.')) {
      return 'Processed (${key.substring('processed.'.length)})';
    }
    if (key.startsWith('droppedByType.')) {
      return 'Dropped (${key.substring('droppedByType.'.length)})';
    }
    const pretty = {
      'processed': 'Processed',
      'skipped': 'Skipped',
      'failures': 'Failures',
      'prefetch': 'Prefetched',
      'flushes': 'Flushes',
      'catchupBatches': 'Catch-up Batches',
      'skippedByRetryLimit': 'Skipped (Retry Cap)',
      'retriesScheduled': 'Retries Scheduled',
      'circuitOpens': 'Circuit Opens',
      'dbApplied': 'DB Applied',
      'dbIgnoredByVectorClock': 'DB Ignored (VectorClock)',
      'conflictsCreated': 'Conflicts',
      'dbMissingBase': 'DB Missing Base',
    };
    return pretty[key] ?? key;
  }

  Map<String, List<MapEntry<String, int>>> _grouped(Map<String, int> v2) {
    final throughput = _select(
        v2,
        (k) =>
            k == 'processed' ||
            k == 'prefetch' ||
            k == 'flushes' ||
            k == 'catchupBatches' ||
            k == 'retriesScheduled' ||
            k.startsWith('processed.'));
    final reliability = _select(
        v2,
        (k) =>
            k == 'failures' ||
            k == 'skipped' ||
            k == 'skippedByRetryLimit' ||
            k == 'circuitOpens' ||
            k.startsWith('droppedByType.'));
    final db = _select(
        v2,
        (k) =>
            k == 'dbApplied' ||
            k == 'dbIgnoredByVectorClock' ||
            k == 'conflictsCreated' ||
            k == 'dbMissingBase');
    return {
      'Throughput': throughput,
      'Reliability': reliability,
      'DB Apply': db,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text(
              '$lastUpdatedLabel ${_formatTime(lastUpdated)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
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
        Builder(builder: (context) {
          final kpiKeys = ['processed', 'failures', 'retriesScheduled'];
          final kpiEntries =
              metrics.entries.where((e) => kpiKeys.contains(e.key)).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (kpiEntries.isNotEmpty) const Text('Top KPIs'),
              if (kpiEntries.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: MetricsGrid(
                    entries: kpiEntries,
                    labelFor: _labelFor,
                    history: history,
                  ),
                ),
            ],
          );
        }),
        // Grouped sections
        ..._grouped(metrics).entries.expand((section) => [
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  section.key,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              MetricsGrid(
                entries: section.value,
                labelFor: _labelFor,
                history: history,
              ),
              const SizedBox(height: 12),
            ]),
        DiagnosticsPanel(fetchDiagnostics: fetchDiagnostics),
      ],
    );
  }
}
