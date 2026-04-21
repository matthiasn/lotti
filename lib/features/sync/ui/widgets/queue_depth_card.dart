import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/sync/queue/inbound_event_queue.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Small card that surfaces the live [InboundQueue] depth signal to
/// the Sync Settings page. Subscribes to [InboundQueue.depthChanges]
/// and refreshes on every emission; falls back to an on-demand
/// [InboundQueue.stats] call for the initial paint.
///
/// Diagnostic-only. The card is visible only when Phase 2's queue
/// pipeline is the active ingestion path, so the numbers shown are
/// the ground truth for "events currently waiting to apply".
class QueueDepthCard extends StatefulWidget {
  const QueueDepthCard({required this.queue, super.key});

  final InboundQueue queue;

  @override
  State<QueueDepthCard> createState() => _QueueDepthCardState();
}

class _QueueDepthCardState extends State<QueueDepthCard> {
  StreamSubscription<QueueDepthSignal>? _sub;
  QueueDepthSignal? _latest;
  bool _liveSignalSeen = false;
  bool _retryingAll = false;

  @override
  void initState() {
    super.initState();
    _bindQueue(widget.queue);
  }

  @override
  void didUpdateWidget(QueueDepthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the parent rebuilds with a different queue (e.g. the user
    // toggled the pipeline flag, spawning a fresh coordinator) the
    // existing subscription is stale. Rebind to the new stream so the
    // card reflects the live pipeline, not the retired one.
    if (!identical(oldWidget.queue, widget.queue)) {
      _sub?.cancel();
      _latest = null;
      _liveSignalSeen = false;
      _bindQueue(widget.queue);
    }
  }

  void _bindQueue(InboundQueue queue) {
    _sub = queue.depthChanges.listen((signal) {
      if (!mounted) return;
      setState(() {
        _latest = signal;
        _liveSignalSeen = true;
      });
    });
    unawaited(_loadInitial(queue));
  }

  Future<void> _loadInitial(InboundQueue queue) async {
    try {
      final stats = await queue.stats();
      if (!mounted) return;
      // If the subscription already emitted a live signal while this
      // one-shot read was in flight, don't let the stale snapshot
      // overwrite it. Also bail if the widget rebound to a different
      // queue between the `.stats()` call and its resolution.
      if (_liveSignalSeen) return;
      if (!identical(queue, widget.queue)) return;
      setState(() {
        _latest = QueueDepthSignal(
          total: stats.total,
          byProducer: stats.byProducer,
          oldestEnqueuedAt: stats.oldestEnqueuedAt,
          abandoned: stats.abandoned,
        );
      });
    } catch (_) {
      // Silently ignore — the depth stream subscription will refresh
      // the card on the next emission. A one-shot DB error at paint
      // time should not crash the Sync Settings page.
    }
  }

  Future<void> _onRetryAllSkipped() async {
    if (_retryingAll) return;
    setState(() => _retryingAll = true);
    try {
      final resurrected = await widget.queue.resurrectAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.messages.queueSkippedRetryAllDone(resurrected),
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.messages.queueSkippedRetryAllError(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _retryingAll = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final messages = context.messages;
    final signal = _latest;
    final total = signal?.total ?? 0;
    final abandoned = signal?.abandoned ?? 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        messages.queueDepthCardTitle,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (abandoned > 0) ...[
                      _SkippedBadge(count: abandoned),
                      const SizedBox(width: 12),
                    ],
                    Text(
                      total.toString(),
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: total == 0
                            ? theme.colorScheme.onSurfaceVariant
                            : theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  signal == null
                      ? messages.queueDepthCardLoading
                      : total == 0
                      ? messages.queueDepthCardEmpty
                      : _buildBreakdown(signal, messages.queueDepthCardEmpty),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (abandoned > 0) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.report_outlined,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          messages.queueSkippedCardTitle,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    messages.queueSkippedCardBody(abandoned),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
                      onPressed: _retryingAll ? null : _onRetryAllSkipped,
                      icon: _retryingAll
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: Text(messages.queueSkippedRetryAll),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  String _buildBreakdown(QueueDepthSignal signal, String emptyFallback) {
    final parts = <String>[];
    for (final producer in InboundEventProducer.values) {
      final count = signal.byProducer[producer] ?? 0;
      if (count > 0) parts.add('${producer.name}: $count');
    }
    if (parts.isEmpty) return emptyFallback;
    return parts.join('  ·  ');
  }
}

/// Small error-tinted pill that surfaces the abandoned-row count
/// inline with the queue depth so the user notices skipped events
/// without scrolling further.
class _SkippedBadge extends StatelessWidget {
  const _SkippedBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.messages.queueSkippedBadge(count),
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}
