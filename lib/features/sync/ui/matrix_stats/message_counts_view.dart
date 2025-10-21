import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/sync/matrix/stats.dart';
import 'package:lotti/features/sync/matrix/stats_signature.dart';
import 'package:lotti/features/sync/state/matrix_stats_provider.dart';
import 'package:lotti/features/sync/ui/matrix_stats/metrics_grid.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Sent-messages panel for Matrix Stats. Listens to the controller manually to
/// avoid page-level rebuilds while still reacting to debounced service emits.
class MessageCountsView extends ConsumerStatefulWidget {
  const MessageCountsView({super.key});

  @override
  MessageCountsViewState createState() => MessageCountsViewState();
}

class MessageCountsViewState extends ConsumerState<MessageCountsView> {
  MatrixStats? _stats;
  ProviderSubscription<AsyncValue<MatrixStats>>? _subscription;
  String? _signature;
  bool _subscriptionClosed = false;

  @visibleForTesting
  bool get subscriptionClosed => _subscriptionClosed;

  @override
  void initState() {
    super.initState();
    _subscription = ref.listenManual<AsyncValue<MatrixStats>>(
      matrixStatsControllerProvider,
      (previous, next) {
        next.whenData((value) {
          if (!mounted) return;
          final newSignature = matrixStatsSignature(value);
          if (newSignature == _signature) return; // no-op when unchanged
          setState(() {
            _stats = value;
            _signature = newSignature;
          });
        });
      },
      fireImmediately: false,
    );
    final initial = ref.read(matrixStatsControllerProvider).valueOrNull;
    _stats = initial;
    _signature = matrixStatsSignature(initial);
  }

  @override
  void dispose() {
    final subscription = _subscription;
    _subscription = null;
    subscription?.close();
    _subscriptionClosed = true;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _stats;
    if (value == null) return const SizedBox.shrink();

    final keys = value.messageCounts.keys.toList()..sort();
    final entries = [
      for (final key in keys)
        MapEntry<String, int>('sent.$key', value.messageCounts[key] ?? 0),
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
