import 'package:flutter/material.dart';
import 'package:glass_kit/glass_kit.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/lotti_primary_button.dart';
import 'package:lotti/widgets/lotti_tertiary_button.dart';

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
              LottiTertiaryButton(
                label: context.messages.aiFormCancel,
                onPressed: onCancel,
              ),
              const SizedBox(width: 20),
              LottiPrimaryButton(
                label: context.messages.saveLabel,
                onPressed: showSaveButton && !isLoading ? onSave : null,
                icon: Icons.save_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
