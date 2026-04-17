import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/chips/design_system_chip.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/journal_page_state.dart';
import 'package:lotti/features/tasks/ui/model/task_browse_models.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
import 'package:lotti/features/tasks/ui/widgets/task_browse_list_item.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_palette.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_shared_widgets.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

class TaskListPane extends StatelessWidget {
  const TaskListPane({
    required this.state,
    required this.onTaskSelected,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onFilterPressed,
    super.key,
  });

  final TaskListDetailState state;
  final ValueChanged<String> onTaskSelected;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: TaskShowcasePalette.page(context),
      ),
      child: Column(
        children: [
          _TaskListSearchHeader(
            query: state.searchQuery,
            onSearchChanged: onSearchChanged,
            onSearchCleared: onSearchCleared,
            onFilterPressed: onFilterPressed,
          ),
          if (state.filterState.appliedCount > 0)
            TaskListActiveFilters(
              state: state,
              onFilterPressed: onFilterPressed,
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              child: state.visibleSections.isEmpty
                  ? TaskShowcaseEmptyResults(
                      message: context.messages.taskShowcaseNoResults,
                    )
                  : TaskListSectionsList(
                      sections: state.visibleSections,
                      sortOption: taskSortOptionFromSelectedSortId(
                        state.filterState.selectedSortId,
                      ),
                      selectedTaskId: state.selectedTask?.task.meta.id,
                      onTaskSelected: onTaskSelected,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class TaskListSectionsList extends StatefulWidget {
  const TaskListSectionsList({
    required this.sections,
    required this.sortOption,
    required this.selectedTaskId,
    required this.onTaskSelected,
    this.bottomPadding = 120,
    super.key,
  });

  final List<TaskListSection> sections;
  final TaskSortOption sortOption;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;
  final double bottomPadding;

  @override
  State<TaskListSectionsList> createState() => _TaskListSectionsListState();
}

class _TaskListSectionsListState extends State<TaskListSectionsList> {
  final ValueNotifier<String?> _hoveredTaskIdNotifier = ValueNotifier(null);

  @override
  void dispose() {
    _hoveredTaskIdNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildShowcaseItems(
      sections: widget.sections,
      sortOption: widget.sortOption,
    );

    return DesignSystemScrollbar(
      child: ListView.builder(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return TaskBrowseListItem(
            key: ValueKey(item.record.task.meta.id),
            entry: item.entry,
            sortOption: widget.sortOption,
            showCreationDate: false,
            showDueDate: true,
            showCoverArt: false,
            categoryNameOverride: item.record.category.name,
            categoryIconOverride: item.record.category.icon?.iconData,
            categoryColorHexOverride: item.record.category.color,
            trackedDurationLabelOverride: item.record.trackedDurationLabel,
            sectionHeaderTitleOverride: item.sectionTitle,
            previousTaskIdInSection: index > 0 && !item.entry.isFirstInSection
                ? items[index - 1].record.task.meta.id
                : null,
            nextTaskIdInSection:
                !item.entry.isLastInSection && index < items.length - 1
                ? items[index + 1].record.task.meta.id
                : null,
            selectedTaskId: widget.selectedTaskId,
            hoveredTaskIdNotifier: _hoveredTaskIdNotifier,
            onTap: () => widget.onTaskSelected(item.record.task.meta.id),
          );
        },
      ),
    );
  }
}

TaskSortOption taskSortOptionFromSelectedSortId(String selectedSortId) {
  return switch (selectedSortId) {
    TaskSortIds.createdDateSort => TaskSortOption.byDate,
    TaskSortIds.prioritySort => TaskSortOption.byPriority,
    _ => TaskSortOption.byDueDate,
  };
}

List<_TaskShowcaseBrowseItem> _buildShowcaseItems({
  required List<TaskListSection> sections,
  required TaskSortOption sortOption,
}) {
  final items = <_TaskShowcaseBrowseItem>[];

  for (final section in sections) {
    final sectionKey = _sectionKeyForSection(section, sortOption: sortOption);
    for (var index = 0; index < section.tasks.length; index++) {
      final record = section.tasks[index];
      items.add(
        _TaskShowcaseBrowseItem(
          record: record,
          sectionTitle: section.title,
          entry: TaskBrowseEntry(
            task: record.task,
            sectionKey: sectionKey,
            showSectionHeader: index == 0,
            isFirstInSection: index == 0,
            isLastInSection: index == section.tasks.length - 1,
            sectionCount: index == 0 ? section.tasks.length : null,
          ),
        ),
      );
    }
  }

  return items;
}

TaskBrowseSectionKey _sectionKeyForSection(
  TaskListSection section, {
  required TaskSortOption sortOption,
}) {
  final firstTask = section.tasks.first.task;
  return switch (sortOption) {
    TaskSortOption.byPriority => TaskBrowseSectionKey.priority(
      firstTask.data.priority,
    ),
    TaskSortOption.byDate => TaskBrowseSectionKey.createdDate(
      firstTask.meta.dateFrom,
    ),
    TaskSortOption.byDueDate =>
      firstTask.data.due != null
          ? TaskBrowseSectionKey.dueDate(firstTask.data.due!)
          : const TaskBrowseSectionKey.noDueDate(),
  };
}

class _TaskShowcaseBrowseItem {
  const _TaskShowcaseBrowseItem({
    required this.record,
    required this.sectionTitle,
    required this.entry,
  });

  final TaskRecord record;
  final String sectionTitle;
  final TaskBrowseEntry entry;
}

class TaskListActiveFilters extends StatelessWidget {
  const TaskListActiveFilters({
    required this.state,
    required this.onFilterPressed,
    this.onFilterChanged,
    this.onClearAll,
    super.key,
  });

  final TaskListDetailState state;
  final VoidCallback onFilterPressed;

  /// Called with the filter state after a single chip has been removed.
  /// When `null`, tapping a chip falls back to [onFilterPressed] (opens
  /// the filter modal) so legacy callers keep working.
  final ValueChanged<DesignSystemTaskFilterState>? onFilterChanged;

  /// Called when the user taps "Clear all". When `null` the button is
  /// hidden; otherwise it resets every filter section at once.
  final VoidCallback? onClearAll;

  @override
  Widget build(BuildContext context) {
    final filterState = state.filterState;

    final chips = <_ActiveFilterChip>[
      ...?filterState.statusField?.selectedOptions.map(
        (option) => _ActiveFilterChip(
          label: option.label,
          onRemove: onFilterChanged == null
              ? null
              : () => onFilterChanged!(
                  filterState.removeSelection(
                    DesignSystemTaskFilterSection.status,
                    option.id,
                  ),
                ),
        ),
      ),
      for (final priorityId in filterState.selectedPriorityIds)
        _ActiveFilterChip(
          label:
              filterState.priorityOptions
                  .where((option) => option.id == priorityId)
                  .firstOrNull
                  ?.label ??
              priorityId.toUpperCase(),
          priority: _taskPriorityForId(priorityId),
          onRemove: onFilterChanged == null
              ? null
              : () => onFilterChanged!(filterState.togglePriority(priorityId)),
        ),
      ...?filterState.categoryField?.selectedOptions.map(
        (option) => _ActiveFilterChip(
          label: option.label,
          onRemove: onFilterChanged == null
              ? null
              : () => onFilterChanged!(
                  filterState.removeSelection(
                    DesignSystemTaskFilterSection.category,
                    option.id,
                  ),
                ),
        ),
      ),
      ...?filterState.labelField?.selectedOptions.map(
        (option) => _ActiveFilterChip(
          label: option.label,
          onRemove: onFilterChanged == null
              ? null
              : () => onFilterChanged!(
                  filterState.removeSelection(
                    DesignSystemTaskFilterSection.label,
                    option.id,
                  ),
                ),
        ),
      ),
    ].where((chip) => chip.label.isNotEmpty).toList();

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final chip in chips)
            DesignSystemChip(
              label: chip.label,
              onPressed: chip.onRemove ?? onFilterPressed,
              showRemove: chip.onRemove != null,
              avatar: chip.priority != null
                  ? TaskShowcasePriorityGlyph(priority: chip.priority!)
                  : null,
            ),
          if (onClearAll != null)
            DesignSystemChip(
              label: context.messages.tasksFilterClearAll,
              onPressed: onClearAll,
              leadingIcon: Icons.close_rounded,
            ),
        ],
      ),
    );
  }
}

