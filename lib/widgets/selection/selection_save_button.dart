import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Reusable save button for selection modals
///
/// Provides consistent styling and behavior for save actions
/// across different selection modal types.
class SelectionSaveButton extends StatelessWidget {
  const SelectionSaveButton({
    required this.onPressed,
    this.label,
    this.icon = Icons.check_rounded,
    super.key,
  });

  /// Callback when button is pressed (null to disable)
  final VoidCallback? onPressed;

  /// Optional custom label (defaults to localized "Save")
  final String? label;

  /// Icon to display (defaults to check mark)
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null;
    final colorScheme = context.colorScheme;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isEnabled
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          foregroundColor:
              isEnabled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 24,
              color: isEnabled
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label ?? context.messages.saveButtonLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                color: isEnabled
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
