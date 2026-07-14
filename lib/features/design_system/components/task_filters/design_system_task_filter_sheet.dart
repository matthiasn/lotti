import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_grouped_list.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/settings/settings_switch_row.dart';

export 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_action_bar.dart';
export 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet_state.dart';

part 'design_system_task_filter_sheet_widgets.dart';

/// Filter overview content for the root page of a multi-page Wolt flow.
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
    final spacing = tokens.spacing;
    final fieldRows = <Widget>[
      for (final section in DesignSystemTaskFilterSection.values)
        if (state.fieldFor(section) case final field?)
          _TaskFilterNavigationField(
            key: ValueKey(
              'design-system-task-filter-field-${section.name}',
            ),
            field: field,
            onTap: onFieldPressed == null
                ? null
                : () => onFieldPressed!(section),
          ),
    ];

    final sections = <Widget>[
      if (state.hasSearchMode)
        _TaskFilterChoiceSection(
          label: state.searchModeLabel,
          children: [
            for (final option in state.searchModeOptions)
              DesignSystemFilterChoicePill(
                key: ValueKey(
                  'design-system-task-filter-search-mode-${option.id}',
                ),
                label: option.label,
                selected: option.id == state.selectedSearchModeId,
                role: DesignSystemFilterChoiceRole.singleSelect,
                onTap: () => onChanged(state.selectSearchMode(option.id)),
              ),
          ],
        ),
      if (state.hasSortSection)
        _TaskFilterChoiceSection(
          label: state.sortLabel,
          children: [
            for (final option in state.sortOptions)
              DesignSystemFilterChoicePill(
                key: ValueKey(
                  'design-system-task-filter-sort-${option.id}',
                ),
                label: option.label,
                selected: option.id == state.selectedSortId,
                role: DesignSystemFilterChoiceRole.singleSelect,
                onTap: () => onChanged(state.selectSort(option.id)),
              ),
          ],
        ),
      if (fieldRows.isNotEmpty)
        DesignSystemGroupedList(
          padding: EdgeInsets.zero,
          filled: false,
          children: fieldRows,
        ),
      if (state.hasPrioritySection)
        _TaskFilterChoiceSection(
          label: state.priorityLabel,
          compact: true,
          children: [
            for (final option in state.priorityOptions)
              DesignSystemFilterChoicePill(
                key: ValueKey(
                  'design-system-task-filter-priority-${option.id}',
                ),
                label: option.label,
                selected: option.id == DesignSystemTaskFilterState.allPriorityId
                    ? state.selectedPriorityIds.isEmpty
                    : state.selectedPriorityIds.contains(option.id),
                role: DesignSystemFilterChoiceRole.multiSelect,
                leading: option.glyph == DesignSystemTaskFilterGlyph.none
                    ? null
                    : _TaskFilterPriorityGlyph(glyph: option.glyph),
                onTap: () => onChanged(state.togglePriority(option.id)),
              ),
          ],
        ),
      if (state.hasAgentFilter)
        _TaskFilterChoiceSection(
          label: state.agentFilterLabel,
          children: [
            for (final option in state.agentFilterOptions)
              DesignSystemFilterChoicePill(
                key: ValueKey(
                  'design-system-task-filter-agent-${option.id}',
                ),
                label: option.label,
                selected: option.id == state.selectedAgentFilterId,
                role: DesignSystemFilterChoiceRole.singleSelect,
                onTap: () => onChanged(state.selectAgentFilter(option.id)),
              ),
          ],
        ),
      if (state.toggles.isNotEmpty)
        _TaskFilterToggleGroup(
          label: context.messages.journalFilterShowTitle,
          toggles: state.toggles,
          onChanged: (id) => onChanged(state.toggleValue(id)),
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < sections.length; index++) ...[
          sections[index],
          if (index != sections.length - 1) SizedBox(height: spacing.step6),
        ],
      ],
    );
  }
}
