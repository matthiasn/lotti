import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// Two-page confirm-then-run modal for long-running settings actions.
///
/// Page one is a (by default destructive) confirmation prompt; on confirm
/// it advances to page two and runs the async [show] `operation`, showing
/// the caller's `progressBuilder`. Errors during the operation are logged
/// (not surfaced) and the sheet is dismissed when done. Used by maintenance
/// flows like purge / FTS5 recreate that need a progress phase after the
/// user commits.
class ConfirmationProgressModal {
  const ConfirmationProgressModal._();

  /// Shows the modal and returns `true` if the user confirmed (the
  /// operation then ran), `false` if they cancelled.
  ///
  /// [progressBuilder] renders the second page while [operation] runs.
  /// [isDestructive] styles the confirm button (danger vs. primary) and
  /// shows the warning icon. [closeOnComplete] auto-dismisses the sheet
  /// when the operation finishes. [confirmationContent] injects extra UI
  /// above the action bar; [isConfirmEnabled] / [confirmEnabledListenable]
  /// gate and reactively rebuild the confirm button.
  static Future<bool> show({
    required BuildContext context,
    required String message,
    required String confirmLabel,
    required Widget Function(BuildContext) progressBuilder,
    required Future<void> Function() operation,
    bool isDestructive = true,
    bool closeOnComplete = true,
    Widget? confirmationContent,
    bool Function()? isConfirmEnabled,
    Listenable? confirmEnabledListenable,
  }) async {
    final pageIndexNotifier = ValueNotifier(0);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    var confirmed = false;

    await ModalUtils.showMultiPageModal<void>(
      context: context,
      pageIndexNotifier: pageIndexNotifier,
      pageListBuilder: (modalSheetContext) {
        Future<void> onConfirm() async {
          confirmed = true;
          pageIndexNotifier.value = 1;
          await _executeOperation(
            modalSheetContext,
            operation,
            closeOnComplete,
          );
        }

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
                      color: colorScheme.errorContainer.withValues(
                        alpha: AppTheme.alphaPrimary,
                      ),
                      borderRadius: BorderRadius.circular(
                        AppTheme.cardBorderRadius +
                            ModalTheme.iconBorderRadiusExtra,
                      ),
                      border: Border.all(
                        color: colorScheme.errorContainer.withValues(
                          alpha: AppTheme.alphaOutline,
                        ),
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
                const SizedBox(height: ModalTheme.spacing24),
                if (confirmationContent != null) ...[
                  confirmationContent,
                  const SizedBox(height: ModalTheme.spacing24),
                ],
                const SizedBox(height: AppTheme.spacingLarge),
                DesignSystemModalActionBar(
                  // The confirm action sizes to its label rather than
                  // stretching edge to edge: a full-width filled primary reads
                  // as the loudest thing on screen even when the modal is a
                  // routine choice, and at modal width it dwarfs the Cancel
                  // beside it.
                  layout: DesignSystemModalActionBarLayout.compactPrimary,
                  secondary: [
                    DesignSystemButton(
                      label: context.messages.cancelButton,
                      variant: DesignSystemButtonVariant.secondary,
                      size: DesignSystemButtonSize.large,
                      onPressed: () {
                        confirmed = false;
                        Navigator.of(modalSheetContext).pop();
                      },
                    ),
                  ],
                  primary: confirmEnabledListenable != null
                      ? ListenableBuilder(
                          listenable: confirmEnabledListenable,
                          builder: (context, _) {
                            return _buildConfirmButton(
                              modalSheetContext,
                              isConfirmEnabled,
                              onConfirm,
                              confirmLabel,
                              isDestructive,
                            );
                          },
                        )
                      : _buildConfirmButton(
                          modalSheetContext,
                          isConfirmEnabled,
                          onConfirm,
                          confirmLabel,
                          isDestructive,
                        ),
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

  static Future<void> _executeOperation(
    BuildContext modalSheetContext,
    Future<void> Function() operation,
    bool closeOnComplete,
  ) async {
    try {
      await operation();
    } catch (e, stackTrace) {
      getIt<DomainLogger>().error(
        LogDomain.settings,
        e,
        stackTrace: stackTrace,
        subDomain: 'operation',
      );
    } finally {
      if (closeOnComplete && modalSheetContext.mounted) {
        Navigator.of(modalSheetContext).pop();
      }
    }
  }

  static DesignSystemButton _buildConfirmButton(
    BuildContext context,
    bool Function()? isConfirmEnabled,
    Future<void> Function() onConfirm,
    String confirmLabel,
    bool isDestructive,
  ) {
    final enabled = isConfirmEnabled?.call() ?? true;
    return DesignSystemButton(
      onPressed: enabled ? onConfirm : null,
      label: confirmLabel,
      leadingIcon: Icons.check_circle_rounded,
      variant: isDestructive
          ? DesignSystemButtonVariant.danger
          : DesignSystemButtonVariant.primary,
      size: DesignSystemButtonSize.large,
      // fullWidth only centres the content; the parent decides the width. In
      // the compact row the button keeps its intrinsic size, and when the bar
      // falls back to its stacked layout — narrow width or text scale > 1.3 —
      // the stretched column widens it and this keeps the icon and label
      // centred instead of pinned to the leading edge.
      fullWidth: true,
    );
  }
}
