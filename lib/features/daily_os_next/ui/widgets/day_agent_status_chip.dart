import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_persona_provider.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Day-header badge surfacing the day agent's observable state (ADR 0032
/// phase 4): working / attention / day-closed, with the per-day token spend
/// in the tooltip when the day has its own agent. Renders nothing while the
/// agent is idle — silence means fine. Tapping routes to the agent's
/// internals (same destination as the "Inspect agent" menu entry).
class DayAgentStatusChip extends ConsumerWidget {
  /// Creates the status chip for [date].
  const DayAgentStatusChip({
    required this.date,
    required this.onInspectAgent,
    super.key,
  });

  /// The day whose agent state is surfaced.
  final DateTime date;

  /// Opens the day agent's internals page.
  final VoidCallback onInspectAgent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final persona =
        ref.watch(dayAgentPersonaStateProvider(date)).value ??
        DayAgentPersonaState.idle;
    if (persona == DayAgentPersonaState.idle) {
      return const SizedBox.shrink();
    }
    final tokens = context.designTokens;
    final messages = context.messages;
    final (color, icon, label) = switch (persona) {
      DayAgentPersonaState.working => (
        tokens.colors.alert.info.defaultColor,
        Icons.autorenew_rounded,
        messages.dailyOsNextDayAgentStatusWorking,
      ),
      DayAgentPersonaState.attention => (
        tokens.colors.alert.warning.defaultColor,
        Icons.priority_high_rounded,
        messages.dailyOsNextDayAgentStatusAttention,
      ),
      // idle returned above, so the remaining case is celebrating.
      _ => (
        tokens.colors.alert.success.defaultColor,
        Icons.celebration_outlined,
        messages.dailyOsNextDayAgentStatusDayClosed,
      ),
    };
    final tokenSpend = ref.watch(dayAgentTokenSpendProvider(date)).value;
    final tooltip = tokenSpend == null
        ? label
        : '$label — '
              '${messages.dailyOsNextDayAgentTokensToday(tokenSpend)}';
    return Padding(
      padding: EdgeInsets.only(right: tokens.spacing.step2),
      child: Tooltip(
        message: tooltip,
        child: DsPill(
          variant: DsPillVariant.tinted,
          color: color,
          label: label,
          leading: Icon(
            icon,
            size: tokens.typography.size.caption,
            color: color,
          ),
          onTap: onInspectAgent,
        ),
      ),
    );
  }
}
