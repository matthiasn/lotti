import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/pipeline_v2/v2_metrics.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/features/sync/ui/matrix_stats/v2_metrics_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

class IncomingStats extends ConsumerStatefulWidget {
  const IncomingStats({super.key});

  @override
  ConsumerState<IncomingStats> createState() => _IncomingStatsState();
}

class _IncomingStatsState extends ConsumerState<IncomingStats> {
  DateTime? _lastUpdated;
  Future<V2Metrics?>? _metricsFuture;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    // Initial typed metrics fetch (decoupled from messageCounts rebuilds).
    _metricsFuture = ref.read(matrixServiceProvider).getV2Metrics();
  }

  void _refreshDiagnostics() {
    setState(() {
      ref
        ..invalidate(matrixV2MetricsFutureProvider)
        ..invalidate(matrixDiagnosticsTextProvider);
      _metricsFuture = ref.read(matrixServiceProvider).getV2Metrics();
      _lastUpdated = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(matrixStatsControllerProvider);

    return stats.map(
      data: (data) {
        final value = data.value;
        return SingleChildScrollView(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.messages.settingsMatrixSentMessagesLabel} ${value.sentCount}',
              ),
              const SizedBox(height: 10),
              DataTable(
                columns: <DataColumn>[
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        context.messages.settingsMatrixMessageType,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Expanded(
                      child: Text(
                        context.messages.settingsMatrixCount,
                        style: const TextStyle(fontStyle: FontStyle.italic),
                      ),
                    ),
                  ),
                ],
                rows: <DataRow>[
                  for (final k in (value.messageCounts.keys.toList()..sort()))
                    DataRow(
                      cells: <DataCell>[
                        DataCell(Text(k)),
                        DataCell(Text(value.messageCounts[k].toString())),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 16),
              FutureBuilder<V2Metrics?>(
                future: _metricsFuture,
                builder: (context, snap) {
                  final v2 = snap.data?.toMap();
                  if (v2 == null || v2.isEmpty) {
                    return Row(
                      children: [
                        Text(
                          context.messages.settingsMatrixV2MetricsNoData,
                        ),
                        const Spacer(),
                        IconButton(
                          key: const Key('matrixStats.refresh.noData'),
                          tooltip: context.messages.settingsMatrixRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _refreshDiagnostics,
                        ),
                      ],
                    );
                  }

                  return V2MetricsSection(
                    metrics: v2,
                    lastUpdated: _lastUpdated,
                    title: context.messages.settingsMatrixV2Metrics,
                    lastUpdatedLabel:
                        context.messages.settingsMatrixLastUpdated,
                    onForceRescan: () async {
                      await ref.read(matrixServiceProvider).forceV2Rescan();
                      _refreshDiagnostics();
                    },
                    onRetryNow: () async {
                      await ref.read(matrixServiceProvider).retryV2Now();
                      _refreshDiagnostics();
                    },
                    onCopyDiagnostics: () async {
                      final svc = ref.read(matrixServiceProvider);
                      final text = await svc.getSyncDiagnosticsText();
                      if (!context.mounted) return;
                      await ClipboardHelper.copyTextWithSnackBar(
                        context,
                        text,
                        snackBar: const SnackBar(
                          content: Text('Diagnostics copied'),
                          duration: Duration(milliseconds: 800),
                        ),
                      );
                    },
                    onRefresh: _refreshDiagnostics,
                    fetchDiagnostics: () => ref
                        .read(matrixServiceProvider)
                        .getSyncDiagnosticsText(),
                  );
                },
              ),
            ],
          ),
        );
      },
      error: (error) => const Text(
        'Error loading Matrix stats',
        style: TextStyle(color: Colors.red),
      ),
      loading: (loading) => const CircularProgressIndicator(),
    );
  }
}
