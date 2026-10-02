import 'package:lotti/features/agents/wake/wake_budget.dart';
import 'package:lotti/features/design_system/components/steppers/design_system_stepper.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The agent's daily wake limit, and how much of it today has used.
///
/// The limit is a synced preference: whatever device changes it, every device
/// enforces it, and the usage counts wakes from all of them. The row says so
/// in plain terms — "3 of 10 used today" — and, once the limit is reached,
/// that automatic updates are paused until tomorrow, so a refused update is
/// never a silent one.
///
/// The stepper moves through [WakeBudget.choices]; a stored value between two
/// choices (another build's) steps to the nearest one on either side.
class AgentWakeBudgetRow extends StatelessWidget {
  const AgentWakeBudgetRow({
    required this.used,
    required this.maxPerDay,
    required this.onChanged,
    super.key,
  });

  /// Wakes counted today across every device.
  final int used;

  /// The effective daily limit.
  final int maxPerDay;

  /// Called with the newly chosen limit; null disables the stepper.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final exhausted = used >= maxPerDay;
    final lower = WakeBudget.choices.lastWhere(
      (choice) => choice < maxPerDay,
      orElse: () => maxPerDay,
    );
    final higher = WakeBudget.choices.firstWhere(
      (choice) => choice > maxPerDay,
      orElse: () => maxPerDay,
    );
    final change = onChanged;
    final caption = tokens.typography.styles.others.caption;

    return Tooltip(
      message: messages.agentWakeBudgetHelp,
      child: Row(
        key: const ValueKey('agentWakeBudgetRow'),
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.agentWakeBudgetLabel,
                  style: caption.copyWith(color: ai.bodyText),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (exhausted) ...[
                      Icon(
                        LottiIcons.warning,
                        key: const ValueKey('agentWakeBudgetExhaustedGlyph'),
                        size: tokens.spacing.step5,
                        color: tokens.colors.alert.warning.defaultColor,
                      ),
                      SizedBox(width: tokens.spacing.step2),
                    ],
                    Flexible(
                      child: Text(
                        exhausted
                            ? messages.agentWakeBudgetExhausted
                            : messages.agentWakeBudgetUsage(used, maxPerDay),
                        key: const ValueKey('agentWakeBudgetUsage'),
                        style: caption.copyWith(color: ai.metaText),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DesignSystemStepper(
            label: messages.agentWakeBudgetValue(maxPerDay),
            decrementTooltip: messages.agentWakeBudgetDecrease,
            incrementTooltip: messages.agentWakeBudgetIncrease,
            decrementKey: const ValueKey('agentWakeBudgetDecrease'),
            incrementKey: const ValueKey('agentWakeBudgetIncrease'),
            onDecrement: change == null || lower == maxPerDay
                ? null
                : () => change(lower),
            onIncrement: change == null || higher == maxPerDay
                ? null
                : () => change(higher),
          ),
        ],
      ),
    );
  }
}
