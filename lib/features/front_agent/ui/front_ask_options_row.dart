import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/front_agent/model/front_chat_thread.dart';
import 'package:material_ui/material_ui.dart';

/// The choices under a clarifying question, as outlined buttons — pressable
/// at a glance, and never mistaken for one of the user's own filled
/// bubbles: one tap answers in
/// the option's own words, which the next routing turn reads back as the
/// user's reply (decision 1 — nothing is filed or asked on the user's
/// behalf without the user saying so).
class FrontAskOptionsRow extends StatelessWidget {
  const FrontAskOptionsRow({
    required this.options,
    required this.onChosen,
    this.enabled = true,
    super.key,
  });

  final List<FrontAskOption> options;
  final ValueChanged<FrontAskOption> onChosen;

  /// False while a turn is in flight: a second answer would queue a second
  /// turn.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Wrap(
      spacing: tokens.spacing.step3,
      runSpacing: tokens.spacing.step3,
      children: [
        for (final option in options)
          DesignSystemButton(
            key: ValueKey(
              'front-ask-option-${option.kind.wireName}:${option.id}',
            ),
            label: option.label,
            // What the question asks for: a full-size neutral button, the
            // accent left to the composer's one action.
            variant: DesignSystemButtonVariant.outlined,
            size: DesignSystemButtonSize.medium,
            onPressed: enabled ? () => onChosen(option) : null,
          ),
      ],
    );
  }
}
