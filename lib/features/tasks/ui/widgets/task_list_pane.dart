import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/categories/domain/category_icon.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/scrollbars/design_system_scrollbar.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_task_filter_sheet.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_models.dart';
import 'package:lotti/features/tasks/ui/model/task_list_detail_state.dart';
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

class TaskListSectionsList extends StatelessWidget {
  const TaskListSectionsList({
    required this.sections,
    required this.selectedTaskId,
    required this.onTaskSelected,
    this.bottomPadding = 120,
    super.key,
  });

  final List<TaskListSection> sections;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return DesignSystemScrollbar(
      child: ListView.separated(
        padding: EdgeInsets.only(bottom: bottomPadding),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 20),
        itemBuilder: (context, index) {
          return _TaskSectionCard(
            section: sections[index],
            selectedTaskId: selectedTaskId,
            onTaskSelected: onTaskSelected,
          );
        },
      ),
    );
  }
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
      ...filterState.statusField.selectedOptions.map((option) => option.label),
      if (filterState.selectedPriorityId !=
          DesignSystemTaskFilterState.allPriorityId)
        filterState.priorityOptions
                .where((option) => option.id == filterState.selectedPriorityId)
                .firstOrNull
                ?.label ??
            '',
      ...filterState.categoryField.selectedOptions.map(
        (option) => option.label,
      ),
      ...filterState.labelField.selectedOptions.map((option) => option.label),
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
      height: 120,
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
        ],
      ),
    );
  }
}

class _TaskSectionCard extends StatelessWidget {
  const _TaskSectionCard({
    required this.section,
    required this.selectedTaskId,
    required this.onTaskSelected,
  });

  final TaskListSection section;
  final String? selectedTaskId;
  final ValueChanged<String> onTaskSelected;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                section.title,
                style: tokens.typography.styles.others.caption.copyWith(
                  color: TaskShowcasePalette.highText(context),
                ),
              ),
              const Spacer(),
              Text(
                context.messages.taskShowcaseTaskCount(section.tasks.length),
                style: tokens.typography.styles.others.caption.copyWith(
                  color: TaskShowcasePalette.mediumText(context),
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(tokens.radii.l),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: TaskShowcasePalette.surface(context),
              border: Border.all(color: TaskShowcasePalette.border(context)),
            ),
            child: Column(
              children: [
                for (var index = 0; index < section.tasks.length; index++)
                  _TaskListRow(
                    record: section.tasks[index],
                    selected:
                        section.tasks[index].task.meta.id == selectedTaskId,
                    onTap: () =>
                        onTaskSelected(section.tasks[index].task.meta.id),
                    showDivider: index < section.tasks.length - 1,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TaskListRow extends StatelessWidget {
  const _TaskListRow({
    required this.record,
    required this.selected,
    required this.onTap,
    required this.showDivider,
  });

  final TaskRecord record;
  final bool selected;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final category = record.category;
    final categoryColor = category.color ?? defaultTaskCategoryColorHex;

    return DesignSystemListItem(
      titleContent: Text(
        record.task.data.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.designTokens.typography.styles.subtitle.subtitle2
            .copyWith(
              color: TaskShowcasePalette.highText(context),
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitleSpans: [
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: TaskShowcaseCategoryChip(
            label: category.name,
            colorHex: categoryColor,
            icon: category.icon?.iconData ?? Icons.label_outline,
          ),
        ),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(width: 8),
        ),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: TaskShowcasePriorityGlyph(priority: record.task.data.priority),
        ),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(width: 6),
        ),
        TextSpan(text: record.task.data.priority.short),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(width: 12),
        ),
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Icon(
            Icons.watch_later_outlined,
            size: 16,
            color: TaskShowcasePalette.mediumText(context),
          ),
        ),
        const WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(width: 6),
        ),
        TextSpan(text: record.timeRange),
      ],
      trailing: TaskShowcaseStatusLabel(status: record.task.data.status),
      activated: selected,
      selected: selected,
      activatedBackgroundColor: TaskShowcasePalette.selectedRow(context),
      hoverBackgroundColor: TaskShowcasePalette.hoverFill(context),
      pressedBackgroundColor: TaskShowcasePalette.selectedRow(context),
      showDivider: showDivider,
      onTap: onTap,
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
