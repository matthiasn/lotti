import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_grid.dart';
import 'package:lotti/features/sync/ui/matrix_stats/v2_metrics_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

class IncomingStats extends ConsumerStatefulWidget {
  const IncomingStats({super.key});

  @override
  ConsumerState<IncomingStats> createState() => _IncomingStatsState();
}

class _IncomingStatsState extends ConsumerState<IncomingStats> {
  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      key: PageStorageKey('matrixStatsScroll'),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(child: _MessageCountsView()),
          SizedBox(height: 16),
          RepaintBoundary(child: _V2MetricsPanel()),
        ],
      ),
    );
  }
}

class _V2MetricsPanel extends ConsumerStatefulWidget {
  const _V2MetricsPanel();

  @override
  ConsumerState<_V2MetricsPanel> createState() => _V2MetricsPanelState();
}

class _V2MetricsPanelState extends ConsumerState<_V2MetricsPanel>
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
    _refreshOnce();
    _startPolling();
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
        if (map != null && map.isNotEmpty && sig != _lastSig) {
          if (!mounted) return;
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

  void _refreshOnce() {
    unawaited(() async {
      final v2 = await ref.read(matrixServiceProvider).getV2Metrics();
      final map = v2?.toMap();
      if (!mounted || map == null || map.isEmpty) return;
      setState(() {
        _metricsMap = map;
        _lastSig = _signature(map);
      });
    }());
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

  void _refreshDiagnostics() {
    ref
      ..invalidate(matrixV2MetricsFutureProvider)
      ..invalidate(matrixDiagnosticsTextProvider);
    _refreshOnce();
    setState(() {
      _lastUpdated = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return V2MetricsSection(
      metrics: _metricsMap ?? const <String, int>{},
      lastUpdated: _lastUpdated,
      title: context.messages.settingsMatrixV2Metrics,
      lastUpdatedLabel: context.messages.settingsMatrixLastUpdated,
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
      fetchDiagnostics: () =>
          ref.read(matrixServiceProvider).getSyncDiagnosticsText(),
    );
  }
}

class _MessageCountsView extends ConsumerStatefulWidget {
  const _MessageCountsView();

  @override
  ConsumerState<_MessageCountsView> createState() => _MessageCountsViewState();
}

class _MessageCountsViewState extends ConsumerState<_MessageCountsView> {
  MatrixStats? _stats;
  ProviderSubscription<AsyncValue<MatrixStats>>? _sub;
  String? _sig;

  @override
  void initState() {
    super.initState();
    // Use manual listen in initState; regular ref.listen is only allowed in build.
    _sub = ref.listenManual<AsyncValue<MatrixStats>>(
      matrixStatsControllerProvider,
      (prev, next) {
        next.whenData((value) {
          if (!mounted) return;
          final newSig = _signature(value);
          if (newSig == _sig) return; // no-op if unchanged
          setState(() {
            _stats = value;
            _sig = newSig;
          });
        });
      },
      fireImmediately: false,
    );
    final initial = ref.read(matrixStatsControllerProvider).valueOrNull;
    _stats = initial;
    _sig = _signature(initial);
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _stats;
    if (value == null) return const SizedBox.shrink();
    final keys = value.messageCounts.keys.toList()..sort();
    final entries = [
      for (final k in keys) MapEntry('sent.$k', value.messageCounts[k] ?? 0),
    ];
    String labelFor(String key) {
      if (key.startsWith('sent.')) {
        return 'Sent (${key.substring(5)})';
      }
      return key;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${context.messages.settingsMatrixSentMessagesLabel} ${value.sentCount}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        MetricsGrid(entries: entries, labelFor: labelFor),
      ],
    );
  }
}

String? _signature(MatrixStats? stats) {
  if (stats == null) return null;
  final keys = stats.messageCounts.keys.toList()..sort();
  final b = StringBuffer()
    ..write('sent=')
    ..write(stats.sentCount)
    ..write(';');
  for (final k in keys) {
    b
      ..write(k)
      ..write('=')
      ..write(stats.messageCounts[k] ?? 0)
      ..write(';');
  }
  return b.toString();
}
