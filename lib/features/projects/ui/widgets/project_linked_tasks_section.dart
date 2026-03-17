import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/form/form_widgets.dart';

/// Displays a list of tasks linked to a project.
class ProjectLinkedTasksSection extends StatelessWidget {
  const ProjectLinkedTasksSection({
    required this.tasks,
    super.key,
  });

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;

    return LottiFormSection(
      title: messages.projectLinkedTasks,
      icon: Icons.task_alt,
      children: [
        if (tasks.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              messages.projectNoLinkedTasks,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          )
        else
          ...tasks.map(
            (task) => _TaskTile(task: task),
          ),
      ],
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final statusLabel = task.data.status.toDbString;
    final messages = context.messages;

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.task_alt, size: 20),
      title: Text(
        task.data.title.isEmpty ? messages.taskUntitled : task.data.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        statusLabel,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: context.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => getIt<NavService>().beamToNamed('/tasks/${task.meta.id}'),
    );
  }
}
