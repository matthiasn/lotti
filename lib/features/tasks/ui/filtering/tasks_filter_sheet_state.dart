import 'package:flutter/material.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/filtering/task_project_selection_modal.dart';
import 'package:lotti/features/tasks/ui/utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/utils/color.dart';

/// Toggle IDs used by the tasks filter sheet.
abstract final class TasksFilterToggleIds {
  static const showCreationDate = 'showCreationDate';
  static const showDueDate = 'showDueDate';
}

/// Sort option IDs used by the tasks filter sheet.
abstract final class TasksFilterSortIds {
  static const byDueDate = 'byDueDate';
  static const byDate = 'byDate';
  static const byPriority = 'byPriority';

  static String fromSortOption(TaskSortOption option) => switch (option) {
    TaskSortOption.byDueDate => byDueDate,
    TaskSortOption.byDate => byDate,
    TaskSortOption.byPriority => byPriority,
  };

  static TaskSortOption toSortOption(String id) => switch (id) {
    byDueDate => TaskSortOption.byDueDate,
    byDate => TaskSortOption.byDate,
    byPriority => TaskSortOption.byPriority,
    _ => TaskSortOption.byPriority,
  };
}

/// Agent filter option IDs.
abstract final class TasksFilterAgentIds {
  static const all = 'all';
  static const hasAgent = 'hasAgent';
  static const noAgent = 'noAgent';

  static String fromFilter(AgentAssignmentFilter filter) => switch (filter) {
    AgentAssignmentFilter.all => all,
    AgentAssignmentFilter.hasAgent => hasAgent,
    AgentAssignmentFilter.noAgent => noAgent,
  };

  static AgentAssignmentFilter toFilter(String id) => switch (id) {
    hasAgent => AgentAssignmentFilter.hasAgent,
    noAgent => AgentAssignmentFilter.noAgent,
    _ => AgentAssignmentFilter.all,
  };
}

/// Search mode option IDs.
abstract final class TasksFilterSearchModeIds {
  static const fullText = 'fullText';
  static const vector = 'vector';

  static String fromMode(SearchMode mode) => switch (mode) {
    SearchMode.fullText => fullText,
    SearchMode.vector => vector,
  };

  static SearchMode toMode(String id) => switch (id) {
    vector => SearchMode.vector,
    _ => SearchMode.fullText,
  };
}

/// Priority option IDs that map to the internal set-based filter.
abstract final class TasksFilterPriorityIds {
  static const p0 = 'p0';
  static const p1 = 'p1';
  static const p2 = 'p2';
  static const p3 = 'p3';

  /// Maps an internal priority string to a display priority ID.
  static String? toDisplayId(String internalId) => switch (internalId) {
    'CRITICAL' => p0,
    'HIGH' => p1,
    'MEDIUM' => p2,
    'LOW' => p3,
    _ => null,
  };

  /// Maps a display priority ID to the internal priority string.
  static String? toInternalId(String displayId) => switch (displayId) {
    p0 => 'CRITICAL',
    p1 => 'HIGH',
    p2 => 'MEDIUM',
    p3 => 'LOW',
    _ => null,
  };
}

