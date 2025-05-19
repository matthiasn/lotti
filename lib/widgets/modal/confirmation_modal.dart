import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:lotti/widgets/misc/wolt_modal_config.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

/// shows a confirmation modal with customizable message and action labels.
Future<bool> showConfirmationModal({
  required BuildContext context,
  required String message,
  String? title,
  String confirmLabel = 'YES, DELETE',
  String cancelLabel = 'CANCEL',
  bool isDestructive = true,
}) async {
  bool? result;

  await WoltModalSheet.show<void>(
    context: context,
    pageListBuilder: (modalSheetContext) {
      return [
        WoltModalSheetPage(
          backgroundColor: context.colorScheme.surfaceContainer,
          hasSabGradient: false,
          navBarHeight: 35,
          topBarTitle: title != null
              ? Text(title, style: context.textTheme.titleSmall)
              : null,
          isTopBarLayerAlwaysVisible: title != null,
          trailingNavBarWidget: IconButton(
            padding: WoltModalConfig.pagePadding,
            icon: const Icon(Icons.close),
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
                if (isDestructive)
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: context.colorScheme.error,
                  ),
                if (isDestructive) const SizedBox(height: 16),
                Text(
                  message,
                  style: context.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        result = false;
                        Navigator.of(context).pop();
                      },
                      child: Text(cancelLabel),
                    ),
                    FilledButton(
                      onPressed: () {
                        result = true;
                        Navigator.of(context).pop();
                      },
                      style: isDestructive
                          ? FilledButton.styleFrom(
                              backgroundColor: context.colorScheme.error,
                            )
                          : null,
                      child: Text(
                        confirmLabel,
                        style: isDestructive
                            ? context.textTheme.labelLarge?.copyWith(
                                color: context.colorScheme.onError,
                                fontWeight: FontWeight.bold,
                              )
                            : null,
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
    barrierDismissible: false,
  );

  return result ?? false;
}

/// shows a confirmation modal specifically for database deletion operations.
Future<bool> showDatabaseDeleteConfirmationModal({
  required BuildContext context,
  required String databaseName,
}) async {
  return showConfirmationModal(
    context: context,
    message: context.messages.maintenanceDeleteDatabaseMessage(databaseName),
    confirmLabel: context.messages.maintenanceDeleteDatabaseConfirm,
  );
}
