import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai_consumption/state/consumption_providers.dart';
import 'package:lotti/features/ai_consumption/ui/widgets/consumption_summary_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:material_ui/material_ui.dart';

/// What one of her turns cost, as the quiet line under her words —
/// `9.8K tokens`: the routing calls of that wake,
/// never the owners' answers, which are theirs and show on their own agents
/// (decision 8 made her model cheap; this is where the user sees that it
/// was).
///
/// Nothing is shown until the totals are known, and nothing when the wake
/// recorded no call — a turn answered from the cache of a failed run, or a
/// recovery wake that only walked doors.
class FrontTurnCostLine extends ConsumerWidget {
  const FrontTurnCostLine({required this.runKey, super.key});

  final String runKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totals = ref
        .watch(
          agentRunConsumptionTotalsProvider((
            agentId: frontAgentId,
            runKey: runKey,
          )),
        )
        .value;
    if (totals == null || totals.callCount == 0) return const SizedBox.shrink();
    final tokens = context.designTokens;
    return Tooltip(
      message: consumptionSummaryTooltip(context, totals),
      child: Text(
        consumptionSummaryLabel(context, totals),
        key: ValueKey('front-turn-cost-$runKey'),
        style: tokens.typography.styles.others.caption.copyWith(
          color: tokens.colors.text.lowEmphasis,
        ),
      ),
    );
  }
}
