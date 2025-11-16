import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/compact_task_progress.dart';
import 'package:lotti/features/tasks/ui/header/estimated_time_widget.dart';
import 'package:lotti/features/tasks/ui/header/task_category_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_language_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_priority_wrapper.dart';
import 'package:lotti/features/tasks/ui/header/task_status_wrapper.dart';
import 'package:lotti/features/tasks/ui/task_date_row.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class TaskHeaderMetaCard extends StatelessWidget {
  const TaskHeaderMetaCard({
    required this.taskId,
    super.key,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: TaskDateRow(taskId: taskId)),
            const SizedBox(width: 12),
            _EditableTaskProgress(taskId: taskId),
          ],
        ),
        const SizedBox(height: AppTheme.cardSpacing / 2),
        _TaskMetadataRow(taskId: taskId),
      ],
    );
  }
}

class _TaskMetadataRow extends StatelessWidget {
  const _TaskMetadataRow({
    required this.taskId,
  });

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppTheme.cardSpacing / 2,
            runSpacing: AppTheme.cardSpacing / 2,
            children: [
              TaskPriorityWrapper(
                taskId: taskId,
                showLabel: false,
              ),
              TaskStatusWrapper(
                taskId: taskId,
                showLabel: false,
              ),
              TaskCategoryWrapper(taskId: taskId),
              TaskLanguageWrapper(taskId: taskId),
            ],
          ),
        ),
      ],
    );
  }
}

class _EditableTaskProgress extends ConsumerWidget {
  const _EditableTaskProgress({
    required this.taskId,
  });

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider).valueOrNull;
    final task = entryState?.entry;

    final hasTask = task is Task;
    final estimate = hasTask ? task.data.estimate : null;
    final hasEstimate = estimate != null && estimate != Duration.zero;

    Future<void> onTap() async {
      if (!hasTask) {
        return;
      }

      await showEstimatePicker(
        context: context,
        initialDuration: estimate ?? Duration.zero,
        onEstimateChanged: (newDuration) async {
          await notifier.save(estimate: newDuration);
        },
      );
    }

    final Widget child;
    if (hasEstimate) {
      child = CompactTaskProgress(taskId: taskId);
    } else {
      child = Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.statusIndicatorPaddingHorizontal,
          vertical: AppTheme.statusIndicatorPaddingVertical,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainerHighest.withValues(
            alpha: AppTheme.alphaSurfaceContainerHighest,
          ),
          borderRadius: BorderRadius.circular(
            AppTheme.statusIndicatorBorderRadius,
          ),
          border: Border.all(
            color: context.colorScheme.outline.withValues(
              alpha: AppTheme.alphaStatusIndicatorBorder,
            ),
            width: AppTheme.statusIndicatorBorderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_outlined,
              size: AppTheme.statusIndicatorIconSizeCompact,
              color: context.colorScheme.outline,
            ),
            const SizedBox(width: 6),
            Text(
              context.messages.taskNoEstimateLabel,
              style: context.textTheme.titleSmall?.copyWith(
                color: context.colorScheme.onSurfaceVariant.withValues(
                  alpha: AppTheme.alphaSurfaceVariant,
                ),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: onTap,
      child: child,
    );
  }
}
