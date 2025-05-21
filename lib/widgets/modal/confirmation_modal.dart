import 'package:flutter/material.dart';
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

  await WoltModalSheet.show<void>(
    context: context,
    pageListBuilder: (modalSheetContext) {
      return [
        WoltModalSheetPage(
          backgroundColor: const Color(0xFF544F72),
          // Fun dark purple background
          hasSabGradient: false,
          navBarHeight: 35,
          isTopBarLayerAlwaysVisible: false,
          trailingNavBarWidget: IconButton(
            padding: WoltModalConfig.pagePadding,
            icon: const Icon(Icons.close, color: Colors.white),
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
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 36,
                    color: Color(0xFFFF6B6B), // Soft alert red
                  ),
                const SizedBox(height: 16),

                // Confirmation Text
                Text(
                  message,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white,
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
                          backgroundColor: const Color(0xFF7B9EC6),
                          // Muted blue
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          cancelLabel,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
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
                          backgroundColor: const Color(0xFFE57373),
                          // Playful red
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: Text(
                          confirmLabel.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
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
    barrierDismissible: true,
  );

  return result ?? false;
}
