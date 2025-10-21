import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class _IncomingStatsState extends ConsumerState<IncomingStats>
    with WidgetsBindingObserver {
  DateTime? _lastUpdated;
  Map<String, int>? _metricsMap;
  Timer? _pollTimer;
  bool _appActive = true;
  bool _inFlight = false;
  String? _lastSig;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastUpdated = DateTime.now();
    // Initial typed metrics fetch (decoupled from messageCounts rebuilds).
    // Initial metrics fetch
    unawaited(() async {
      final v2 = await ref.read(matrixServiceProvider).getV2Metrics();
      if (!mounted) return;
      setState(() {
        _metricsMap = v2?.toMap();
        _lastSig = _signature(_metricsMap);
      });
    }());
    _startPolling();
  }

  void _refreshDiagnostics() {
    setState(() {
      ref
        ..invalidate(matrixV2MetricsFutureProvider)
        ..invalidate(matrixDiagnosticsTextProvider);
      _lastUpdated = DateTime.now();
    });
    unawaited(() async {
      final v2 = await ref.read(matrixServiceProvider).getV2Metrics();
      if (!mounted) return;
      setState(() {
        _metricsMap = v2?.toMap();
        _lastSig = _signature(_metricsMap);
        _lastUpdated = DateTime.now();
      });
    }());
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!_appActive || _inFlight) return;
      _inFlight = true;
      try {
        final v2 = await ref.read(matrixServiceProvider).getV2Metrics();
        final map = v2?.toMap();
        final sig = _signature(map);
        if (sig != _lastSig) {
          setState(() {
            _metricsMap = map;
            _lastSig = sig;
            _lastUpdated = DateTime.now();
          });
        }
      } finally {
        _inFlight = false;
      }
    });
  }

  String? _signature(Map<String, int>? m) {
    if (m == null || m.isEmpty) return null;
    final keys = m.keys.toList()..sort();
    final b = StringBuffer();
    for (final k in keys) {
      b
        ..write(k)
        ..write('=')
        ..write(m[k])
        ..write(';');
    }
    return b.toString();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActive = state == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MessageCountsView(),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 120),
            child: (_metricsMap == null || _metricsMap!.isEmpty)
                ? Row(
                    key: const ValueKey('v2.noData'),
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
                  )
                : V2MetricsSection(
                    key: const ValueKey('v2.section'),
                    metrics: _metricsMap!,
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
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageCountsView extends ConsumerWidget {
  const _MessageCountsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(matrixStatsControllerProvider);
    return stats.map(
      data: (data) {
        final value = data.value;
        final keys = value.messageCounts.keys.toList()..sort();
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
                  label: Text(
                    context.messages.settingsMatrixMessageType,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
                DataColumn(
                  label: Text(
                    context.messages.settingsMatrixCount,
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                ),
              ],
              rows: <DataRow>[
                for (final k in keys)
                  DataRow(
                    cells: <DataCell>[
                      DataCell(Text(k)),
                      DataCell(Text(value.messageCounts[k].toString())),
                    ],
                  ),
              ],
            ),
          ],
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
