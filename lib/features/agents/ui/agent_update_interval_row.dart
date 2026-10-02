import 'package:lotti/features/agents/wake/project_update_slots.dart';
import 'package:lotti/features/design_system/components/steppers/design_system_stepper.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// How often a project agent may refresh its out-of-date summary on its own.
///
/// A change to the project only marks the summary out of date; the summary
/// is refreshed in the next update slot, on one device. This row sets the
/// slot length — a synced preference, so every device keeps the same grid —
/// and says what it means in plain terms: "Every 2 hours".
///
/// The stepper moves through [ProjectUpdateSlots.choices]: decrement means
/// more often, increment less often.
class AgentUpdateIntervalRow extends StatelessWidget {
  const AgentUpdateIntervalRow({
    required this.intervalMinutes,
    required this.onChanged,
    super.key,
  });

  /// The effective interval, one of [ProjectUpdateSlots.choices].
  final int intervalMinutes;

  /// Called with the newly chosen interval; null disables the stepper.
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final ai = tokens.colors.aiCard;
    final messages = context.messages;
    final shorter = ProjectUpdateSlots.choices.lastWhere(
      (choice) => choice < intervalMinutes,
      orElse: () => intervalMinutes,
    );
    final longer = ProjectUpdateSlots.choices.firstWhere(
      (choice) => choice > intervalMinutes,
      orElse: () => intervalMinutes,
    );
    final change = onChanged;
    final caption = tokens.typography.styles.others.caption;

    return Tooltip(
      message: messages.agentUpdateIntervalHelp,
      child: Row(
        key: const ValueKey('agentUpdateIntervalRow'),
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  messages.agentUpdateIntervalLabel,
                  style: caption.copyWith(color: ai.bodyText),
                ),
                Text(
                  messages.agentUpdateIntervalHint,
                  style: caption.copyWith(color: ai.metaText),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DesignSystemStepper(
            label: _intervalLabel(messages, intervalMinutes),
            decrementTooltip: messages.agentUpdateIntervalDecrease,
            incrementTooltip: messages.agentUpdateIntervalIncrease,
            decrementKey: const ValueKey('agentUpdateIntervalDecrease'),
            incrementKey: const ValueKey('agentUpdateIntervalIncrease'),
            onDecrement: change == null || shorter == intervalMinutes
                ? null
                : () => change(shorter),
            onIncrement: change == null || longer == intervalMinutes
                ? null
                : () => change(longer),
          ),
        ],
      ),
    );
  }
}

/// The wording of an update interval of [minutes]: "Every hour", "Every 4
/// hours", "Once a day".
String _intervalLabel(AppLocalizations messages, int minutes) =>
    minutes == Duration.minutesPerDay
    ? messages.agentUpdateIntervalDaily
    : messages.agentUpdateIntervalHours(minutes ~/ Duration.minutesPerHour);
