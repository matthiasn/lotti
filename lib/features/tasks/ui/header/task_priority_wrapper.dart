import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/modern_status_chip.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class TaskPriorityWrapper extends ConsumerWidget {
  const TaskPriorityWrapper({
    required this.taskId,
    this.showLabel = true,
    super.key,
  });

  final String taskId;
  final bool showLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: taskId);
    final entryState = ref.watch(provider).valueOrNull;
    final task = entryState?.entry;

    if (task is! Task) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    final color = task.data.priority.colorForBrightness(brightness);

    return InkWell(
      onTap: () => _showPicker(
        context,
        ref,
        taskId,
        task.data.priority,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel) ...[
            Text(
              context.messages.tasksPriorityTitle,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 4),
          ],
          ModernStatusChip(
            label: task.data.priority.short,
            color: color,
            borderWidth: AppTheme.statusIndicatorBorderWidth * 1.5,
          ),
        ],
      ),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    String taskId,
    TaskPriority current,
  ) async {
    // Read a fresh notifier right before opening the sheet to avoid
    // holding a stale reference across rebuilds/navigation.
    final controller = ref.read(entryControllerProvider(id: taskId).notifier);
    const options = TaskPriority.values;
    final res = await ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.tasksPriorityPickerTitle,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...options.map((p) => ListTile(
                leading: ModernStatusChip(
                  label: p.short,
                  color: p.colorForBrightness(Theme.of(ctx).brightness),
                  borderWidth: AppTheme.statusIndicatorBorderWidth * 1.5,
                ),
                title: Text(_localizedDescription(ctx, p)),
                trailing: current == p ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(ctx).pop(p.short),
              )),
        ],
      ),
    );

    if (res != null) {
      await controller.updateTaskPriority(res);
    }
  }

  String _localizedDescription(BuildContext context, TaskPriority p) {
    final m = context.messages;
    switch (p) {
      case TaskPriority.p0Urgent:
        return m.tasksPriorityP0Description;
      case TaskPriority.p1High:
        return m.tasksPriorityP1Description;
      case TaskPriority.p2Medium:
        return m.tasksPriorityP2Description;
      case TaskPriority.p3Low:
        return m.tasksPriorityP3Description;
    }
  }
}
