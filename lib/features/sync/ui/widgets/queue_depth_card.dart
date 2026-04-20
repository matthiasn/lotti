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

  @override
  void initState() {
    super.initState();
    _sub = widget.queue.depthChanges.listen((signal) {
      if (!mounted) return;
      setState(() => _latest = signal);
    });
    unawaited(_loadInitial());
  }

  Future<void> _loadInitial() async {
    final stats = await widget.queue.stats();
    if (!mounted) return;
    setState(() {
      _latest = QueueDepthSignal(
        total: stats.total,
        byProducer: stats.byProducer,
        oldestEnqueuedAt: stats.oldestEnqueuedAt,
      );
    });
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

    return Card(
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
