import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/modal/modal_utils.dart';

class TaskPriorityWrapper extends ConsumerWidget {
  const TaskPriorityWrapper({
    required this.taskId,
    super.key,
  });

  final String taskId;

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

    return OutlinedButton.icon(
      onPressed: () => _showPicker(
        context,
        ref,
        taskId,
        task.data.priority,
      ),
      icon: Icon(Icons.priority_high_rounded, color: color, size: 18),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      label: Text(
        task.data.priority.short,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
    final controller =
        ref.read(entryControllerProvider(id: taskId).notifier);
    const options = TaskPriority.values;
    final res = await ModalUtils.showSinglePageModal<String>(
      context: context,
      title: context.messages.tasksPriorityPickerTitle,
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...options.map((p) => ListTile(
                leading: Icon(
                  Icons.priority_high_rounded,
                  color: p.colorForBrightness(Theme.of(ctx).brightness),
                ),
                title:
                    Text('${p.short} — ${_localizedDescription(ctx, p)}'),
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
