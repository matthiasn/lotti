import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
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
    stickyActionBar: SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
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
                              Text(context
                                  .messages.settingsMatrixV2MetricsNoData),
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

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  context.messages.settingsMatrixV2Metrics,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${context.messages.settingsMatrixLastUpdated} ${_formatTime(_lastUpdated)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                                const Spacer(),
                                const Tooltip(
                                  message:
                                      'Legend:\n• processed.<type> = processed sync messages by payload type\n• droppedByType.<type> = per‑type drops after retries/older ignores\n• dbApplied = DB rows written\n• dbIgnoredByVectorClock = incoming older/same ignored by DB\n• conflictsCreated = concurrent vector clocks logged',
                                  child: Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Force rescan and catch-up now',
                                  child: IconButton(
                                    key: const Key('matrixStats.forceRescan'),
                                    icon: const Icon(Icons.sync_rounded),
                                    onPressed: () async {
                                      // Fire and forget; UI will reflect via metrics
                                      await ref
                                          .read(matrixServiceProvider)
                                          .forceV2Rescan();
                                      _refreshDiagnostics();
                                    },
                                  ),
                                ),
                                Tooltip(
                                  message: 'Copy sync diagnostics to clipboard',
                                  child: IconButton(
                                    key: const Key(
                                        'matrixStats.copyDiagnostics'),
                                    icon: const Icon(Icons.copy_all_rounded),
                                    onPressed: () async {
                                      final svc =
                                          ref.read(matrixServiceProvider);
                                      final text =
                                          await svc.getSyncDiagnosticsText();
                                      // ignore: use_build_context_synchronously
                                      await ClipboardHelper
                                          .copyTextWithSnackBar(
                                        context,
                                        text,
                                        snackBar: const SnackBar(
                                          content: Text('Diagnostics copied'),
                                          duration: Duration(milliseconds: 800),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Tooltip(
                                  message: 'Retry pending failures now',
                                  child: IconButton(
                                    key: const Key('matrixStats.retryNow'),
                                    icon: const Icon(Icons.flash_on_rounded),
                                    onPressed: () async {
                                      await ref
                                          .read(matrixServiceProvider)
                                          .retryV2Now();
                                      _refreshDiagnostics();
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  key: const Key('matrixStats.refresh.metrics'),
                                  tooltip:
                                      context.messages.settingsMatrixRefresh,
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
                                      style: const TextStyle(
                                          fontStyle: FontStyle.italic),
                                    ),
                                  ),
                                ),
                                DataColumn(
                                  label: Expanded(
                                    child: Text(
                                      context.messages.settingsMatrixValue,
                                      style: const TextStyle(
                                          fontStyle: FontStyle.italic),
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
                            const SizedBox(height: 12),
                            ExpansionTile(
                              title: const Text('Diagnostics'),
                              // Collapsed by default to avoid clutter.
                              children: [
                                FutureBuilder<String>(
                                  future: ref
                                      .read(matrixServiceProvider)
                                      .getSyncDiagnosticsText(),
                                  builder: (context, snap) {
                                    if (snap.connectionState ==
                                        ConnectionState.waiting) {
                                      return const Padding(
                                        padding: EdgeInsets.all(8),
                                        child: CircularProgressIndicator(),
                                      );
                                    }
                                    final txt = snap.data ?? '';
                                    final lines = txt
                                        .split('\n')
                                        .where((l) => l.contains('='))
                                        .toList();
                                    final diag = <String, String>{};
                                    for (final l in lines) {
                                      final i = l.indexOf('=');
                                      if (i > 0) {
                                        diag[l.substring(0, i)] =
                                            l.substring(i + 1);
                                      }
                                    }
                                    final dbMissingBase =
                                        diag['dbMissingBase'] ?? '0';
                                    final ignoredCount = int.tryParse(
                                            diag['lastIgnoredCount'] ?? '0') ??
                                        0;
                                    final prefCount = int.tryParse(
                                            diag['lastPrefetchedCount'] ??
                                                '0') ??
                                        0;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('dbMissingBase: $dbMissingBase'),
                                          const SizedBox(height: 6),
                                          if (ignoredCount > 0) ...[
                                            const Text('Last Ignored:'),
                                            for (var i = 1;
                                                i <= ignoredCount;
                                                i++)
                                              Text(
                                                  diag['lastIgnored.$i'] ?? ''),
                                            const SizedBox(height: 6),
                                          ],
                                          if (prefCount > 0) ...[
                                            const Text('Last Prefetched:'),
                                            for (var i = 1; i <= prefCount; i++)
                                              Text(diag['lastPrefetched.$i'] ??
                                                  ''),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                      loading: () => const CircularProgressIndicator(),
                      error: (err, __) => const Text(
                        'Error loading V2 metrics',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
              ],
            ));
      },
      error: (error) => const Text(
        'Error loading Matrix stats',
        style: TextStyle(color: Colors.red),
      ),
      loading: (loading) => const CircularProgressIndicator(),
    );
  }
}
