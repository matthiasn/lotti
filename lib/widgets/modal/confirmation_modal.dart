import 'package:flutter/material.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

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
  final isDark = theme.brightness == Brightness.dark;

  await WoltModalSheet.show<void>(
    context: context,
    modalBarrierColor: isDark
        ? context.colorScheme.surfaceContainerLow.withAlpha(128)
        : context.colorScheme.outline.withAlpha(128),
    pageListBuilder: (modalSheetContext) {
      return [
        WoltModalSheetPage(
          backgroundColor: theme.colorScheme.inversePrimary,
          hasSabGradient: false,
          navBarHeight: 35,
          isTopBarLayerAlwaysVisible: false,
          trailingNavBarWidget: IconButton(
            padding: WoltModalConfig.pagePadding,
            icon:
                Icon(Icons.close, color: theme.colorScheme.onPrimaryContainer),
            onPressed: () {
              result = false;
              Navigator.of(context).pop();
            },
          ),
          child: Padding(
            padding: WoltModalConfig.pagePadding,
            child: Column(
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
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          result = false;
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.surfaceTint,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          cancelLabel,
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onError,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          result = true;
                          Navigator.of(context).pop();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.colorScheme.error,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          confirmLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ];
    },
    modalTypeBuilder: ModalUtils.modalTypeBuilder,
  );

  return result ?? false;
}
