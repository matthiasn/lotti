import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Shows a transient confirmation that the named filter was saved.
void showSavedTaskFilterSavedToast(
  BuildContext context, {
  required String name,
}) {
  _showToast(
    context,
    context.messages.tasksSavedFilterToastSaved(name),
  );
}

/// Shows a transient confirmation that an existing saved filter was updated.
void showSavedTaskFilterUpdatedToast(
  BuildContext context, {
  required String name,
}) {
  _showToast(
    context,
    context.messages.tasksSavedFilterToastUpdated(name),
  );
}

/// Shows a transient confirmation that a saved filter was deleted.
void showSavedTaskFilterDeletedToast(BuildContext context) {
  _showToast(context, context.messages.tasksSavedFilterToastDeleted);
}

void _showToast(BuildContext context, String message) {
  final tokens = context.designTokens;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.colors.background.level02,
        content: Row(
          children: [
            Icon(
              Icons.check_rounded,
              size: 16,
              color: tokens.colors.interactive.enabled,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: tokens.typography.styles.body.bodyMedium.copyWith(
                  color: tokens.colors.text.highEmphasis,
                ),
              ),
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
            color: tokens.colors.interactive.enabled.withValues(alpha: 0.32),
          ),
        ),
        duration: const Duration(milliseconds: 2000),
      ),
    );
}
