import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/model/template_performance_metrics.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_metric_tile.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/animations.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Collapsible metrics dashboard at the top of the evolution chat.
///
/// Shows a 2x2 grid of [EvolutionMetricTile] cards with key template
/// performance data. Collapses/expands with an animated chevron.
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
  bool _isExpanded = true;

  @override
  Widget build(BuildContext context) {
    final metricsAsync =
        ref.watch(templatePerformanceMetricsProvider(widget.templateId));

    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 18,
                  color: GameyColors.aiCyan.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.agentEvolutionDashboardTitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: _isExpanded ? 0.0 : -0.25,
                  duration: GameyAnimations.normal,
                  curve: GameyAnimations.smooth,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: GameyAnimations.normal,
          curve: GameyAnimations.smooth,
          child: _isExpanded
              ? metricsAsync.when(
                  data: (metrics) => _buildGrid(context, metrics),
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context,
    TemplatePerformanceMetrics metrics,
  ) {
    if (metrics.totalWakes == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(
          context.messages.agentTemplateNoMetrics,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 13,
          ),
        ),
      );
    }

    final avgDurationText = metrics.averageDuration != null
        ? '${metrics.averageDuration!.inSeconds}s'
        : 'N/A';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: EvolutionMetricTile(
                  label: context.messages.agentTemplateMetricsSuccessRate,
                  value: '${(metrics.successRate * 100).toStringAsFixed(0)}%',
                  icon: Icons.check_circle_outline_rounded,
                  accentColor: GameyColors.primaryGreen,
                  progress: metrics.successRate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EvolutionMetricTile(
                  label: context.messages.agentTemplateMetricsTotalWakes,
                  value: '${metrics.totalWakes}',
                  icon: Icons.bolt_rounded,
                  accentColor: GameyColors.primaryOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: EvolutionMetricTile(
                  label: context.messages.agentTemplateMetricsActiveInstances,
                  value: '${metrics.activeInstanceCount}',
                  icon: Icons.devices_rounded,
                  accentColor: GameyColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: EvolutionMetricTile(
                  label: context.messages.agentEvolutionMttrLabel,
                  value: avgDurationText,
                  icon: Icons.timer_outlined,
                  accentColor: GameyColors.primaryPurple,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
