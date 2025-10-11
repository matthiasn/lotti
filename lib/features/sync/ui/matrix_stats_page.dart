import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

SliverWoltModalSheetPage matrixStatsPage({
  required BuildContext context,
  required ValueNotifier<int> pageIndexNotifier,
}) {
  return ModalUtils.modalSheetPage(
    context: context,
    showCloseButton: true,
    stickyActionBar: Padding(
      padding: WoltModalConfig.pagePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: LottiSecondaryButton(
              label: context.messages.settingsMatrixPreviousPage,
              onPressed: () =>
                  pageIndexNotifier.value = pageIndexNotifier.value - 1,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: LottiPrimaryButton(
              onPressed: () => Navigator.of(context).pop(),
              label: context.messages.settingsMatrixDone,
            ),
          ),
        ],
      ),
    ),
    title: context.messages.settingsMatrixStatsTitle,
    padding: WoltModalConfig.pagePadding + const EdgeInsets.only(bottom: 80),
    child: const IncomingStats(),
  );
}

class IncomingStats extends ConsumerStatefulWidget {
  const IncomingStats({super.key});

  @override
  ConsumerState<IncomingStats> createState() => _IncomingStatsState();
}

class _IncomingStatsState extends ConsumerState<IncomingStats> {
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    // Initial fetch occurs via provider; only stamp time here.
    _lastUpdated = DateTime.now();
  }

  void _refreshDiagnostics() {
    setState(() {
      // Invalidate typed diagnostics to force a refresh
      ref.invalidate(matrixV2MetricsFutureProvider);
      _lastUpdated = DateTime.now();
    });
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final t = dt.toLocal().toIso8601String();
    // Show HH:mm:ss
    return t.length >= 19 ? t.substring(11, 19) : t;
  }

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(matrixStatsControllerProvider);

    return stats.map(
      data: (data) {
        final value = data.value;

        return Column(
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
                ...value.messageCounts.keys.map(
                  (k) => DataRow(
                    cells: <DataCell>[
                      DataCell(Text(k)),
                      DataCell(Text(value.messageCounts[k].toString())),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // V2 metrics via typed provider
            ref.watch(matrixV2MetricsFutureProvider).when(
              data: (metrics) {
                final v2 = metrics?.toMap();
                if (v2 == null || v2.isEmpty) {
                  return Row(
                    children: [
                      Text(context.messages.settingsMatrixV2MetricsNoData),
                      const Spacer(),
                      IconButton(
                        key: const Key('matrixStats.refresh'),
                        tooltip: context.messages.settingsMatrixRefresh,
                        icon: const Icon(Icons.refresh_rounded),
                        onPressed: _refreshDiagnostics,
                      ),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          context.messages.settingsMatrixV2Metrics,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${context.messages.settingsMatrixLastUpdated} ${_formatTime(_lastUpdated)}',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const Spacer(),
                        IconButton(
                          key: const Key('matrixStats.refresh'),
                          tooltip: context.messages.settingsMatrixRefresh,
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: _refreshDiagnostics,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    DataTable(
                      columns: <DataColumn>[
                        DataColumn(
                          label: Expanded(
                            child: Text(
                              context.messages.settingsMatrixMetric,
                              style:
                                  const TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Expanded(
                            child: Text(
                              context.messages.settingsMatrixValue,
                              style:
                                  const TextStyle(fontStyle: FontStyle.italic),
                            ),
                          ),
                        ),
                      ],
                      rows: <DataRow>[
                        for (final entry in v2.entries)
                          DataRow(
                            cells: <DataCell>[
                              DataCell(Text(entry.key)),
                              DataCell(Text(entry.value.toString())),
                            ],
                          ),
                      ],
                    ),
                  ],
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const CircularProgressIndicator(),
            ),
          ],
        );
      },
      error: (error) => const CircularProgressIndicator(),
      loading: (loading) => const CircularProgressIndicator(),
    );
  }
}
