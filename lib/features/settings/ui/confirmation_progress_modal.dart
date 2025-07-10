import 'package:flutter/material.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modern_modal_utils.dart';

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
    final cancelLabel = context.messages.cancelButton.toUpperCase();
    final pageIndexNotifier = ValueNotifier(0);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    var confirmed = false;

    await ModernModalUtils.showMultiPageModernModal<void>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (modalSheetContext) {
        return [
          // Confirmation Page
          ModernModalUtils.modernModalSheetPage(
            context: modalSheetContext,
            child: Padding(
              padding: const EdgeInsets.all(ModalTheme.padding),
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
                      Expanded(
                        child: SizedBox(
                          height: ModalTheme.buttonHeight,
                          child: OutlinedButton(
                            onPressed: () {
                              confirmed = false;
                              Navigator.of(modalSheetContext).pop();
                            },
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: colorScheme.onSurfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.cardBorderRadius),
                              ),
                              side: BorderSide(
                                color: colorScheme.outline
                                    .withValues(alpha: AppTheme.alphaOutline),
                                width: ModalTheme.buttonBorderWidth,
                              ),
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: ModalTheme.fontSize,
                                fontWeight: FontWeight.w600,
                                letterSpacing: ModalTheme.letterSpacing,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                cancelLabel,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingLarge + 4),
                      Expanded(
                        child: SizedBox(
                          height: ModalTheme.buttonHeight,
                          child: FilledButton(
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
                            style: FilledButton.styleFrom(
                              backgroundColor: isDestructive
                                  ? colorScheme.error
                                  : colorScheme.primary,
                              foregroundColor: isDestructive
                                  ? colorScheme.onError
                                  : colorScheme.onPrimary,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    AppTheme.cardBorderRadius),
                              ),
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: ModalTheme.fontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: ModalTheme.letterSpacingBold,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                confirmLabel.toUpperCase(),
                                textAlign: TextAlign.center,
                              ),
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
          // Progress/Completion Page
          ModernModalUtils.modernModalSheetPage(
            context: modalSheetContext,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(
                    vertical: ModalTheme.progressCardMarginV,
                    horizontal: ModalTheme.progressCardMarginH),
                padding: const EdgeInsets.symmetric(
                    vertical: ModalTheme.progressCardVertical,
                    horizontal: ModalTheme.progressCardHorizontal),
                child: DefaultTextStyle(
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: ModalTheme.fontSize,
                  ),
                  child: progressBuilder(modalSheetContext),
                ),
              ),
            ),
          ),
        ];
      },
    );

    return confirmed;
  }
}
