import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/agents/state/ritual_review_providers.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_charts_section.dart';
import 'package:lotti/features/agents/ui/evolution/widgets/evolution_session_timeline.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/gamey/colors.dart';

/// Composite dashboard widget combining summary stats, charts, and the
/// session timeline for a template's evolution history.
class EvolutionHistoryDashboard extends ConsumerWidget {
  const EvolutionHistoryDashboard({
    required this.templateId,
    super.key,
  });

  final String templateId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(evolutionSessionStatsProvider(templateId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.messages.agentEvolutionHistoryTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        // Summary stats row
        statsAsync.when(
          data: (stats) => _StatsRow(stats: stats),
          loading: () => const SizedBox(height: 48),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        // Charts
        EvolutionChartsSection(templateId: templateId),
        const SizedBox(height: 16),
        // Session timeline
        Text(
          context.messages.agentRitualReviewSessionHistory,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        EvolutionSessionTimeline(templateId: templateId),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final EvolutionSessionStats stats;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return Row(
      children: [
        _StatChip(
          label: messages.agentEvolutionSessionCount,
          value: '${stats.totalSessions}',
        ),
        const SizedBox(width: 16),
        _StatChip(
          label: messages.agentEvolutionApprovalRate,
          value: '${(stats.approvalRate * 100).toStringAsFixed(0)}%',
          color: stats.approvalRate >= 0.5
              ? GameyColors.primaryGreen
              : GameyColors.primaryOrange,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
