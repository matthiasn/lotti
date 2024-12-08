import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklist_item_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class ChecklistItemWrapper extends ConsumerWidget {
  const ChecklistItemWrapper(
    this.itemId, {
    required this.checklistId,
    super.key,
  });

  final String itemId;
  final String checklistId;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = checklistItemControllerProvider(id: itemId);
    final item = ref.watch(provider);

    return item.map(
      data: (data) {
        final item = data.value;
        if (item == null || item.isDeleted) {
          return const SizedBox.shrink();
        }
        return DragItemWidget(
          dragItemProvider: (request) async {
            final dragItem = DragItem(
              localData: {
                'checklistItemId': item.id,
                'checklistId': checklistId,
              },
            )..add(Formats.plainText(item.data.title));
            return dragItem;
          },
          allowedOperations: () => [DropOperation.move],
          child: DraggableWidget(
            child: Dismissible(
              key: Key(item.id),
              dismissThresholds: const {DismissDirection.endToStart: 0.25},
              onDismissed: (_) => ref.read(provider.notifier).delete(),
              background: ColoredBox(
                color: context.colorScheme.error,
                child: const Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async {
                final result = await showDialog<bool>(
                  context: context,
                  builder: (context) {
                    return AlertDialog(
                      title: Text(context.messages.checklistItemDelete),
                      content: Text(
                        context.messages.checklistItemDeleteWarning,
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child:
                              Text(context.messages.checklistItemDeleteCancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child:
                              Text(context.messages.checklistItemDeleteConfirm),
                        ),
                      ],
                    );
                  },
                );
                return result ?? false;
              },
              child: ChecklistItemWidget(
                title: item.data.title,
                isChecked: item.data.isChecked,
                onChanged: (checked) =>
                    ref.read(provider.notifier).updateChecked(checked: checked),
                onDelete: ref.read(provider.notifier).delete,
                onTitleChange: ref.read(provider.notifier).updateTitle,
              ),
            ),
          ),
        );
      },
      error: ErrorWidget.new,
      loading: (_) => const SizedBox.shrink(),
    );
  }
}
