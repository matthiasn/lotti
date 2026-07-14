import 'package:flutter/material.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/design_system/components/selection/design_system_selection_row.dart';
import 'package:lotti/features/tasks/ui/widgets/task_showcase_chips.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Modal body for choosing a task priority.
///
/// Uses the same full-width selection row as status, category, project, and AI
/// selectors. The compact priority code and its localized description form one
/// stable title so every row shares the same leading and text columns.
class TaskPriorityModalContent extends StatelessWidget {
  const TaskPriorityModalContent({
    required this.currentPriority,
    required this.onSelected,
    super.key,
  });

  final TaskPriority currentPriority;
  final ValueChanged<TaskPriority> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final priority in TaskPriority.values)
          DesignSystemSelectionRow(
            key: ValueKey('task-priority-${priority.short}'),
            title: '${priority.short} · ${_description(context, priority)}',
            type: DesignSystemSelectionRowType.singleSelect,
            selected: priority == currentPriority,
            leading: TaskShowcasePriorityGlyph(priority: priority),
            onTap: () => onSelected(priority),
          ),
      ],
    );
  }

  String _description(BuildContext context, TaskPriority priority) {
    final messages = context.messages;
    return switch (priority) {
      TaskPriority.p0Urgent => messages.tasksPriorityP0Description,
      TaskPriority.p1High => messages.tasksPriorityP1Description,
      TaskPriority.p2Medium => messages.tasksPriorityP2Description,
      TaskPriority.p3Low => messages.tasksPriorityP3Description,
    };
  }
}
