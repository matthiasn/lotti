import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_wrapper.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/logic/create/create_entry.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/cards/index.dart';

class ChecklistsWidget extends ConsumerStatefulWidget {
  const ChecklistsWidget({
    required this.entryId,
    required this.task,
    super.key,
  });

  final String entryId;
  final Task task;

  @override
  ConsumerState<ChecklistsWidget> createState() => _ChecklistsWidgetState();
}

class _ChecklistsWidgetState extends ConsumerState<ChecklistsWidget> {
  bool _isEditing = false;
  List<String>? _checklistIds;

  @override
  Widget build(BuildContext context) {
    final provider = entryControllerProvider(id: widget.entryId);
    final item = ref.watch(provider).value?.entry;
    final notifier = ref.read(provider.notifier);

    if (item == null || item is! Task) {
      return const SizedBox.shrink();
    }

    final checklistIds = _checklistIds ?? item.data.checklistIds ?? [];
    final color = context.colorScheme.outline;

    return ModernBaseCard(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                context.messages.checklistsTitle,
                style: context.textTheme.titleSmall?.copyWith(color: color),
              ),
              IconButton(
                tooltip: context.messages.addActionAddChecklist,
                onPressed: () => createChecklist(task: widget.task, ref: ref),
                icon: Icon(Icons.add_rounded, color: color),
              ),
              if (checklistIds.length > 1)
                IconButton(
                  tooltip: context.messages.addActionAddChecklist,
                  onPressed: () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                  icon: Icon(Icons.reorder, color: color),
                ),
            ],
          ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: _isEditing,
            onReorder: (int oldIndex, int newIndex) {
              final itemIds = [...checklistIds];
              final movedItem = itemIds.removeAt(oldIndex);
              final insertionIndex =
                  newIndex > oldIndex ? newIndex - 1 : newIndex;
              itemIds.insert(insertionIndex, movedItem);
              setState(() {
                _checklistIds = itemIds;
              });

              notifier.updateChecklistOrder(itemIds);
            },
            children: List.generate(
              checklistIds.length,
              (int index) {
                final checklistId = checklistIds.elementAt(index);
                return ChecklistWrapper(
                  key: Key('$checklistId${widget.entryId}$index'),
                  entryId: checklistId,
                  categoryId: item.categoryId,
                  taskId: widget.task.id,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
