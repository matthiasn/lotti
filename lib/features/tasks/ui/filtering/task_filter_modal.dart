import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_selection_modal.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/journal/state/journal_page_controller.dart';
import 'package:lotti/features/journal/state/journal_page_scope.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter_activator.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filters_controller.dart';
import 'package:lotti/features/tasks/ui/filtering/tasks_filter_sheet_state.dart';
import 'package:lotti/features/tasks/ui/saved_filters/saved_task_filter_toast.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/entities_cache_service.dart';

final _projectCatalogCache = Expando<Map<String, List<ProjectEntry>>>(
  'task-filter-projects',
);

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

  // Open from the last catalog snapshot immediately. A refresh starts with the
  // route and updates the shared draft in place, so a cold database never
  // makes the filter trigger appear unresponsive and later openings remain
  // stale-while-revalidate.
  var allProjectsWithCategories = _cachedProjectsForFilter(
    allCategories: categories,
  );

  final initialState = buildTasksFilterSheetState(
    context,
    controllerState: controllerState,
    categories: categories,
    labels: labels,
    projectsWithCategories: allProjectsWithCategories,
  );

  // Snapshot the saved-filter state for the Save flow.
  final savedFilters =
      container.read(savedTaskFiltersControllerProvider).value ??
      const <SavedTaskFilter>[];
  final matchedId = container.read(currentSavedTaskFilterIdProvider);
  // Resolve the active id to its saved filter. If the id no longer points at a
  // filter (concurrent delete/rename), degrade to the create flow rather than
  // updating a stale id.
  final matchedSavedFilter = matchedId == null
      ? null
      : savedFilters.where((filter) => filter.id == matchedId).firstOrNull;

  await showDesignSystemFilterModal(
    context: context,
    initialState: initialState,
    refreshInitialState: !controllerState.enableProjects
        ? null
        : (current) async {
            try {
              allProjectsWithCategories = await _refreshProjectsForFilter(
                allCategories: categories,
              );
              if (!context.mounted) return current;
              final refreshedField = buildTasksFilterSheetState(
                context,
                controllerState: controllerState,
                categories: categories,
                labels: labels,
                projectsWithCategories: allProjectsWithCategories,
              ).projectField!;
              final currentSelection =
                  current.projectField?.selectedIds ?? const <String>{};
              return _pruneProjectsForSelectedCategories(
                current.copyWith(
                  projectField: refreshedField.copyWith(
                    selectedIds: currentSelection,
                  ),
                ),
                allProjectsWithCategories,
              );
            } catch (error, stackTrace) {
              if (getIt.isRegistered<DomainLogger>()) {
                getIt<DomainLogger>().error(
                  LogDomain.tasks,
                  error,
                  stackTrace: stackTrace,
                  subDomain: 'loadFilterProjects',
                );
              }
              return current;
            }
          },
    existingSavedFilterName: showTasks ? matchedSavedFilter?.name : null,
    canCreateSavedFilter: !showTasks
        ? null
        : (draftState) => tasksFilterHasActiveClauses(
            _draftStateToTasksFilter(draftState, controllerState),
          ),
    canUpdateSavedFilter: !showTasks || matchedSavedFilter == null
        ? null
        : (draftState) => !taskFiltersHaveSameSavedShape(
            matchedSavedFilter.filter,
            _draftStateToTasksFilter(draftState, controllerState),
          ),
    onCreateSavedFilter: !showTasks
        ? null
        : (name, draftState) async {
            // The persisted filter is built from the route-scoped draft so
            // in-modal edits are captured even before Apply. The modal layer
            // applies and closes only after persistence succeeds.
            final filter = _draftStateToTasksFilter(
              draftState,
              controllerState,
            );
            final notifier = container.read(
              savedTaskFiltersControllerProvider.notifier,
            );
            try {
              final created = await notifier.create(
                name: name,
                filter: filter,
              );
              if (context.mounted) {
                showSavedTaskFilterSavedToast(context, name: created.name);
              }
            } catch (error, stackTrace) {
              if (getIt.isRegistered<DomainLogger>()) {
                getIt<DomainLogger>().error(
                  LogDomain.tasks,
                  error,
                  stackTrace: stackTrace,
                  subDomain: 'saveFilter',
                );
              }
              // Rethrow so the modal layer keeps the modal open and the
              // user can retry.
              rethrow;
            }
          },
    onUpdateSavedFilter: !showTasks || matchedSavedFilter == null
        ? null
        : (draftState) async {
            final filter = _draftStateToTasksFilter(
              draftState,
              controllerState,
            );
            try {
              await container
                  .read(savedTaskFiltersControllerProvider.notifier)
                  .updateFilter(matchedSavedFilter.id, filter);
              if (context.mounted) {
                showSavedTaskFilterUpdatedToast(
                  context,
                  name: matchedSavedFilter.name,
                );
              }
            } catch (error, stackTrace) {
              if (getIt.isRegistered<DomainLogger>()) {
                getIt<DomainLogger>().error(
                  LogDomain.tasks,
                  error,
                  stackTrace: stackTrace,
                  subDomain: 'saveFilter',
                );
              }
              rethrow;
            }
          },
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
    fieldPageConfigs: {
      DesignSystemTaskFilterSection.category: DesignSystemFilterFieldPageConfig(
        searchHintText: context.messages.categorySearchPlaceholder,
        normalizeState: (state) => _pruneProjectsForSelectedCategories(
          state,
          allProjectsWithCategories,
        ),
      ),
      DesignSystemTaskFilterSection.label: DesignSystemFilterFieldPageConfig(
        searchHintText: context.messages.tasksLabelsSheetSearchHint,
      ),
      DesignSystemTaskFilterSection.project: DesignSystemFilterFieldPageConfig(
        searchHintText: context.messages.projectShowcaseSearchHint,
        groupsBuilder: (state) => _projectGroups(
          state,
          allProjectsWithCategories: allProjectsWithCategories,
          categories: categories,
        ),
      ),
    },
  );
}

