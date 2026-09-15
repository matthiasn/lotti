import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_action_bar.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Standard modal action bar for a task filter overview: the shared
/// [DesignSystemFilterActionBar] bound to a [DesignSystemTaskFilterState]
/// draft, with the optional Save action between Clear and Apply.
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
    final hasFilters = state.appliedCount > 0;

    return DesignSystemFilterActionBar(
      clearKey: const ValueKey('design-system-task-filter-clear'),
      applyKey: const ValueKey('design-system-task-filter-apply'),
      clearLabel: state.clearAllLabel,
      applyLabel: state.applyLabel,
      onClearPressed: hasFilters
          ? () {
              final cleared = state.clearAll();
              onChanged(cleared);
              onClearAllPressed?.call(cleared);
            }
          : null,
      onApplyPressed: onApplyPressed == null
          ? null
          : () => onApplyPressed!(state),
      extraSecondary: [
        if (onSavePressed != null)
          DesignSystemButton(
            key: saveButtonKey,
            label: context.messages.tasksSavedFiltersSaveButtonLabel,
            variant: DesignSystemButtonVariant.secondary,
            size: DesignSystemButtonSize.large,
            leadingIcon: LottiIcons.bookmark,
            onPressed: canSave ? onSavePressed : null,
          ),
      ],
    );
  }
}
