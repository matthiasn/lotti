import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_action_bar.dart'
    show DesignSystemTaskFilterActionBar;
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

export 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_action_bar.dart';
export 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';

part 'design_system_task_filter_sheet_widgets.dart';

/// The filter sheet content — designed to be placed inside a Wolt modal page.
///
/// This widget renders the scrollable filter sections (sort, status, priority,
/// category, label, project, agent, search mode, toggles). It does NOT include
/// the outer frame, background, drag handle, or action buttons — those are
/// provided by the Wolt modal via [DesignSystemTaskFilterActionBar].
class DesignSystemTaskFilterSheet extends StatelessWidget {
  const DesignSystemTaskFilterSheet({
    required this.state,
    required this.onChanged,
    this.onFieldPressed,
    super.key,
  });

  final DesignSystemTaskFilterState state;
  final ValueChanged<DesignSystemTaskFilterState> onChanged;
  final ValueChanged<DesignSystemTaskFilterSection>? onFieldPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final palette = DesignSystemFilterPalette.fromTokens(tokens);
    final spacing = tokens.spacing;
    final contentSections = <Widget>[
      if (state.hasSearchMode)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.searchModeLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: [
                for (final option in state.searchModeOptions)
                  DesignSystemFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-search-mode-${option.id}',
                    ),
                    label: option.label,
                    selected: option.id == state.selectedSearchModeId,
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    onTap: () => onChanged(state.selectSearchMode(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.hasSortSection)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.sortLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: [
                for (final option in state.sortOptions)
                  DesignSystemFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-sort-${option.id}',
                    ),
                    label: option.label,
                    selected: option.id == state.selectedSortId,
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    onTap: () => onChanged(state.selectSort(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.hasStatusField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-status',
          ),
          label: state.statusField!.label,
          items: state.statusField!.selectedOptions,
          section: DesignSystemTaskFilterSection.status,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.status,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.status,
              id,
            ),
          ),
        ),
      if (state.hasPrioritySection)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.priorityLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step1,
              runSpacing: spacing.step1,
              children: [
                for (final option in state.priorityOptions)
                  DesignSystemFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-priority-${option.id}',
                    ),
                    label: option.label,
                    selected:
                        option.id == DesignSystemTaskFilterState.allPriorityId
                        ? state.selectedPriorityIds.isEmpty
                        : state.selectedPriorityIds.contains(option.id),
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    leading: option.glyph != DesignSystemTaskFilterGlyph.none
                        ? _TaskFilterPriorityGlyph(
                            glyph: option.glyph,
                            palette: palette,
                          )
                        : null,
                    onTap: () => onChanged(state.togglePriority(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.hasCategoryField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-category',
          ),
          label: state.categoryField!.label,
          items: state.categoryField!.selectedOptions,
          section: DesignSystemTaskFilterSection.category,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.category,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.category,
              id,
            ),
          ),
        ),
      if (state.hasProjectField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-project',
          ),
          label: state.projectField!.label,
          items: state.projectField!.selectedOptions,
          section: DesignSystemTaskFilterSection.project,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.project,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.project,
              id,
            ),
          ),
        ),
      if (state.hasLabelField)
        _TaskFilterSelectionField(
          key: const ValueKey(
            'design-system-task-filter-field-label',
          ),
          label: state.labelField!.label,
          items: state.labelField!.selectedOptions,
          section: DesignSystemTaskFilterSection.label,
          palette: palette,
          onTap: onFieldPressed == null
              ? null
              : () => onFieldPressed!.call(
                  DesignSystemTaskFilterSection.label,
                ),
          onRemove: (id) => onChanged(
            state.removeSelection(
              DesignSystemTaskFilterSection.label,
              id,
            ),
          ),
        ),
      if (state.hasAgentFilter)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _TaskFilterSectionLabel(
              text: state.agentFilterLabel,
              color: palette.secondaryText,
              style: tokens.typography.styles.others.caption,
            ),
            SizedBox(height: spacing.step4),
            Wrap(
              spacing: spacing.step3,
              runSpacing: spacing.step3,
              children: [
                for (final option in state.agentFilterOptions)
                  DesignSystemFilterChoicePill(
                    key: ValueKey(
                      'design-system-task-filter-agent-${option.id}',
                    ),
                    label: option.label,
                    selected: option.id == state.selectedAgentFilterId,
                    palette: palette,
                    textStyle: tokens.typography.styles.subtitle.subtitle2,
                    onTap: () => onChanged(state.selectAgentFilter(option.id)),
                  ),
              ],
            ),
          ],
        ),
      if (state.toggles.isNotEmpty)
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final toggle in state.toggles)
              _TaskFilterToggleRow(
                key: ValueKey(
                  'design-system-task-filter-toggle-${toggle.id}',
                ),
                toggle: toggle,
                palette: palette,
                onChanged: () => onChanged(state.toggleValue(toggle.id)),
              ),
          ],
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (contentSections.isNotEmpty)
          for (var i = 0; i < contentSections.length; i++) ...[
            contentSections[i],
            if (i != contentSections.length - 1)
              SizedBox(height: spacing.step6),
          ],
      ],
    );
  }
}