List<DesignSystemFilterSelectionGroup> _projectGroups(
  DesignSystemTaskFilterState state, {
  required List<ProjectWithCategory> allProjectsWithCategories,
  required List<CategoryDefinition> categories,
}) {
  final selectedCategoryIds = state.categoryField!.selectedIds;
  return [
    for (final category in categories)
      if (selectedCategoryIds.isEmpty ||
          selectedCategoryIds.contains(category.id))
        DesignSystemFilterSelectionGroup(
          label: category.name,
          optionIds: {
            for (final project in allProjectsWithCategories)
              if (project.categoryId == category.id) project.project.meta.id,
          },
        ),
  ];
}

DesignSystemTaskFilterState _pruneProjectsForSelectedCategories(
  DesignSystemTaskFilterState state,
  List<ProjectWithCategory> allProjectsWithCategories,
) {
  final projectField = state.projectField;
  if (projectField == null) return state;
  final selectedCategoryIds = state.categoryField!.selectedIds;
  final allowedProjectIds = {
    for (final project in allProjectsWithCategories)
      if (selectedCategoryIds.isEmpty ||
          selectedCategoryIds.contains(project.categoryId))
        project.project.meta.id,
  };
  final normalizedIds = projectField.selectedIds.intersection(
    allowedProjectIds,
  );
  if (normalizedIds.length == projectField.selectedIds.length) return state;
  return state.copyWith(
    projectField: projectField.copyWith(selectedIds: normalizedIds),
  );
}

List<ProjectWithCategory> _cachedProjectsForFilter({
  required List<CategoryDefinition> allCategories,
}) {
  final db = getIt<JournalDb>();
  final cachedByCategory = _projectCatalogCache[db];
  if (cachedByCategory == null) return const [];
  return [
    for (final category in allCategories)
      for (final project
          in cachedByCategory[category.id] ?? const <ProjectEntry>[])
        ProjectWithCategory(project: project, categoryId: category.id),
  ];
}

