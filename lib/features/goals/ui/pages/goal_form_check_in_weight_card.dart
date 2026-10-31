import 'package:lotti/features/design_system/components/cards/design_system_section_card.dart';
import 'package:lotti/features/design_system/components/toggles/design_system_toggle.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The goal form's say on whether the user's check-ins are the goal itself —
/// a journal, a reflective practice — so the coach keeps and answers what
/// they wrote rather than noting that they checked in (ADR 0151).
///
/// [value] is what the goal does now: the user's choice when they made one,
/// otherwise what the criteria imply. The whole card toggles, so the target
/// is the row rather than the switch alone.
class GoalFormCheckInWeightCard extends StatelessWidget {
  const GoalFormCheckInWeightCard({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return DesignSystemSectionCard(
      onTap: () => onChanged(!value),
      child: Row(
        children: [
          Icon(
            LottiIcons.note,
            size: IconSizes.s,
            color: tokens.colors.text.mediumEmphasis,
          ),
          SizedBox(width: tokens.spacing.step3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  messages.goalFormCheckInsAreSubstanceTitle,
                  style: tokens.typography.styles.subtitle.subtitle2,
                ),
                Text(
                  messages.goalFormCheckInsAreSubstanceSubtitle,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.mediumEmphasis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: tokens.spacing.step3),
          DesignSystemToggle(
            key: const ValueKey('goal-form-check-ins-are-substance'),
            value: value,
            onChanged: onChanged,
            semanticsLabel: messages.goalFormCheckInsAreSubstanceTitle,
          ),
        ],
      ),
    );
  }
}
