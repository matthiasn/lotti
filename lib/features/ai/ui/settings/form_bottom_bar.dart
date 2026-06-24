import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Sticky glass footer for the AI Settings edit forms.
///
/// Shows a status line on the left — "no changes", a fix-errors hint, or
/// nothing — and Cancel / Save buttons on the right. Save is only enabled when
/// the form is both [isDirty] and [isFormValid] (and not [isLoading]); an
/// unchanged or invalid form keeps it disabled.
class FormBottomBar extends StatelessWidget {
  const FormBottomBar({
    required this.onSave,
    required this.onCancel,
    required this.isFormValid,
    required this.isDirty,
    super.key,
    this.isLoading = false,
  });

  final VoidCallback? onSave;
  final VoidCallback onCancel;
  final bool isFormValid;
  final bool isDirty;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final showSaveButton = isDirty && isFormValid;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: context.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: GlassContainer.clearGlass(
        elevation: 0,
        height: 64,
        width: double.infinity,
        blur: 12,
        color: context.colorScheme.surface.withAlpha(128),
        borderWidth: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Row(
            children: [
              // Status indicator
              if (!isDirty) ...[
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 20,
                  color: context.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  context.messages.aiFormNoChanges,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
              ] else if (!isFormValid) ...[
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: context.colorScheme.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.messages.aiFormFixErrors,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: context.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ] else ...[
                const Spacer(),
              ],

              // Buttons
              DesignSystemButton(
                label: context.messages.aiFormCancel,
                onPressed: onCancel,
                variant: DesignSystemButtonVariant.tertiary,
                size: DesignSystemButtonSize.large,
              ),
              const SizedBox(width: 20),
              // The visible status line on the left explains a disabled Save
              // sighted, but it isn't linked to the button — mirror the reason
              // into a tooltip + semantics so it's perceivable on hover and by
              // screen readers (parity with the AppBar forms that have no
              // status line).
              Tooltip(
                message: !isDirty
                    ? context.messages.aiFormNoChanges
                    : !isFormValid
                    ? context.messages.aiFormFixErrors
                    : context.messages.saveLabel,
                child: DesignSystemButton(
                  label: context.messages.saveLabel,
                  onPressed: showSaveButton && !isLoading ? onSave : null,
                  leadingIcon: Icons.save_rounded,
                  size: DesignSystemButtonSize.large,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
