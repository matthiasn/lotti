import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lotti/features/agents/model/ritual_summary.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_wake_activity_chart.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_base_card.dart';
import 'package:lotti/widgets/cards/modern_icon_container.dart';

/// Collapsible ritual summary shown at the top of the one-on-one chat.
class EvolutionDashboardHeader extends ConsumerStatefulWidget {
  const EvolutionDashboardHeader({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  ConsumerState<EvolutionDashboardHeader> createState() =>
      _EvolutionDashboardHeaderState();
}

class _EvolutionDashboardHeaderState
    extends ConsumerState<EvolutionDashboardHeader> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final metricsAsync = ref.watch(
      ritualSummaryMetricsProvider(widget.templateId),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: metricsAsync.when(
        data: (metrics) => ModernBaseCard(
          onTap: () => setState(() => _expanded = !_expanded),
          padding: const EdgeInsets.all(14),
          backgroundColor: context.colorScheme.surfaceContainerLow,
          borderColor: context.colorScheme.outlineVariant.withValues(
            alpha: 0.35,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderRow(
                expanded: _expanded,
                metrics: metrics,
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: _ExpandedContent(metrics: metrics),
                ),
                crossFadeState: _expanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: AppTheme.collapseAnimationDuration,
                sizeCurve: AppTheme.animationCurve,
              ),
            ],
          ),
        ),
        loading: () => const SizedBox.shrink(),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.expanded,
    required this.metrics,
  });

  final bool expanded;
  final RitualSummaryMetrics metrics;

  static final NumberFormat _numberFormat = NumberFormat.compact();

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w800,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ModernIconContainer(
          icon: Icons.insights_rounded,
          isCompact: true,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.messages.agentEvolutionDashboardTitle,
                      style: titleStyle,
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: AppTheme.chevronRotationDuration,
                    curve: AppTheme.animationCurve,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              if (expanded) ...[
                const SizedBox(height: 4),
                Text(
                  context.messages.agentRitualSummarySubtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _InlineStat(
                      label: context.messages.agentRitualSummaryWakesSinceLast,
                      value: _numberFormat.format(
                        metrics.wakesSinceLastSession,
                      ),
                    ),
                    _InlineStat(
                      label: context.messages.agentRitualSummaryTokensSinceLast,
                      value: _numberFormat.format(
                        metrics.totalTokenUsageSinceLastSession,
                      ),
                    ),
                  ],
                ),
              ] else ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CompactInlineStat(
                      label: context.messages.agentRitualSummaryWakesSinceLast,
                      value: _numberFormat.format(
                        metrics.wakesSinceLastSession,
                      ),
                    ),
                    _CompactInlineStat(
                      label: context.messages.agentRitualSummaryTokensSinceLast,
                      value: _numberFormat.format(
                        metrics.totalTokenUsageSinceLastSession,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _CompactInlineStat extends StatelessWidget {
  const _CompactInlineStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.28,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  const _InlineStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.42,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpandedContent extends StatelessWidget {
  const _ExpandedContent({
    required this.metrics,
  });

  final RitualSummaryMetrics metrics;

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(
          height: 1,
          color: context.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _DetailTile(
              label: context.messages.agentTemplateMetricsTotalWakes,
              value: _numberFormat.format(metrics.lifetimeWakeCount),
            ),
            _DetailTile(
              label: context.messages.agentRitualSummaryWakesSinceLast,
              value: _numberFormat.format(metrics.wakesSinceLastSession),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          context.messages.agentRitualSummaryWakeHistory30Days,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
          decoration: BoxDecoration(
            color: context.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.26,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: context.colorScheme.outlineVariant.withValues(alpha: 0.18),
            ),
          ),
          child: EvolutionWakeActivityChart(
            buckets: metrics.dailyWakeCounts,
          ),
        ),
      ],
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 180),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.38,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
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
