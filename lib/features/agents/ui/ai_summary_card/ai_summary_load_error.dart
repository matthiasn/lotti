import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The agent card's place when the task's agent could not be loaded: one
/// quiet line that says so, with a way to try again — instead of the card
/// silently vanishing as if the task had no agent at all.
class AiSummaryLoadError extends StatelessWidget {
  const AiSummaryLoadError({required this.onRetry, super.key});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final colors = tokens.colors;
    return Row(
      children: [
        Icon(
          LottiIcons.warning,
          size: IconSizes.s,
          color: colors.text.mediumEmphasis,
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            context.messages.aiSummaryLoadFailed,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: colors.text.mediumEmphasis,
            ),
          ),
        ),
        DesignSystemButton(
          label: context.messages.aiSummaryRetry,
          variant: DesignSystemButtonVariant.tertiary,
          size: DesignSystemButtonSize.dense,
          alignsLabelToTrailingEdge: true,
          onPressed: onRetry,
        ),
      ],
    );
  }
}
