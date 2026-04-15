import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

typedef DesignSystemFilterOptionAppearanceResolver =
    DesignSystemFilterSelectionOptionAppearance? Function(String optionId);

@immutable
class DesignSystemFilterSelectionOptionAppearance {
  const DesignSystemFilterSelectionOptionAppearance({
    this.icon,
    this.foregroundColor,
    this.enabled = true,
  });

  final IconData? icon;
  final Color? foregroundColor;
  final bool enabled;
}

/// Shows a multi-select field selection modal for a task filter section.
///
/// Uses Wolt modal sheet — adapts between bottom sheet (mobile) and dialog
/// (desktop) automatically via [ModalUtils.modalTypeBuilder].
Future<DesignSystemTaskFilterState?>
showDesignSystemTaskFilterFieldSelectionModal({
  required BuildContext context,
  required DesignSystemTaskFilterState draftState,
  required DesignSystemTaskFilterSection section,
  DesignSystemFilterOptionAppearanceResolver? appearanceResolver,
}) async {
  final field = switch (section) {
    DesignSystemTaskFilterSection.status => draftState.statusField,
    DesignSystemTaskFilterSection.category => draftState.categoryField,
    DesignSystemTaskFilterSection.label => draftState.labelField,
    DesignSystemTaskFilterSection.project => draftState.projectField,
  };

  if (field == null) {
    return null;
  }

  final selectedIds = await showDesignSystemFilterSelectionModal(
    context: context,
    title: field.label,
    options: field.options,
    initialSelectedIds: field.selectedIds,
    appearanceResolver: appearanceResolver,
  );

  if (selectedIds == null) {
    return null;
  }

  final updatedField = field.copyWith(selectedIds: selectedIds);
  return switch (section) {
    DesignSystemTaskFilterSection.status => draftState.copyWith(
      statusField: updatedField,
    ),
    DesignSystemTaskFilterSection.category => draftState.copyWith(
      categoryField: updatedField,
    ),
    DesignSystemTaskFilterSection.label => draftState.copyWith(
      labelField: updatedField,
    ),
    DesignSystemTaskFilterSection.project => draftState.copyWith(
      projectField: updatedField,
    ),
  };
}

/// Shows a generic multi-select filter selection modal.
///
/// Uses Wolt modal sheet — adapts between bottom sheet (mobile) and dialog
/// (desktop) automatically. The Done button is rendered as a sticky action bar
/// that remains visible while the options list scrolls.
Future<Set<String>?> showDesignSystemFilterSelectionModal({
  required BuildContext context,
  required String title,
  required List<DesignSystemTaskFilterOption> options,
  required Set<String> initialSelectedIds,
  DesignSystemFilterOptionAppearanceResolver? appearanceResolver,
  String? applyLabel,
}) async {
  final selectedIdsNotifier = ValueNotifier({...initialSelectedIds});
  final resolvedLabel = applyLabel ?? context.messages.doneButton;

  try {
    return await ModalUtils.showSinglePageModal<Set<String>>(
      context: context,
      title: title,
      padding: const EdgeInsets.only(left: 20, top: 8, right: 20, bottom: 20),
      stickyActionBarBuilder: (_) {
        return Builder(
          builder: (ctx) {
            final tokens = ctx.designTokens;
            final palette = DesignSystemFilterPalette.fromTokens(tokens);
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spacing.step5,
                vertical: tokens.spacing.step4,
              ),
              child: SizedBox(
                width: double.infinity,
                child: DesignSystemFilterActionButton(
                  key: const ValueKey(
                    'design-system-filter-selection-apply',
                  ),
                  label: resolvedLabel,
                  palette: palette,
                  highlighted: true,
                  textStyle: tokens.typography.styles.subtitle.subtitle1,
                  onTap: () => Navigator.of(ctx).pop(
                    selectedIdsNotifier.value,
                  ),
                ),
              ),
            );
          },
        );
      },
      builder: (modalContext) {
        return ValueListenableBuilder<Set<String>>(
          valueListenable: selectedIdsNotifier,
          builder: (ctx, selectedIds, _) {
            final tokens = ctx.designTokens;
            final spacing = tokens.spacing;
            final palette = DesignSystemFilterPalette.fromTokens(tokens);

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  _DesignSystemFilterSelectionRow(
                    option: options[index],
                    selected: selectedIds.contains(options[index].id),
                    palette: palette,
                    appearance: appearanceResolver?.call(options[index].id),
                    onTap: () {
                      final next = {...selectedIds};
                      if (!next.add(options[index].id)) {
                        next.remove(options[index].id);
                      }
                      selectedIdsNotifier.value = next;
                    },
                  ),
                  if (index != options.length - 1)
                    Divider(
                      height: spacing.step6,
                      color: palette.dividerColor,
                    ),
                ],
                SizedBox(height: spacing.step10),
              ],
            );
          },
        );
      },
    );
  } finally {
    selectedIdsNotifier.dispose();
  }
}

class _DesignSystemFilterSelectionRow extends StatelessWidget {
  const _DesignSystemFilterSelectionRow({
    required this.option,
    required this.selected,
    required this.palette,
    required this.onTap,
    this.appearance,
  });

  final DesignSystemTaskFilterOption option;
  final bool selected;
  final DesignSystemFilterPalette palette;
  final VoidCallback onTap;
  final DesignSystemFilterSelectionOptionAppearance? appearance;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final enabled = appearance?.enabled ?? true;
    final foregroundColor = enabled
        ? appearance?.foregroundColor ?? palette.primaryText
        : palette.secondaryText.withValues(alpha: 0.5);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('design-system-filter-selection-option-${option.id}'),
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.step1,
            vertical: spacing.step4,
          ),
          child: Row(
            children: [
              if (appearance?.icon case final icon?) ...[
                Icon(
                  icon,
                  color: foregroundColor,
                  size: 28,
                ),
                SizedBox(width: spacing.step4),
              ],
              Expanded(
                child: Text(
                  option.label,
                  style: tokens.typography.styles.subtitle.subtitle1.copyWith(
                    color: foregroundColor,
                  ),
                ),
              ),
              DesignSystemCheckbox(
                value: selected,
                onChanged: enabled ? (_) => onTap() : null,
                semanticsLabel: option.label,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
