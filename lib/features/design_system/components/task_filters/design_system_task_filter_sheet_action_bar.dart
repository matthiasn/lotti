import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_modal_action_bar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Standard modal action bar for a filter overview.
///
/// Saving is deliberately a navigation action rather than an anchored menu:
/// the owning modal routes to its token-backed save page, where creating,
/// updating, and duplicating are presented as explicit operations.
class DesignSystemTaskFilterActionBar extends StatelessWidget {
  const DesignSystemTaskFilterActionBar({
    required this.state,
    required this.onChanged,
    this.onApplyPressed,
    this.onClearAllPressed,
    this.onSavePressed,
    this.canSave = false,
    super.key,
  });

  final DesignSystemTaskFilterState state;
  final ValueChanged<DesignSystemTaskFilterState> onChanged;
  final ValueChanged<DesignSystemTaskFilterState>? onApplyPressed;
  final ValueChanged<DesignSystemTaskFilterState>? onClearAllPressed;

  /// Opens the owning modal's save flow. This never creates another popup or
  /// dialog; it moves to a page in the existing modal route.
  final VoidCallback? onSavePressed;
  final bool canSave;

  @visibleForTesting
  static const Key saveButtonKey = ValueKey(
    'design-system-task-filter-save',
  );

  @override
  Widget build(BuildContext context) {
    final spacing = context.designTokens.spacing;
    final hasFilters = state.appliedCount > 0;

    return DesignSystemModalActionBar(
      glass: true,
      layout: DesignSystemModalActionBarLayout.compactPrimary,
      padding: EdgeInsets.fromLTRB(
        spacing.step5,
        spacing.step4,
        spacing.step5,
        spacing.step5,
      ),
      secondary: [
        DesignSystemButton(
          key: const ValueKey('design-system-task-filter-clear'),
          label: state.clearAllLabel,
          variant: DesignSystemButtonVariant.secondary,
          size: DesignSystemButtonSize.large,
          onPressed: hasFilters
              ? () {
                  final cleared = state.clearAll();
                  onChanged(cleared);
                  onClearAllPressed?.call(cleared);
                }
              : null,
        ),
        if (onSavePressed != null)
          DesignSystemButton(
            key: saveButtonKey,
            label: context.messages.tasksSavedFiltersSaveButtonLabel,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
            leadingIcon: Icons.bookmark_add_outlined,
            onPressed: canSave ? onSavePressed : null,
          ),
      ],
      primary: DesignSystemButton(
        key: const ValueKey('design-system-task-filter-apply'),
        label: state.applyLabel,
        leadingIcon: Icons.check_rounded,
        size: DesignSystemButtonSize.large,
        onPressed: onApplyPressed == null ? null : () => onApplyPressed!(state),
      ),
    );
  }
}
