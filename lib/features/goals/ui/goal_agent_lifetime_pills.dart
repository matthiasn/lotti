import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/logic/consumption_formatting.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Top-level lifetime governance for one goal agent.
///
/// These pills deliberately sit on the goal surface rather than being hidden
/// in Agent Internals: consumption and compute are user-owned lifetime facts,
/// while
/// per-wake traces remain a debugging concern.
class GoalAgentLifetimePills extends ConsumerWidget {
  const GoalAgentLifetimePills({required this.agentId, super.key});

  final String agentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(agentConsumptionTotalsProvider(agentId)).value;
    if (totals == null || totals.callCount == 0) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    final foreground = tokens.colors.text.mediumEmphasis;
    final duration = _formatComputeDuration(
      Duration(milliseconds: totals.durationMs),
    );

    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step3),
      child: Wrap(
        key: const ValueKey('goal-agent-lifetime-pills'),
        spacing: tokens.spacing.step2,
        runSpacing: tokens.spacing.step2,
        children: [
          ConsumptionSummaryPill(
            totals: totals,
            foregroundColor: foreground,
          ),
          Tooltip(
            message: context.messages.goalAgentLifetimeTimeTooltip(
              formatCallCount(totals.callCount),
            ),
            child: DsPill(
              variant: DsPillVariant.filled,
              bordered: true,
              label: context.messages.goalAgentLifetimeTimePill(duration),
              labelColor: foreground,
              leading: Icon(
                Icons.schedule_rounded,
                size: IconSizes.xs,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatComputeDuration(Duration duration) {
  if (duration > Duration.zero && duration.inMinutes == 0) return '<1m';
  return formatDurationSummary(duration.inSeconds);
}
