import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_primary_button.dart';
import 'package:lotti/widgets/buttons/lotti_secondary_button.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class ConfirmationProgressModal {
  const ConfirmationProgressModal._();

  static Future<bool> show({
    required BuildContext context,
    required String message,
    required String confirmLabel,
    required Widget Function(BuildContext) progressBuilder,
    required Future<void> Function() operation,
    bool isDestructive = true,
  }) async {
    final pageIndexNotifier = ValueNotifier(0);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    var confirmed = false;

    await ModalUtils.showMultiPageModal<void>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (modalSheetContext) {
        return [
          // Confirmation Page
          ModalUtils.modalSheetPage(
            context: modalSheetContext,
            padding: const EdgeInsets.all(ModalTheme.padding),
            hasTopBarLayer: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isDestructive)
                  Container(
                    padding: const EdgeInsets.all(ModalTheme.iconPadding),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer
                          .withValues(alpha: AppTheme.alphaPrimary),
                      borderRadius: BorderRadius.circular(
                          AppTheme.cardBorderRadius +
                              ModalTheme.iconBorderRadiusExtra),
                      border: Border.all(
                        color: colorScheme.errorContainer
                            .withValues(alpha: AppTheme.alphaOutline),
                      ),
                    ),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: ModalTheme.iconSize,
                      color: colorScheme.error,
                    ),
                  ),
                const SizedBox(height: ModalTheme.spacing24),
                Text(
                  message,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: ModalTheme.headlineLineHeight,
                    letterSpacing: ModalTheme.headlineLetterSpacing,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: ModalTheme.spacing40),
                Row(
                  children: [
                    SizedBox(
                      height: ModalTheme.buttonHeight,
                      child: LottiSecondaryButton(
                        label: context.messages.cancelButton,
                        onPressed: () {
                          confirmed = false;
                          Navigator.of(modalSheetContext).pop();
                        },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingLarge),
                    Expanded(
                      child: SizedBox(
                        height: ModalTheme.buttonHeight,
                        child: LottiPrimaryButton(
                          onPressed: () async {
                            confirmed = true;
                            pageIndexNotifier.value = 1;
                            try {
                              await operation();
                            } catch (e, stackTrace) {
                              getIt<LoggingService>().captureException(
                                e,
                                domain: 'ConfirmationProgressModal',
                                subDomain: 'operation',
                                stackTrace: stackTrace,
                              );
                            } finally {
                              if (modalSheetContext.mounted) {
                                Navigator.of(modalSheetContext).pop();
                              }
                            }
                          },
                          label: confirmLabel.toUpperCase(),
                          icon: Icons.check_circle_rounded,
                          isDestructive: isDestructive,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Progress/Completion Page
          ModalUtils.modalSheetPage(
            context: modalSheetContext,
            hasTopBarLayer: false,
            padding: const EdgeInsets.all(ModalTheme.padding),
            child: progressBuilder(modalSheetContext),
          ),
        ];
      },
    );

    return confirmed;
  }
}
