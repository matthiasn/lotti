import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_project_selection_modal.dart';
import 'package:lotti/features/tasks/ui/filtering/tasks_filter_sheet_state.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';

/// Shows the task filter modal using the design system filter sheet.
///
/// The modal is presented as a dialog on desktop and as a bottom sheet
/// on mobile, using Wolt modal sheet.
Future<void> showTaskFilterModal(
  BuildContext context, {
  required bool showTasks,
}) async {
  final container = ProviderScope.containerOf(context);
  final controller = container.read(
    journalPageControllerProvider(showTasks).notifier,
  );
  final controllerState = container.read(
    journalPageControllerProvider(showTasks),
  );

  final cache = getIt<EntitiesCacheService>();
  final categories = cache.sortedCategories;
  final labels = cache.sortedLabels;

  // Prefetch projects for ALL categories so that draft category changes
  // inside the sheet can show the right projects without another fetch.
  final allProjectsWithCategories = await _fetchProjectsForFilter(
    selectedCategoryIds: const {}, // empty = all categories
    allCategories: categories,
  );

  if (!context.mounted) return;

  final initialState = buildTasksFilterSheetState(
    context,
    controllerState: controllerState,
    categories: categories,
    labels: labels,
    projectsWithCategories: allProjectsWithCategories,
  );

  await showDesignSystemFilterModal(
    context: context,
    initialState: initialState,
    onApplied: (sheetState) {
      _applyFilterState(
        sheetState,
        controller: controller,
        controllerState: controllerState,
      );
    },
    modalDecorator: (child) {
      final container = ProviderScope.containerOf(context);
      return UncontrolledProviderScope(
        container: container,
        child: ProviderScope(
          overrides: [
            journalPageScopeProvider.overrideWithValue(showTasks),
          ],
          child: child,
        ),
      );
    },
    onFieldPressed: (sheetContext, draftState, section) async {
      if (section == DesignSystemTaskFilterSection.project) {
        return _handleProjectFieldPressed(
          sheetContext,
          draftState: draftState,
          allProjectsWithCategories: allProjectsWithCategories,
          categories: categories,
        );
      }

      return showDesignSystemTaskFilterFieldSelectionModal(
        context: sheetContext,
        draftState: draftState,
        section: section,
        appearanceResolver: section == DesignSystemTaskFilterSection.status
            ? (optionId) {
                final icon = taskIconFromStatusString(optionId);
                final color = taskColorFromStatusString(
                  optionId,
                  brightness: Theme.of(sheetContext).brightness,
                );
                return DesignSystemFilterSelectionOptionAppearance(
                  icon: icon,
                  foregroundColor: color,
                );
              }
            : null,
      );
    },
  );
}

/// Handles the project field press — shows the grouped project selection modal.
Future<DesignSystemTaskFilterState?> _handleProjectFieldPressed(
  BuildContext context, {
  required DesignSystemTaskFilterState draftState,
  required List<ProjectWithCategory> allProjectsWithCategories,
  required List<CategoryDefinition> categories,
}) async {
  // Filter projects based on current category selection in the draft state
  final selectedCategoryIds =
      draftState.categoryField?.selectedIds ?? const <String>{};

  final filteredProjects = selectedCategoryIds.isEmpty
      ? allProjectsWithCategories
      : allProjectsWithCategories
            .where((p) => selectedCategoryIds.contains(p.categoryId))
            .toList();

  if (filteredProjects.isEmpty) return null;

  // Build the list of categories relevant to the filtered projects
  final relevantCategoryIds = filteredProjects.map((p) => p.categoryId).toSet();
  final relevantCategories = categories
      .where((c) => relevantCategoryIds.contains(c.id))
      .toList();

  final selectedIds = await showProjectSelectionModal(
    context: context,
    projects: filteredProjects,
    categories: relevantCategories,
    initialSelectedIds: draftState.projectField?.selectedIds ?? const {},
  );

  if (selectedIds == null) return null;

  final updatedField = draftState.projectField?.copyWith(
    selectedIds: selectedIds,
  );
  return updatedField != null
      ? draftState.copyWith(projectField: updatedField)
      : draftState;
}

/// Fetches projects for the selected categories (or all categories if none).
Future<List<ProjectWithCategory>> _fetchProjectsForFilter({
  required Set<String> selectedCategoryIds,
  required List<CategoryDefinition> allCategories,
}) async {
  final db = getIt<JournalDb>();
  final categoryIds =
      (selectedCategoryIds.isEmpty
              ? allCategories.map((c) => c.id).toSet()
              : selectedCategoryIds)
          .where((id) => id.isNotEmpty); // Skip "unassigned" category

  final groups = await Future.wait(
    categoryIds.map(
      (categoryId) async {
        final projects = await db.getProjectsForCategory(categoryId);
        return projects.map(
          (project) => ProjectWithCategory(
            project: project,
            categoryId: categoryId,
          ),
        );
      },
    ),
  );

  return groups.expand((g) => g).toList();
}

/// Applies the filter sheet state back to the controller in a single batch.
Future<void> _applyFilterState(
  DesignSystemTaskFilterState sheetState, {
  required JournalPageController controller,
  required JournalPageState controllerState,
}) async {
  // Extract priority
  final priorityDisplayId = sheetState.selectedPriorityId;
  final internalPriorityId = TasksFilterPriorityIds.toInternalId(
    priorityDisplayId,
  );

  // Extract toggles
  final toggleMap = {
    for (final toggle in sheetState.toggles) toggle.id: toggle.value,
  };

  await controller.applyBatchFilterUpdate(
    statuses: sheetState.statusField?.selectedIds,
    categoryIds: sheetState.categoryField?.selectedIds,
    labelIds: sheetState.labelField?.selectedIds,
    projectIds: sheetState.projectField?.selectedIds,
    priorities: internalPriorityId != null ? {internalPriorityId} : const {},
    sortOption: TasksFilterSortIds.toSortOption(sheetState.selectedSortId),
    agentAssignmentFilter: TasksFilterAgentIds.toFilter(
      sheetState.selectedAgentFilterId,
    ),
    searchMode: sheetState.hasSearchMode
        ? TasksFilterSearchModeIds.toMode(sheetState.selectedSearchModeId)
        : null,
    showCreationDate:
        toggleMap[TasksFilterToggleIds.showCreationDate] ??
        controllerState.showCreationDate,
    showDueDate:
        toggleMap[TasksFilterToggleIds.showDueDate] ??
        controllerState.showDueDate,
  );
}
