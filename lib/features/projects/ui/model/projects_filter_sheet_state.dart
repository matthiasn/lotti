import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

DesignSystemTaskFilterState buildProjectsFilterSheetState(
  BuildContext context, {
  required ProjectsFilter filter,
  required Iterable<CategoryDefinition> categories,
  bool showDragHandle = true,
}) {
  return DesignSystemTaskFilterState(
    title: context.messages.tasksFilterApplyTitle,
    clearAllLabel: context.messages.tasksFilterClearAll,
    applyLabel: context.messages.tasksLabelsSheetApply,
    statusField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(context.messages.projectsFilterStatusLabel),
      options: [
        DesignSystemTaskFilterOption(
          id: ProjectStatusFilterIds.open,
          label: context.messages.projectStatusOpen,
        ),
        DesignSystemTaskFilterOption(
          id: ProjectStatusFilterIds.active,
          label: context.messages.projectStatusActive,
        ),
        DesignSystemTaskFilterOption(
          id: ProjectStatusFilterIds.onHold,
          label: context.messages.projectStatusOnHold,
        ),
        DesignSystemTaskFilterOption(
          id: ProjectStatusFilterIds.completed,
          label: context.messages.projectStatusCompleted,
        ),
        DesignSystemTaskFilterOption(
          id: ProjectStatusFilterIds.archived,
          label: context.messages.projectStatusArchived,
        ),
      ],
      selectedIds: filter.selectedStatusIds,
    ),
    categoryField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(context.messages.taskCategoryLabel),
      options: [
        for (final category in categories)
          DesignSystemTaskFilterOption(
            id: category.id,
            label: category.name,
          ),
      ],
      selectedIds: filter.selectedCategoryIds,
    ),
    showDragHandle: showDragHandle,
  );
}

ProjectsFilter projectsFilterFromSheetState(
  DesignSystemTaskFilterState sheetState, {
  required ProjectsFilter baseFilter,
}) {
  return baseFilter.copyWith(
    selectedStatusIds: sheetState.statusField?.selectedIds ?? const <String>{},
    selectedCategoryIds:
        sheetState.categoryField?.selectedIds ?? const <String>{},
  );
}

String stripTrailingColon(String value) {
  return value.endsWith(':')
      ? value.substring(0, value.length - 1).trimRight()
      : value;
}
