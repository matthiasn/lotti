import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Shows a design-system confirmation modal with optional title, message, and
/// customizable action labels.
Future<bool> showConfirmationModal({
  required BuildContext context,
  required String message,
  String? title,
  String confirmLabel = 'YES, DELETE DATABASE',
  String cancelLabel = 'CANCEL',
  bool isDestructive = true,
}) async {
  bool? result;

  await ModalUtils.showSinglePageModal<void>(
    context: context,
    hasTopBarLayer: false,
    builder: (BuildContext context) {
      final theme = Theme.of(context);
      final tokens = context.designTokens;
      final spacing = tokens.spacing;

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning Icon
          if (isDestructive)
            Icon(
              Icons.warning_amber_rounded,
              size: spacing.step9,
              color: theme.colorScheme.error,
            ),
          if (isDestructive) SizedBox(height: spacing.step4),

          if (title != null) ...[
            Text(
              title,
              style: tokens.typography.styles.heading.heading3.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: spacing.step2),
          ],

          // Confirmation Text
          Text(
            message,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),

          SizedBox(height: spacing.step7),

          // Action Buttons
          DesignSystemModalActionBar(
            secondary: [
              DesignSystemButton(
                onPressed: () {
                  result = false;
                  Navigator.of(context).pop();
                },
                label: cancelLabel,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
              ),
            ],
            primary: DesignSystemButton(
              onPressed: () {
                result = true;
                Navigator.of(context).pop();
              },
              label: confirmLabel.toUpperCase(),
              variant: isDestructive
                  ? DesignSystemButtonVariant.danger
                  : DesignSystemButtonVariant.primary,
              size: DesignSystemButtonSize.large,
              fullWidth: true,
            ),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
