import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/matrix/matrix_service.dart';
import 'package:lotti/features/sync/queue/queue_pipeline_coordinator.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/widgets/fetch_all_history_dialog.dart';
import 'package:lotti/features/sync/ui/widgets/queue_depth_card.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class BackfillSettingsPage extends ConsumerWidget {
  const BackfillSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(backfillConfigControllerProvider);
    final statsState = ref.watch(backfillStatsControllerProvider);
    final theme = Theme.of(context);
    final matrixService = getIt.isRegistered<MatrixService>()
        ? getIt<MatrixService>()
        : null;
    final coordinator = matrixService?.queueCoordinator;
    final showQueueSection =
        (matrixService?.isLegacyPipelineSuppressed ?? false) &&
        coordinator != null;

    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.backfillSettingsTitle,
        subtitle: context.messages.backfillSettingsSubtitle,
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showQueueSection) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: QueueDepthCard(queue: coordinator.queue),
              ),
              const SizedBox(height: 16),
              _CatchUpNowButton(coordinator: coordinator),
              const SizedBox(height: 8),
              _FetchAllHistoryButton(coordinator: coordinator),
              const SizedBox(height: 24),
            ],

            // Enable/Disable Toggle Card
            _BackfillToggleCard(
              isEnabled: configAsync.value ?? true,
              isLoading: configAsync.isLoading,
              onToggle: () =>
                  ref.read(backfillConfigControllerProvider.notifier).toggle(),
            ),

            const SizedBox(height: 24),

            // Stats Section
            _StatsSection(
              stats: statsState.stats,
              isLoading: statsState.isLoading,
              onRefresh: () =>
                  ref.read(backfillStatsControllerProvider.notifier).refresh(),
            ),

            const SizedBox(height: 24),

            // Manual Backfill Section
            _ManualBackfillSection(
              isProcessing: statsState.isProcessing,
              lastProcessedCount: statsState.lastProcessedCount,
              error: statsState.error,
              onTrigger: () => ref
                  .read(backfillStatsControllerProvider.notifier)
                  .triggerFullBackfill(),
            ),

            const SizedBox(height: 24),

            // Reset Unresolvable Section
            _ResetUnresolvableSection(
              isProcessing: statsState.isResetting,
              lastResetCount: statsState.lastResetCount,
              unresolvableCount: statsState.stats?.totalUnresolvable ?? 0,
              error: statsState.error,
              onTrigger: () => ref
                  .read(backfillStatsControllerProvider.notifier)
                  .resetUnresolvable(),
            ),

            const SizedBox(height: 24),

            // Re-Request Section
            _ReRequestSection(
              isProcessing: statsState.isReRequesting,
              lastReRequestedCount: statsState.lastReRequestedCount,
              requestedCount: statsState.stats?.totalRequested ?? 0,
              error: statsState.error,
              onTrigger: () => ref
                  .read(backfillStatsControllerProvider.notifier)
                  .triggerReRequest(),
            ),

            const SizedBox(height: 24),

            // Retire Stuck Now — manual trigger for
            // `retireAgedOutRequestedEntries(amnestyWindow: Duration.zero)`.
            _RetireStuckNowSection(
              isProcessing: statsState.isRetiringStuck,
              lastRetiredCount: statsState.lastRetiredStuckCount,
              openCount:
                  (statsState.stats?.totalMissing ?? 0) +
                  (statsState.stats?.totalRequested ?? 0),
              error: statsState.error,
              onTrigger: () async {
                final confirmed = await _confirmRetireStuck(
                  context,
                  openCount:
                      (statsState.stats?.totalMissing ?? 0) +
                      (statsState.stats?.totalRequested ?? 0),
                );
                if (!confirmed) return;
                await ref
                    .read(backfillStatsControllerProvider.notifier)
                    .retireStuckNow();
              },
            ),

            const SizedBox(height: 16),

            // Info text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                context.messages.backfillSettingsInfo,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatchUpNowButton extends StatefulWidget {
  const _CatchUpNowButton({required this.coordinator});

  final QueuePipelineCoordinator coordinator;

  @override
  State<_CatchUpNowButton> createState() => _CatchUpNowButtonState();
}

class _CatchUpNowButtonState extends State<_CatchUpNowButton> {
  bool _running = false;

  Future<void> _kick() async {
    if (_running) return;
    setState(() => _running = true);
    try {
      await widget.coordinator.triggerBridge();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.messages.queueCatchUpNowDone)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.messages.queueFetchAllHistoryError(error.toString()),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _running ? null : _kick,
          icon: _running
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.bolt_outlined),
          label: Text(
            _running
                ? messages.queueCatchUpNowRunning
                : messages.queueCatchUpNowButton,
          ),
        ),
      ),
    );
  }
}

class _FetchAllHistoryButton extends StatelessWidget {
  const _FetchAllHistoryButton({required this.coordinator});

  final QueuePipelineCoordinator coordinator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () async {
            await FetchAllHistoryDialog.show(context, coordinator);
          },
          icon: const Icon(Icons.download_rounded),
          label: Text(context.messages.queueFetchAllHistoryButton),
        ),
      ),
    );
  }
}

class _BackfillToggleCard extends StatelessWidget {
  const _BackfillToggleCard({
    required this.isEnabled,
    required this.isLoading,
    required this.onToggle,
  });

  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isEnabled ? Icons.sync : Icons.sync_disabled,
              color: isEnabled
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.messages.backfillToggleTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isEnabled
                        ? context.messages.backfillToggleEnabledDescription
                        : context.messages.backfillToggleDisabledDescription,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: isEnabled,
                onChanged: (_) => onToggle(),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({
    required this.stats,
    required this.isLoading,
    required this.onRefresh,
  });