class _ActiveFilterChip {
  const _ActiveFilterChip({
    required this.label,
    this.priority,
    this.onRemove,
  });

  final String label;
  final TaskPriority? priority;
  final VoidCallback? onRemove;
}

TaskPriority? _taskPriorityForId(String id) {
  return switch (id) {
    TaskPriorityFilterIds.p0 => TaskPriority.p0Urgent,
    TaskPriorityFilterIds.p1 => TaskPriority.p1High,
    TaskPriorityFilterIds.p2 => TaskPriority.p2Medium,
    TaskPriorityFilterIds.p3 => TaskPriority.p3Low,
    _ => null,
  };
}

class _TaskListSearchHeader extends StatelessWidget {
  const _TaskListSearchHeader({
    required this.query,
    required this.onSearchChanged,
    required this.onSearchCleared,
    required this.onFilterPressed,
  });

  final String query;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchCleared;
  final VoidCallback onFilterPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 132),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: TaskShowcasePalette.page(context),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DesignSystemSearch(
                  hintText: context.messages.searchTasksHint,
                  initialText: query,
                  onChanged: onSearchChanged,
                  onClear: onSearchCleared,
                  onSearchPressed: onSearchChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: context.messages.tasksFilterTitle,
                onPressed: onFilterPressed,
                icon: Icon(
                  Icons.filter_list_rounded,
                  color: TaskShowcasePalette.accent(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class TaskShowcaseEmptyResults extends StatelessWidget {
  const TaskShowcaseEmptyResults({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: context.designTokens.typography.styles.subtitle.subtitle1
            .copyWith(color: TaskShowcasePalette.mediumText(context)),
      ),
    );
  }
}
