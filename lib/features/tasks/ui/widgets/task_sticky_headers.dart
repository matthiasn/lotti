import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/task_sticky_headers_controller.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class TaskStickyHeaders extends ConsumerWidget {
  const TaskStickyHeaders({
    required this.taskId,
    required this.task,
    required this.onTaskHeaderTap,
    required this.onAiSummaryTap,
    required this.onChecklistsTap,
    this.onTimeRecordingTap,
    super.key,
  });

  final String taskId;
  final Task task;
  final VoidCallback onTaskHeaderTap;
  final VoidCallback onAiSummaryTap;
  final VoidCallback onChecklistsTap;
  final VoidCallback? onTimeRecordingTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stickyHeadersState = ref.watch(
      taskStickyHeadersControllerProvider(taskId),
    );

    print('build TaskStickyHeaders $stickyHeadersState');

    // Return empty if no headers are visible
    if (!stickyHeadersState.isTaskHeaderVisible &&
        !stickyHeadersState.isAiSummaryVisible &&
        !stickyHeadersState.isChecklistsVisible) {
      return const SizedBox.shrink();
    }

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Task Header - Sticky when visible
          if (stickyHeadersState.isTaskHeaderVisible)
            GestureDetector(
              onTap: onTaskHeaderTap,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: context.colorScheme.outlineVariant,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      offset: const Offset(0, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: _TaskHeaderContent(task: task),
              ),
            ),

          // AI Summary Header - Sticky when visible
          if (stickyHeadersState.isAiSummaryVisible)
            GestureDetector(
              onTap: onAiSummaryTap,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: context.colorScheme.outlineVariant,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: _SectionHeader(
                  icon: MdiIcons.robotOutline,
                  title: 'AI Task Summary',
                ),
              ),
            ),

          // Checklists Header - Sticky when visible
          if (stickyHeadersState.isChecklistsVisible)
            GestureDetector(
              onTap: onChecklistsTap,
              child: Container(
                height: 48,
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  border: Border(
                    bottom: BorderSide(
                      color: context.colorScheme.outlineVariant,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                child: _SectionHeader(
                  icon: MdiIcons.checkboxMultipleOutline,
                  title: 'Checklists',
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TaskHeaderContent extends StatelessWidget {
  const _TaskHeaderContent({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          // Task title
          Expanded(
            child: Text(
              task.data.title,
              style: context.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Progress indicator if available
          if (task.data.estimate != null)
            Container(
              margin: const EdgeInsets.only(left: 12),
              child: Text(
                '${task.data.estimate!.inHours}h',
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _getStatusColor() => task.data.status.map(
        open: (_) => Colors.blue,
        inProgress: (_) => Colors.blue,
        groomed: (_) => Colors.orange,
        blocked: (_) => Colors.red,
        onHold: (_) => Colors.amber,
        done: (_) => Colors.green,
        rejected: (_) => Colors.red.shade900,
      );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
