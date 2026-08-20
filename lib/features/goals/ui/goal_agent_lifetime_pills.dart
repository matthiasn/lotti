import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Top-level lifetime governance for one goal agent.
///
/// These pills deliberately sit on the goal surface rather than being hidden
/// in Agent Internals: consumption and compute are user-owned lifetime facts,
/// while
/// per-wake traces remain a debugging concern.
class GoalAgentLifetimePills extends ConsumerWidget {
  const GoalAgentLifetimePills({
    required this.agentId,
    this.inline = false,
    super.key,
  });

  final String agentId;

  /// Drops the leading gap and the wrap, for hosts that place the pill on a
  /// row of their own — the read card seats it beside the freshness caption
  /// in its header, where a block-level top inset would break the baseline.
  final bool inline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref.watch(agentConsumptionTotalsProvider(agentId)).value;
    if (totals == null || totals.callCount == 0) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    final foreground = tokens.colors.text.mediumEmphasis;

    final pill = ConsumptionSummaryPill(
      totals: totals,
      foregroundColor: foreground,
      // Informative, not tappable: goal surfaces reserve the fully
      // rounded pill shape for clickable elements.
      cornerRadius: tokens.radii.smallChips,
    );
    if (inline) {
      return KeyedSubtree(
        key: const ValueKey('goal-agent-lifetime-pills'),
        child: pill,
      );
    }
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.step3),
      child: Wrap(
        key: const ValueKey('goal-agent-lifetime-pills'),
        spacing: tokens.spacing.step2,
        runSpacing: tokens.spacing.step2,
        children: [pill],
      ),
    );
  }
}
