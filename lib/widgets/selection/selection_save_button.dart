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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label ?? context.messages.saveButtonLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: context.colorScheme.primary,
          foregroundColor: context.colorScheme.onPrimary,
          disabledBackgroundColor:
              context.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
          disabledForegroundColor:
              context.colorScheme.onSurface.withValues(alpha: 0.4),
          elevation: onPressed != null ? 3 : 0,
          shadowColor: context.colorScheme.primary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
