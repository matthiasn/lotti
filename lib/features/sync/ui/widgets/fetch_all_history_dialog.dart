import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/sync/matrix/pipeline/catch_up_strategy.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Drives the Phase-2 "Fetch all history" flow: invokes
/// [QueuePipelineCoordinator.collectHistory] with a cancellation
/// [Completer], refreshes the UI on every page emitted by
/// [BootstrapSink.onPage], and reports the final [BootstrapResult]
/// once pagination completes.
class FetchAllHistoryDialog extends StatefulWidget {
  const FetchAllHistoryDialog({required this.coordinator, super.key});

  final QueuePipelineCoordinator coordinator;

  static Future<BootstrapResult?> show(
    BuildContext context,
    QueuePipelineCoordinator coordinator,
  ) => showDialog<BootstrapResult?>(
    context: context,
    barrierDismissible: false,
    builder: (context) => FetchAllHistoryDialog(coordinator: coordinator),
  );

  @override
  State<FetchAllHistoryDialog> createState() => _FetchAllHistoryDialogState();
}

class _FetchAllHistoryDialogState extends State<FetchAllHistoryDialog> {
  final Completer<void> _cancelCompleter = Completer<void>();
  BootstrapPageInfo? _latest;
  BootstrapResult? _result;
  Object? _error;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final result = await widget.coordinator.collectHistory(
        onProgress: (info) {
          if (!mounted) return;
          setState(() => _latest = info);
        },
        cancelSignal: _cancelCompleter.future,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _running = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _running = false;
      });
    }
  }

  @override
  void dispose() {
    if (!_cancelCompleter.isCompleted) {
      _cancelCompleter.complete();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = context.messages;

    final status = switch (_result?.stopReason) {
      BootstrapStopReason.serverExhausted ||
      // "Fetch all history" never supplies untilTimestamp, so
      // boundaryReached cannot occur here; treat it the same as a
      // completed server-exhausted walk in case the constant moves.
      BootstrapStopReason.boundaryReached => messages.queueFetchAllHistoryDone(
        _result?.totalEvents ?? 0,
        _result?.totalPages ?? 0,
      ),
      BootstrapStopReason.sinkCancelled =>
        messages.queueFetchAllHistoryCancelled(_result?.totalEvents ?? 0),
      BootstrapStopReason.error =>
        _error != null
            ? messages.queueFetchAllHistoryError(_error!.toString())
            : messages.queueFetchAllHistoryErrorUnknown,
      null =>
        _error != null
            ? messages.queueFetchAllHistoryError(_error!.toString())
            : _latest != null
            ? messages.queueFetchAllHistoryProgress(
                _latest!.totalEventsSoFar,
                _latest!.pageIndex + 1,
              )
            : messages.queueDepthCardLoading,
    };

    return AlertDialog(
      title: Text(messages.queueFetchAllHistoryTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            messages.queueFetchAllHistoryDescription,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (_running) const LinearProgressIndicator(),
          if (_running) const SizedBox(height: 12),
          Text(status, style: theme.textTheme.bodyMedium),
        ],
      ),
      actions: [
        if (_running)
          TextButton(
            onPressed: () {
              if (!_cancelCompleter.isCompleted) {
                _cancelCompleter.complete();
              }
            },
            child: Text(messages.queueFetchAllHistoryCancel),
          )
        else
          TextButton(
            onPressed: () => Navigator.of(context).pop(_result),
            child: Text(messages.queueFetchAllHistoryClose),
          ),
      ],
    );
  }
}
