import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/checklist_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';

class ChecklistsWidget extends ConsumerWidget {
  const ChecklistsWidget({
    required this.entryId,
    required this.task,
    super.key,
  });

  final String entryId;
  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final item = ref.watch(provider).value?.entry;

    if (item == null || item is! Task) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.messages.checklistsTitle),
            IconButton(
              tooltip: context.messages.addActionAddChecklist,
              onPressed: () => createChecklist(task: task),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        ...?item.data.checklistIds?.map(
          (checklistId) => ChecklistWrapper(entryId: checklistId),
        ),
      ],
    );
  }
}
