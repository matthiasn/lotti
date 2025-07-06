import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_widget.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class ChecklistWrapper extends ConsumerWidget {
  const ChecklistWrapper({
    required this.entryId,
    required this.taskId,
    this.categoryId,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final String entryId;
  final String taskId;
  final String? categoryId;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = checklistControllerProvider(id: entryId, taskId: taskId);
    final notifier = ref.read(provider.notifier);
    final checklist = ref.watch(provider).value;

    final completionRate = ref
        .watch(
          checklistCompletionRateControllerProvider(
            id: entryId,
            taskId: taskId,
          ),
        )
        .value;

    final res = ref
        .watch(
          checklistCompletionControllerProvider(id: entryId, taskId: taskId),
        )
        .value;
    final totalCount = res?.totalCount ?? 0;

    if (checklist == null || completionRate == null) {
      return const SizedBox.shrink();
    }

    return DropRegion(
      formats: Formats.standardFormats,
      onDropOver: (event) {
        return DropOperation.move;
      },
      onPerformDrop: (event) async {
        final item = event.session.items.first;
        final localData = item.localData;
        if (localData != null) {
          await notifier.dropChecklistItem(
            localData,
            categoryId: categoryId,
          );
        }
      },
      child: ChecklistWidget(
        id: checklist.id,
        taskId: taskId,
        title: checklist.data.title,
        itemIds: checklist.data.linkedChecklistItems,
        onTitleSave: notifier.updateTitle,
        onCreateChecklistItem: (title) => notifier.createChecklistItem(
          title,
          isChecked: false,
          categoryId: checklist.meta.categoryId,
        ),
        updateItemOrder: notifier.updateItemOrder,
        completionRate: completionRate,
        onDelete: ref.read(provider.notifier).delete,
        totalCount: totalCount,
      ),
    );
  }
}
