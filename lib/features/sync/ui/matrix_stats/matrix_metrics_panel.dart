import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/clipboard_helper.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_section.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';

/// Typed metrics panel responsible for polling MatrixService metrics and
/// exposing the refresh/rescan actions to the UI.
///
/// Notes:
/// - Polls every [MatrixSyncMetricsPanelState.pollInterval] (5s) when the
///   app is active; updates the "Last updated" stamp only when the metrics
///   signature changes to avoid visual jitter.
/// - Refresh/Retry/Rescan actions invalidate the providers and force a single
///   refresh cycle so users get immediate feedback.
class MatrixSyncMetricsPanel extends ConsumerStatefulWidget {
  const MatrixSyncMetricsPanel({super.key});

  @override
  MatrixSyncMetricsPanelState createState() => MatrixSyncMetricsPanelState();
}

class MatrixSyncMetricsPanelState extends ConsumerState<MatrixSyncMetricsPanel>
    with WidgetsBindingObserver {
  DateTime? _lastUpdated;
  Map<String, int>? _metricsMap;
  Timer? _pollTimer;
  bool _appActive = true;
  bool _inFlight = false;
  bool _refreshPending = false;
  bool _pendingForceTimestamp = false;
  String? _lastSignature;

  /// Cadence at which this panel polls `MatrixService.getSyncMetrics`
  /// while the panel is on-screen AND the app is foregrounded. The
  /// previous 2-second cadence drove the
  /// `SELECT … GROUP BY status, producer FROM inbound_event_queue`
  /// aggregate to 223 hits/day on the 2026-05-12 desktop slow_queries
  /// log. Those timings include executor waiting and do not isolate SQL
  /// execution or prove writer-lock contention. The 5-second interval
  /// reduces periodic probe frequency by 60%. All panel probes share
  /// `_inFlight`, including initial and manual refreshes.
  @visibleForTesting
  static const Duration pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_refreshOnce());
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(pollInterval, (_) {
      if (!_appActive || _inFlight) return;
      unawaited(_refreshOnce());
    });
  }

  /// Serializes initial, periodic, and manual probes. A manual action during
  /// a probe schedules one trailing load so its post-action state is observed.
  Future<void> _refreshOnce({bool forceTimestamp = false}) async {
    if (_inFlight) {
      _refreshPending = true;
      _pendingForceTimestamp |= forceTimestamp;
      return;
    }
    _inFlight = true;
    var forceNextTimestamp = forceTimestamp;
    try {
      do {
        _refreshPending = false;
        _pendingForceTimestamp = false;
        final m = await ref.read(matrixServiceProvider).getSyncMetrics();
        final map = m?.toMap();
        if (!mounted) return;
        if (map != null && map.isNotEmpty) {
          if (forceNextTimestamp ||
              metricsMapSignature(map) != _lastSignature) {
            _applyMetricsUpdate(map, forceTimestamp: forceNextTimestamp);
          }
        }
        forceNextTimestamp = _pendingForceTimestamp;
      } while (_refreshPending);
    } finally {
      _inFlight = false;
    }
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
    if (!mounted) return;
    ref
      ..invalidate(matrixSyncMetricsFutureProvider)
      ..invalidate(matrixDiagnosticsTextProvider);
    unawaited(_refreshOnce(forceTimestamp: forceTimestamp));
  }

  @override
  Widget build(BuildContext context) {
    final section = SyncMetricsSection(
      metrics: _metricsMap ?? const <String, int>{},
      lastUpdated: _lastUpdated,
      title: context.messages.settingsMatrixMetrics,
      lastUpdatedLabel: context.messages.settingsMatrixLastUpdated,
      onForceRescan: () async {
        await ref.read(matrixServiceProvider).forceRescan();
        _refreshDiagnostics(forceTimestamp: true);
      },
      onRetryNow: () async {
        await ref.read(matrixServiceProvider).retryNow();
        _refreshDiagnostics(forceTimestamp: true);
      },
      onCopyDiagnostics: () async {
        final svc = ref.read(matrixServiceProvider);
        final text = await svc.getSyncDiagnosticsText();
        if (!context.mounted) return;
        await ClipboardHelper.copyTextAndNotify(
          context,
          text,
          title: context.messages.settingsMatrixDiagnosticCopied,
          duration: const Duration(milliseconds: 800),
        );
      },
      onRefresh: _refreshDiagnostics,
      fetchDiagnostics: () =>
          ref.read(matrixServiceProvider).getSyncDiagnosticsText(),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final needsScroll = constraints.hasBoundedHeight;
        if (needsScroll) {
          return SingleChildScrollView(
            primary: false,
            padding: EdgeInsets.zero,
            child: section,
          );
        }
        return section;
      },
    );
  }
}