/// Builds a [DesignSystemTaskFilterState] from the current controller state.
///
/// This is a pure function that maps runtime filter state to the generic
/// design system filter state used by the filter sheet widget.
DesignSystemTaskFilterState buildTasksFilterSheetState(
  BuildContext context, {
  required JournalPageState controllerState,
  required List<CategoryDefinition> categories,
  required List<LabelDefinition> labels,
  required List<ProjectWithCategory> projectsWithCategories,
}) {
  final messages = context.messages;
  final isDesktop = isDesktopLayout(context);

  // Sort options
  final sortOptions = [
    DesignSystemTaskFilterOption(
      id: TasksFilterSortIds.byDueDate,
      label: messages.tasksSortByDueDate,
    ),
    DesignSystemTaskFilterOption(
      id: TasksFilterSortIds.byDate,
      label: messages.tasksSortByCreationDate,
    ),
    DesignSystemTaskFilterOption(
      id: TasksFilterSortIds.byPriority,
      label: messages.tasksSortByPriority,
    ),
  ];

  final brightness = Theme.of(context).brightness;

  // Status options — include status icon and color for selected chips
  final statusOptions = [
    for (final status in allTaskStatuses)
      DesignSystemTaskFilterOption(
        id: status,
        label: taskLabelFromStatusString(status, context),
        icon: taskIconFromStatusString(status),
        iconColor: taskColorFromStatusString(
          status,
          brightness: brightness,
        ),
      ),
  ];

  // Priority options
  final priorityOptions = [
    const DesignSystemTaskFilterOption(
      id: 'p0',
      label: 'P0',
      glyph: DesignSystemTaskFilterGlyph.priorityP0,
    ),
    const DesignSystemTaskFilterOption(
      id: 'p1',
      label: 'P1',
      glyph: DesignSystemTaskFilterGlyph.priorityP1,
    ),
    const DesignSystemTaskFilterOption(
      id: 'p2',
      label: 'P2',
      glyph: DesignSystemTaskFilterGlyph.priorityP2,
    ),
    const DesignSystemTaskFilterOption(
      id: 'p3',
      label: 'P3',
      glyph: DesignSystemTaskFilterGlyph.priorityP3,
    ),
    DesignSystemTaskFilterOption(
      id: DesignSystemTaskFilterState.allPriorityId,
      label: messages.tasksPriorityFilterAll,
    ),
  ];

  // Map internal priority set to single display ID
  final selectedPriorityId = _prioritySetToDisplayId(
    controllerState.selectedPriorities,
  );

  // Category options — include category icon and color
  final categoryOptions = [
    for (final category in categories)
      DesignSystemTaskFilterOption(
        id: category.id,
        label: category.name,
        icon: category.icon?.iconData,
        iconColor: colorFromCssHex(category.color),
      ),
  ];

  // Label options — include label color as dot indicator
  final labelOptions = [
    for (final label in labels)
      DesignSystemTaskFilterOption(
        id: label.id,
        label: label.name,
        iconColor: colorFromCssHex(label.color),
      ),
  ];

  // Project options — grouped by category (only when projects feature enabled)
  final projectField = controllerState.enableProjects
      ? _buildProjectField(
          context,
          projectsWithCategories: projectsWithCategories,
          categories: categories,
          selectedProjectIds: controllerState.selectedProjectIds,
        )
      : null;

  // Agent filter
  final agentFilterOptions = [
    DesignSystemTaskFilterOption(
      id: TasksFilterAgentIds.all,
      label: messages.tasksAgentFilterAll,
    ),
    DesignSystemTaskFilterOption(
      id: TasksFilterAgentIds.hasAgent,
      label: messages.tasksAgentFilterHasAgent,
    ),
    DesignSystemTaskFilterOption(
      id: TasksFilterAgentIds.noAgent,
      label: messages.tasksAgentFilterNoAgent,
    ),
  ];

  // Search mode — only on desktop when vector search is enabled
  final showSearchMode = isDesktop && controllerState.enableVectorSearch;
  final searchModeOptions = showSearchMode
      ? [
          DesignSystemTaskFilterOption(
            id: TasksFilterSearchModeIds.fullText,
            label: messages.searchModeFullText,
          ),
          DesignSystemTaskFilterOption(
            id: TasksFilterSearchModeIds.vector,
            label: messages.searchModeVector,
          ),
        ]
      : <DesignSystemTaskFilterOption>[];

  // Display toggles
  final toggles = [
    DesignSystemTaskFilterToggle(
      id: TasksFilterToggleIds.showCreationDate,
      label: messages.tasksShowCreationDate,
      value: controllerState.showCreationDate,
    ),
    DesignSystemTaskFilterToggle(
      id: TasksFilterToggleIds.showDueDate,
      label: messages.tasksShowDueDate,
      value: controllerState.showDueDate,
    ),
  ];

  return DesignSystemTaskFilterState(
    title: messages.tasksFilterApplyTitle,
    clearAllLabel: messages.tasksFilterClearAll,
    applyLabel: messages.tasksLabelsSheetApply,
    sortLabel: messages.tasksSortByLabel,
    sortOptions: sortOptions,
    selectedSortId: TasksFilterSortIds.fromSortOption(
      controllerState.sortOption,
    ),
    statusField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(messages.taskStatusLabel),
      options: statusOptions,
      selectedIds: controllerState.selectedTaskStatuses,
    ),
    priorityLabel: messages.tasksPriorityFilterTitle,
    priorityOptions: priorityOptions,
    selectedPriorityId: selectedPriorityId,
    categoryField: DesignSystemTaskFilterFieldState(
      label: stripTrailingColon(messages.taskCategoryLabel),
      options: categoryOptions,
      selectedIds: controllerState.selectedCategoryIds,
    ),
    labelField: DesignSystemTaskFilterFieldState(
      label: messages.tasksLabelFilterTitle,
      options: labelOptions,
      selectedIds: controllerState.selectedLabelIds,
    ),
    projectField: projectField,
    agentFilterLabel: messages.tasksAgentFilterTitle,
    agentFilterOptions: agentFilterOptions,
    selectedAgentFilterId: TasksFilterAgentIds.fromFilter(
      controllerState.agentAssignmentFilter,
    ),
    searchModeLabel: messages.tasksSearchModeLabel,
    searchModeOptions: searchModeOptions,
    selectedSearchModeId: TasksFilterSearchModeIds.fromMode(
      controllerState.searchMode,
    ),
    toggles: toggles,
  );
}

/// Builds the project field with options grouped by category.
///
/// Each option label is prefixed with its category name for clarity
/// when multiple categories are selected. Options are ordered by
/// category, then by project title within each category.
DesignSystemTaskFilterFieldState? _buildProjectField(
  BuildContext context, {
  required List<ProjectWithCategory> projectsWithCategories,
  required List<CategoryDefinition> categories,
  required Set<String> selectedProjectIds,
}) {
  if (projectsWithCategories.isEmpty) return null;

  final categoryById = {
    for (final cat in categories) cat.id: cat,
  };

  // Build options preserving the order provided (already grouped by category).
  final options = <DesignSystemTaskFilterOption>[];
  for (final pwc in projectsWithCategories) {
    final category = categoryById[pwc.categoryId];
    final prefix = category != null ? '${category.name} / ' : '';
    options.add(
      DesignSystemTaskFilterOption(
        id: pwc.project.meta.id,
        label: '$prefix${pwc.project.data.title}',
      ),
    );
  }

  return DesignSystemTaskFilterFieldState(
    label: stripTrailingColon(context.messages.projectFilterLabel),
    options: options,
    selectedIds: selectedProjectIds,
  );
}

/// Converts the set-based internal priority selection to a single display ID.
///
/// The design system filter uses single-select priority (pill UI), while the
/// controller uses a set. If exactly one priority is selected, we map it;
/// otherwise we treat it as "All".
String _prioritySetToDisplayId(Set<String> priorities) {
  if (priorities.isEmpty) return DesignSystemTaskFilterState.allPriorityId;
  if (priorities.length == 1) {
    return TasksFilterPriorityIds.toDisplayId(priorities.first) ??
        DesignSystemTaskFilterState.allPriorityId;
  }
  return DesignSystemTaskFilterState.allPriorityId;
}
