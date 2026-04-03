import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_wake_activity_chart.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';

class RitualSummaryCard extends StatelessWidget {
  const RitualSummaryCard({
    required this.metrics,
    this.compact = false,
    super.key,
  });

  final RitualSummaryMetrics metrics;
  final bool compact;

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = compact ? tokens.spacing.step4 : tokens.spacing.step5;

    return ModernBaseCard(
      margin: EdgeInsets.only(bottom: tokens.spacing.step4),
      padding: EdgeInsets.all(spacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.messages.agentEvolutionDashboardTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: tokens.spacing.step2),
          Text(
            context.messages.agentRitualSummarySubtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
          SizedBox(height: spacing),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricTile(
                label: context.messages.agentTemplateMetricsTotalWakes,
                value: _numberFormat.format(metrics.lifetimeWakeCount),
              ),
              _MetricTile(
                label: context.messages.agentRitualSummaryWakesSinceLast,
                value: _numberFormat.format(metrics.wakesSinceLastSession),
              ),
              _MetricTile(
                label: context.messages.agentRitualSummaryTokensSinceLast,
                value: _numberFormat.format(
                  metrics.totalTokenUsageSinceLastSession,
                ),
              ),
            ],
          ),
          SizedBox(height: spacing),
          Text(
            context.messages.agentRitualSummaryWakeHistory30Days,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: tokens.spacing.step3),
          EvolutionWakeActivityChart(
            buckets: metrics.dailyWakeCounts,
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 132, maxWidth: 180),
      child: Container(
        padding: EdgeInsets.all(tokens.spacing.step4),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.45,
          ),
          borderRadius: BorderRadius.circular(tokens.radii.m),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: tokens.spacing.step2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
