import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// shows a confirmation modal with customizable message and action labels.
Future<bool> showConfirmationModal({
  required BuildContext context,
  required String message,
  String? title,
  String confirmLabel = 'YES, DELETE DATABASE',
  String cancelLabel = 'CANCEL',
  bool isDestructive = true,
}) async {
  bool? result;
  final theme = Theme.of(context);

  await ModalUtils.showSinglePageModal<void>(
    context: context,
    hasTopBarLayer: false,
    builder: (BuildContext context) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Warning Icon
          if (isDestructive)
            Icon(
              Icons.warning_amber_rounded,
              size: 36,
              color: theme.colorScheme.error,
            ),
          const SizedBox(height: 16),

          // Confirmation Text
          Text(
            message,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 28),

          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DesignSystemButton(
                onPressed: () {
                  result = false;
                  Navigator.of(context).pop();
                },
                label: cancelLabel,
                variant: DesignSystemButtonVariant.secondary,
                size: DesignSystemButtonSize.large,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: DesignSystemButton(
                  onPressed: () {
                    result = true;
                    Navigator.of(context).pop();
                  },
                  label: confirmLabel.toUpperCase(),
                  variant: isDestructive
                      ? DesignSystemButtonVariant.danger
                      : DesignSystemButtonVariant.primary,
                  size: DesignSystemButtonSize.large,
                ),
              ),
            ],
          ),
        ],
      );
    },
  );

  return result ?? false;
}
