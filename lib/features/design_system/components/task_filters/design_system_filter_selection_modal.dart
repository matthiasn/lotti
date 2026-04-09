import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/checkboxes/design_system_checkbox.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
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

Future<DesignSystemTaskFilterState?>
showDesignSystemTaskFilterFieldSelectionModal({
  required BuildContext context,
  required DesignSystemTaskFilterState draftState,
  required DesignSystemTaskFilterSection section,
  required DesignSystemFilterPresentation presentation,
  DesignSystemFilterOptionAppearanceResolver? appearanceResolver,
}) async {
  final field = switch (section) {
    DesignSystemTaskFilterSection.status => draftState.statusField,
    DesignSystemTaskFilterSection.category => draftState.categoryField,
    DesignSystemTaskFilterSection.label => draftState.labelField,
  };

  if (field == null) {
    return null;
  }

  final selectedIds = await showDesignSystemFilterSelectionModal(
    context: context,
    title: field.label,
    options: field.options,
    initialSelectedIds: field.selectedIds,
    presentation: presentation,
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
  };
}

Future<Set<String>?> showDesignSystemFilterSelectionModal({
  required BuildContext context,
  required String title,
  required List<DesignSystemTaskFilterOption> options,
  required Set<String> initialSelectedIds,
  required DesignSystemFilterPresentation presentation,
  DesignSystemFilterOptionAppearanceResolver? appearanceResolver,
  String? applyLabel,
}) {
  Widget sheetBuilder(
    BuildContext innerContext,
    StateSetter setState,
    Set<String> selectedIds, {
    required bool showDragHandle,
  }) {
    return DesignSystemFilterSelectionSheet(
      title: title,
      options: options,
      selectedIds: selectedIds,
      showDragHandle: showDragHandle,
      appearanceResolver: appearanceResolver,
      applyLabel: applyLabel ?? innerContext.messages.doneButton,
      onOptionToggled: (optionId) {
        setState(() {
          if (!selectedIds.add(optionId)) {
            selectedIds.remove(optionId);
          }
        });
      },
      onApplyPressed: () => Navigator.of(innerContext).pop(selectedIds),
    );
  }

  return switch (presentation) {
    DesignSystemFilterPresentation.desktop => showDialog<Set<String>>(
      context: context,
      builder: (_) {
        final selectedIds = {...initialSelectedIds};
        return StatefulBuilder(
          builder: (dialogContext, setState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.all(24),
            child: sheetBuilder(
              dialogContext,
              setState,
              selectedIds,
              showDragHandle: false,
            ),
          ),
        );
      },
    ),
    DesignSystemFilterPresentation.mobile =>
      ModalUtils.showBottomSheet<Set<String>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          final selectedIds = {...initialSelectedIds};
          return StatefulBuilder(
            builder: (sheetContext, setState) => SafeArea(
              top: false,
              child: sheetBuilder(
                sheetContext,
                setState,
                selectedIds,
                showDragHandle: true,
              ),
            ),
          );
        },
      ),
  };
}

class DesignSystemFilterSelectionSheet extends StatelessWidget {
  const DesignSystemFilterSelectionSheet({
    required this.title,
    required this.options,
    required this.selectedIds,
    required this.showDragHandle,
    required this.onOptionToggled,
    required this.onApplyPressed,
    required this.applyLabel,
    this.appearanceResolver,
    super.key,
  });

  final String title;
  final List<DesignSystemTaskFilterOption> options;
  final Set<String> selectedIds;
  final bool showDragHandle;
  final String applyLabel;
  final ValueChanged<String> onOptionToggled;
  final VoidCallback onApplyPressed;
  final DesignSystemFilterOptionAppearanceResolver? appearanceResolver;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);

    return ClipRRect(
      borderRadius: BorderRadius.circular(
        DesignSystemFilterMetrics.frameRadius,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(color: palette.sheetBackground),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: DesignSystemFilterMetrics.frameWidth,
            maxHeight: 612,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    spacing.step5,
                    spacing.step4,
                    spacing.step5,
                    spacing.step6,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDragHandle)
                        DesignSystemFilterDragHandle(
                          color: palette.handleColor,
                        ),
                      SizedBox(height: spacing.step6),
                      Text(
                        title,
                        style: tokens.typography.styles.heading.heading2
                            .copyWith(color: palette.primaryText),
                      ),
                      SizedBox(height: spacing.step6),
                      for (var index = 0; index < options.length; index++) ...[
                        _DesignSystemFilterSelectionRow(
                          option: options[index],
                          selected: selectedIds.contains(options[index].id),
                          palette: palette,
                          appearance: appearanceResolver?.call(
                            options[index].id,
                          ),
                          onTap: () => onOptionToggled(options[index].id),
                        ),
                        if (index != options.length - 1)
                          Divider(
                            height: spacing.step6,
                            color: palette.dividerColor,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              Container(height: 1, color: palette.dividerColor),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  spacing.step5,
                  spacing.step4,
                  spacing.step5,
                  0,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: DesignSystemFilterActionButton(
                    key: const ValueKey(
                      'design-system-filter-selection-apply',
                    ),
                    label: applyLabel,
                    palette: palette,
                    highlighted: true,
                    textStyle: tokens.typography.styles.subtitle.subtitle1,
                    onTap: onApplyPressed,
                  ),
                ),
              ),
              if (showDragHandle) ...[
                SizedBox(height: spacing.step4),
                Padding(
                  padding: EdgeInsets.only(bottom: spacing.step3),
                  child: DesignSystemFilterDragHandle(
                    color: palette.handleColor,
                  ),
                ),
                // Home-indicator safe-area padding
                SizedBox(
                  height: spacing.step5 + spacing.step2 + spacing.step1 / 2,
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
