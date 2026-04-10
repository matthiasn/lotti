import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

DesignSystemTaskFilterState buildProjectsFilterSheetState(
  BuildContext context, {
  required ProjectsFilter filter,
  required Iterable<CategoryDefinition> categories,
}) {
  final statusOptions = [
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
  ];
  final statusOptionIds = statusOptions.map((o) => o.id).toSet();

  final categoryOptions = [
    for (final category in categories)
      DesignSystemTaskFilterOption(
        id: category.id,
        label: category.name,
      ),
  ];
  final categoryOptionIds = categoryOptions.map((o) => o.id).toSet();

  return DesignSystemTaskFilterState(
    title: context.messages.tasksFilterApplyTitle,
    clearAllLabel: context.messages.tasksFilterClearAll,
    applyLabel: context.messages.tasksLabelsSheetApply,
    statusField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(context.messages.projectsFilterStatusLabel),
      options: statusOptions,
      selectedIds: filter.selectedStatusIds.intersection(statusOptionIds),
    ),
    categoryField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(context.messages.taskCategoryLabel),
      options: categoryOptions,
      selectedIds: filter.selectedCategoryIds.intersection(categoryOptionIds),
    ),
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