/// Refreshes every category while keeping the previous snapshot available to
/// the already-open modal until the complete replacement is ready.
Future<List<ProjectWithCategory>> _refreshProjectsForFilter({
  required List<CategoryDefinition> allCategories,
}) async {
  final db = getIt<JournalDb>();
  final categoryIds = allCategories
      .map((category) => category.id)
      .where((id) => id.isNotEmpty);

  final groups = await Future.wait(
    categoryIds.map(
      (categoryId) async {
        final projects = await db.getProjectsForCategory(categoryId);
        return (categoryId: categoryId, projects: projects);
      },
    ),
  );
  _projectCatalogCache[db] = {
    for (final group in groups) group.categoryId: group.projects,
  };
  return [
    for (final group in groups)
      for (final project in group.projects)
        ProjectWithCategory(project: project, categoryId: group.categoryId),
  ];
}

/// Applies the filter sheet state back to the controller in a single batch.
///
/// Selection sets are forwarded as nullable so absent sections leave their
/// underlying state unchanged — [TasksFilter]'s `Set<String>` defaults to
/// empty, which would otherwise read as "clear" in the apply path.
Future<void> _applyFilterState(
  DesignSystemTaskFilterState sheetState, {
  required JournalPageController controller,
  required JournalPageState controllerState,
}) async {
  final filter = _draftStateToTasksFilter(sheetState, controllerState);
  await controller.applyBatchFilterUpdate(
    statuses: sheetState.statusField?.selectedIds,
    categoryIds: sheetState.categoryField?.selectedIds,
    labelIds: sheetState.labelField?.selectedIds,
    projectIds: sheetState.projectField?.selectedIds,
    priorities: filter.selectedPriorities,
    sortOption: filter.sortOption,
    agentAssignmentFilter: filter.agentAssignmentFilter,
    searchMode: sheetState.hasSearchMode
        ? TasksFilterSearchModeIds.toMode(sheetState.selectedSearchModeId)
        : null,
    showCreationDate: filter.showCreationDate,
    showDueDate: filter.showDueDate,
  );
}

/// Pure conversion from the modal's draft state to a [TasksFilter] payload
/// suitable for persistence and the apply path's per-field math.
///
/// Selection sets fall back to `const {}` because [TasksFilter] is absolute
/// (a saved filter with an empty status set means "no status constraint").
/// Display toggles fall back to [controllerState] so toggles the sheet
/// doesn't expose don't reset to the [TasksFilter] default.
TasksFilter _draftStateToTasksFilter(
  DesignSystemTaskFilterState sheetState,
  JournalPageState controllerState,
) {
  final internalPriorities = <String>{
    for (final displayId in sheetState.selectedPriorityIds)
      ?TasksFilterPriorityIds.toInternalId(displayId),
  };
  final toggleMap = {
    for (final toggle in sheetState.toggles) toggle.id: toggle.value,
  };
  return TasksFilter(
    selectedTaskStatuses: sheetState.statusField?.selectedIds ?? const {},
    selectedCategoryIds: sheetState.categoryField?.selectedIds ?? const {},
    selectedLabelIds: sheetState.labelField?.selectedIds ?? const {},
    selectedProjectIds: sheetState.projectField?.selectedIds ?? const {},
    selectedPriorities: internalPriorities,
    sortOption: TasksFilterSortIds.toSortOption(sheetState.selectedSortId),
    agentAssignmentFilter: TasksFilterAgentIds.toFilter(
      sheetState.selectedAgentFilterId,
    ),
    showCreationDate:
        toggleMap[TasksFilterToggleIds.showCreationDate] ??
        controllerState.showCreationDate,
    showDueDate:
        toggleMap[TasksFilterToggleIds.showDueDate] ??
        controllerState.showDueDate,
  );
}
