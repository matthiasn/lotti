import 'package:flutter/material.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
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
        border: Border(
          right: BorderSide(color: TaskShowcasePalette.border(context)),
        ),
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
    super.key,
  });

  final TaskListDetailState state;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final filterState = state.filterState;
    final chips = <String>[
      ...?filterState.statusField?.selectedOptions.map(
        (option) => option.label,
      ),
      if (filterState.selectedPriorityId !=
          DesignSystemTaskFilterState.allPriorityId)
        filterState.priorityOptions
                .where((option) => option.id == filterState.selectedPriorityId)
                .firstOrNull
                ?.label ??
            '',
      ...?filterState.categoryField?.selectedOptions.map(
        (option) => option.label,
      ),
      ...?filterState.labelField?.selectedOptions.map((option) => option.label),
    ].where((label) => label.isNotEmpty).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Text(
              context.messages.taskShowcaseActiveFilters,
              style: tokens.typography.styles.others.caption.copyWith(
                color: TaskShowcasePalette.mediumText(context),
              ),
            ),
            for (final chip in chips)
              Chip(
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                label: Text(chip),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
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
      height: 132,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      color: TaskShowcasePalette.page(context),
      child: Column(
        children: [
          SizedBox(
            height: 48,
            child: Row(
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
                  onPressed: onFilterPressed,
                  icon: Icon(
                    Icons.tune_rounded,
                    color: TaskShowcasePalette.accent(context),
                  ),
                ),
              ],
            ),
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
