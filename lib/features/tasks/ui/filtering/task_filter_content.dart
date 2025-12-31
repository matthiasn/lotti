import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/filtering/task_category_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_date_display_toggle.dart';
import 'package:lotti/features/tasks/ui/filtering/task_due_date_display_toggle.dart';
import 'package:lotti/features/tasks/ui/filtering/task_label_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_priority_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_sort_filter.dart';
import 'package:lotti/features/tasks/ui/filtering/task_status_filter.dart';
import 'package:lotti/widgets/app_bar/journal_sliver_appbar.dart';

/// The content displayed inside the task filter modal.
/// Extracted into a separate widget for better testability.
class TaskFilterContent extends StatelessWidget {
  const TaskFilterContent({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            JournalFilter(),
            SizedBox(width: 10),
          ],
        ),
        SizedBox(height: 10),
        TaskSortFilter(),
        SizedBox(height: 10),
        TaskStatusFilter(),
        TaskPriorityFilter(),
        TaskCategoryFilter(),
        TaskLabelFilter(),
        SizedBox(height: 10),
        Divider(),
        SizedBox(height: 10),
        TaskDateDisplayToggle(),
        TaskDueDateDisplayToggle(),
      ],
    );
  }
}
