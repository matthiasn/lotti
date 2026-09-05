import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/lists/design_system_list_item.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/design_system/components/task_filters/design_system_filter_shared.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/projects/ui/model/project_task_list_options.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

/// The label the sheet and the group headers use for a grouping choice.
String projectTaskGroupByLabel(
  AppLocalizations messages,
  ProjectTaskGroupBy groupBy,
) => switch (groupBy) {
  ProjectTaskGroupBy.creationMonth => messages.projectTasksGroupByCreationMonth,
  ProjectTaskGroupBy.status => messages.projectTasksGroupByStatus,
  ProjectTaskGroupBy.priority => messages.projectTasksGroupByPriority,
  ProjectTaskGroupBy.dueWindow => messages.projectTasksGroupByDueWindow,
  ProjectTaskGroupBy.none => messages.projectTasksGroupByNone,
};

String projectTaskSortByLabel(
  AppLocalizations messages,
  ProjectTaskSortBy sortBy,
) => switch (sortBy) {
  ProjectTaskSortBy.actionability => messages.projectTasksSortActionability,
  ProjectTaskSortBy.created => messages.projectTasksSortCreated,
  ProjectTaskSortBy.dueDate => messages.projectTasksSortDueDate,
  ProjectTaskSortBy.estimate => messages.projectTasksSortEstimate,
  ProjectTaskSortBy.priority => messages.projectTasksSortPriority,
  ProjectTaskSortBy.recentlyUpdated => messages.projectTasksSortRecentlyUpdated,
  ProjectTaskSortBy.title => messages.projectTasksSortTitle,
};

/// Opens the "Sort and group" sheet for a project's task list. Every choice
/// applies immediately through [onChanged] — the list behind the sheet
/// re-groups as the user picks — and the sheet closes from its own close
/// control, the way the shared single-page modal does on both a phone and a
/// desktop pane.
Future<void> showProjectTaskListOptionsSheet({
  required BuildContext context,
  required ProjectTaskListOptions options,
  required ValueChanged<ProjectTaskListOptions> onChanged,
}) {
  return ModalUtils.showSinglePageModal<void>(
    context: context,
    title: context.messages.projectTasksSortAndGroup,
    padding: EdgeInsets.zero,
    builder: (modalContext) => ProjectTaskListOptionsSheetContent(
      options: options,
      onChanged: onChanged,
    ),
  );
}

/// The sheet body: a group-by section, a sort-by section and the done-tasks
/// toggle, each choice a single-select row that applies on tap.
class ProjectTaskListOptionsSheetContent extends StatefulWidget {
  const ProjectTaskListOptionsSheetContent({
    required this.options,
    required this.onChanged,
    super.key,
  });

  final ProjectTaskListOptions options;
  final ValueChanged<ProjectTaskListOptions> onChanged;

  @override
  State<ProjectTaskListOptionsSheetContent> createState() =>
      _ProjectTaskListOptionsSheetContentState();
}

class _ProjectTaskListOptionsSheetContentState
    extends State<ProjectTaskListOptionsSheetContent> {
  late ProjectTaskListOptions _options = widget.options;

  void _apply(ProjectTaskListOptions next) {
    if (next == _options) return;
    setState(() => _options = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(messages.projectTasksGroupBy),
          for (final groupBy in ProjectTaskGroupBy.values)
            DesignSystemSelectionRow(
              key: ValueKey('project-tasks-group-${groupBy.name}'),
              title: projectTaskGroupByLabel(messages, groupBy),
              type: DesignSystemSelectionRowType.singleSelect,
              size: DesignSystemListItemSize.small,
              selected: _options.groupBy == groupBy,
              onTap: () => _apply(_options.copyWith(groupBy: groupBy)),
            ),
          _SectionLabel(messages.projectTasksSortBy),
          for (final sortBy in ProjectTaskSortBy.values)
            DesignSystemSelectionRow(
              key: ValueKey('project-tasks-sort-${sortBy.name}'),
              title: projectTaskSortByLabel(messages, sortBy),
              type: DesignSystemSelectionRowType.singleSelect,
              size: DesignSystemListItemSize.small,
              selected: _options.sortBy == sortBy,
              onTap: () => _apply(_options.copyWith(sortBy: sortBy)),
            ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.designTokens.spacing.step5,
              vertical: context.designTokens.spacing.step2,
            ),
            child: DesignSystemFilterToggleRow(
              key: const ValueKey('project-tasks-show-done'),
              label: messages.projectTasksShowDone,
              value: _options.showDone,
              onChanged: (value) => _apply(_options.copyWith(showDone: value)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step4,
        tokens.spacing.step5,
        tokens.spacing.step1,
      ),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: tokens.typography.styles.others.caption.copyWith(
            color: tokens.colors.text.lowEmphasis,
            fontWeight: tokens.typography.weight.semiBold,
          ),
        ),
      ),
    );
  }
}