  final BackfillStats? stats;
  final bool isLoading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bar_chart,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.backfillStatsTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                  onPressed: isLoading ? null : onRefresh,
                  tooltip: context.messages.backfillStatsRefresh,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (stats == null && isLoading)
              const Center(child: CircularProgressIndicator())
            else if (stats == null)
              Text(
                context.messages.backfillStatsNoData,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else ...[
              _StatRow(
                label: context.messages.backfillStatsTotalEntries,
                value: '${stats!.totalEntries}',
              ),
              _StatRow(
                label: context.messages.backfillStatsReceived,
                value: '${stats!.totalReceived}',
                color: theme.colorScheme.primary,
              ),
              _StatRow(
                label: context.messages.backfillStatsMissing,
                value: '${stats!.totalMissing}',
                color: stats!.totalMissing > 0
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
              _StatRow(
                label: context.messages.backfillStatsRequested,
                value: '${stats!.totalRequested}',
                color: stats!.totalRequested > 0
                    ? Colors.orange
                    : theme.colorScheme.onSurfaceVariant,
              ),
              _StatRow(
                label: context.messages.backfillStatsBackfilled,
                value: '${stats!.totalBackfilled}',
                color: Colors.green,
              ),
              _StatRow(
                label: context.messages.backfillStatsDeleted,
                value: '${stats!.totalDeleted}',
              ),
              _StatRow(
                label: context.messages.backfillStatsUnresolvable,
                value: '${stats!.totalUnresolvable}',
                color: stats!.totalUnresolvable > 0
                    ? theme.colorScheme.outline
                    : theme.colorScheme.onSurfaceVariant,
              ),
              if (stats!.hostStats.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  context.messages.backfillStatsHostsTitle(
                    stats!.hostStats.length,
                  ),
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualBackfillSection extends StatelessWidget {
  const _ManualBackfillSection({
    required this.isProcessing,
    required this.lastProcessedCount,
    required this.error,
    required this.onTrigger,
  });

  final bool isProcessing;
  final int? lastProcessedCount;
  final String? error;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.history,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.backfillManualTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.messages.backfillManualDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (lastProcessedCount != null && !isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.messages.backfillManualSuccess(
                        lastProcessedCount!,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing ? null : onTrigger,
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  isProcessing
                      ? context.messages.backfillManualProcessing
                      : context.messages.backfillManualTrigger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetUnresolvableSection extends StatelessWidget {
  const _ResetUnresolvableSection({
    required this.isProcessing,
    required this.lastResetCount,
    required this.unresolvableCount,
    required this.error,
    required this.onTrigger,
  });

  final bool isProcessing;
  final int? lastResetCount;
  final int unresolvableCount;
  final String? error;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.restore,
                  color: unresolvableCount > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.backfillResetUnresolvableTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.messages.backfillResetUnresolvableDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (lastResetCount != null && !isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.messages.backfillResetUnresolvableSuccess(
                        lastResetCount!,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing || unresolvableCount == 0
                    ? null
                    : onTrigger,
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.restore),
                label: Text(
                  isProcessing
                      ? context.messages.backfillResetUnresolvableProcessing
                      : context.messages.backfillResetUnresolvableTrigger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReRequestSection extends StatelessWidget {
  const _ReRequestSection({
    required this.isProcessing,
    required this.lastReRequestedCount,
    required this.requestedCount,
    required this.error,
    required this.onTrigger,
  });

  final bool isProcessing;
  final int? lastReRequestedCount;
  final int requestedCount;
  final String? error;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.replay,
                  color: requestedCount > 0
                      ? Colors.orange
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.backfillReRequestTitle,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.messages.backfillReRequestDescription,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (lastReRequestedCount != null && !isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.messages.backfillReRequestSuccess(
                        lastReRequestedCount!,
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing || requestedCount == 0
                    ? null
                    : onTrigger,
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.replay),
                label: Text(
                  isProcessing
                      ? context.messages.backfillReRequestProcessing
                      : context.messages.backfillReRequestTrigger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a confirmation dialog before manually retiring all currently-open
/// `missing`/`requested` rows. Diagnostic affordance — English-only to keep
/// translation load off sync internals.
Future<bool> _confirmRetireStuck(
  BuildContext context, {
  required int openCount,
}) async {
  final theme = Theme.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Retire stuck entries now?'),
      content: Text(
        'This marks $openCount currently-open '
        '(missing or requested) sequence-log entries as unresolvable. '
        'Use this to unblock the watermark when entries have been stuck '
        'for a while without the 7-day amnesty window having passed. '
        'Entries can still be resurrected if their payload later '
        'arrives on disk with a valid vector clock.',
        style: theme.textTheme.bodyMedium,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Retire now'),
        ),
      ],
    ),
  );
  return result ?? false;
}

class _RetireStuckNowSection extends StatelessWidget {
  const _RetireStuckNowSection({
    required this.isProcessing,
    required this.lastRetiredCount,
    required this.openCount,
    required this.error,
    required this.onTrigger,
  });

  final bool isProcessing;
  final int? lastRetiredCount;
  final int openCount;
  final String? error;
  final VoidCallback onTrigger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.block,
                  color: openCount > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Retire stuck entries',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Force every currently-open missing or requested sequence-log '
              'entry to unresolvable. Skips the 7-day amnesty window — use '
              'this only when you have identified stuck rows that are '
              'blocking the watermark and want immediate recovery.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            if (lastRetiredCount != null && !isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Retired $lastRetiredCount entries to unresolvable.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isProcessing || openCount == 0 ? null : onTrigger,
                icon: isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.block),
                label: Text(
                  isProcessing
                      ? 'Retiring…'
                      : 'Retire $openCount stuck entries',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
