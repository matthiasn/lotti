import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/settings/ui/pages/sliver_box_adapter_page.dart';
import 'package:lotti/features/sync/state/backfill_config_controller.dart';
import 'package:lotti/features/sync/state/backfill_stats_controller.dart';
import 'package:lotti/features/sync/tuning.dart';
import 'package:lotti/features/sync/ui/widgets/sync_feature_gate.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class BackfillSettingsPage extends ConsumerWidget {
  const BackfillSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(backfillConfigControllerProvider);
    final statsState = ref.watch(backfillStatsControllerProvider);
    final theme = Theme.of(context);

    return SyncFeatureGate(
      child: SliverBoxAdapterPage(
        title: context.messages.backfillSettingsTitle,
        subtitle: context.messages.backfillSettingsSubtitle,
        showBackButton: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enable/Disable Toggle Card
            _BackfillToggleCard(
              isEnabled: configAsync.valueOrNull ?? true,
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
                      context.messages
                          .backfillManualSuccess(lastProcessedCount!),
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
                      context.messages
                          .backfillReRequestSuccess(lastReRequestedCount!),
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
                onPressed:
                    isProcessing || requestedCount == 0 ? null : onTrigger,
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
