import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/features/sync/ui/matrix_stats/v2_metrics_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

/// Typed metrics panel responsible for polling MatrixService V2 metrics and
/// exposing the refresh/rescan actions to the UI.
class MatrixV2MetricsPanel extends ConsumerStatefulWidget {
  const MatrixV2MetricsPanel({super.key});

  @override
  MatrixV2MetricsPanelState createState() => MatrixV2MetricsPanelState();
}

class MatrixV2MetricsPanelState extends ConsumerState<MatrixV2MetricsPanel>
    with WidgetsBindingObserver {
  DateTime? _lastUpdated;
  Map<String, int>? _metricsMap;
  Timer? _pollTimer;
  bool _appActive = true;
  bool _inFlight = false;
  String? _lastSignature;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshOnce());
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
        if (!mounted || map == null || map.isEmpty) return;
        final signature = metricsMapSignature(map);
        if (signature != _lastSignature) {
          _applyMetricsUpdate(map);
        }
      } finally {
        _inFlight = false;
      }
    });
  }

  Future<void> _refreshOnce({bool forceTimestamp = false}) async {
    final v2 = await ref.read(matrixServiceProvider).getV2Metrics();
    final map = v2?.toMap();
    if (!mounted || map == null || map.isEmpty) return;
    _applyMetricsUpdate(map, forceTimestamp: forceTimestamp);
  }

  void _applyMetricsUpdate(
    Map<String, int> map, {
    bool forceTimestamp = false,
  }) {
    final signature = metricsMapSignature(map);
    final shouldUpdateTimestamp =
        forceTimestamp || _lastSignature == null || signature != _lastSignature;
    setState(() {
      _metricsMap = map;
      _lastSignature = signature;
      if (shouldUpdateTimestamp) {
        _lastUpdated = clock.now();
      }
    });
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

  void _refreshDiagnostics({bool forceTimestamp = false}) {
    ref
      ..invalidate(matrixV2MetricsFutureProvider)
      ..invalidate(matrixDiagnosticsTextProvider);
    unawaited(_refreshOnce(forceTimestamp: forceTimestamp));
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
        _refreshDiagnostics(forceTimestamp: true);
      },
      onRetryNow: () async {
        await ref.read(matrixServiceProvider).retryV2Now();
        _refreshDiagnostics(forceTimestamp: true);
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
