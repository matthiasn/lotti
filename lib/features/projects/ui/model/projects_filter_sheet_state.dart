import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/projects/model/projects_overview_models.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Adapts a [ProjectsFilter] into the design-system filter-sheet model so the
/// Projects tab can reuse the shared task-filter modal.
///
/// Builds the fixed six status options (keyed by [ProjectStatusFilterIds]) and
/// one option per category, then pre-selects each field by intersecting the
/// filter's stored IDs with the options actually present — dropping any stale
/// selections for categories that no longer exist. The inverse is
/// [projectsFilterFromSheetState].
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
      id: ProjectStatusFilterIds.monitoring,
      label: context.messages.projectStatusMonitoring,
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

/// Folds the filter sheet's edited selections back onto [baseFilter],
/// overwriting only the status and category IDs.
///
/// The text query and search mode are preserved from [baseFilter] because the
/// filter sheet does not own them. Inverse of [buildProjectsFilterSheetState].
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
