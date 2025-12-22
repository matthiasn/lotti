import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_with_suggestion_widget.dart';
import 'package:lotti/features/tasks/ui/checklists/drag_utils.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/buttons/lotti_tertiary_button.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class ChecklistItemWrapper extends ConsumerWidget {
  const ChecklistItemWrapper(
    this.itemId, {
    required this.checklistId,
    required this.taskId,
    this.hideIfChecked = false,
    super.key,
  });

  final String itemId;
  final String taskId;
  final String checklistId;
  final bool hideIfChecked;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = checklistItemControllerProvider(
      id: itemId,
      taskId: taskId,
    );
    final item = ref.watch(provider);

    return item.map(
      data: (data) {
        final item = data.value;
        if (item == null || item.isDeleted) {
          return const SizedBox.shrink();
        }

        // Capture notifiers before widget disposal
        final itemNotifier = ref.read(provider.notifier);
        final checklistNotifier = ref.read(checklistControllerProvider(
          id: checklistId,
          taskId: taskId,
        ).notifier);

        final child = DragItemWidget(
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
          dragBuilder: buildDragDecorator,
          child: DraggableWidget(
            child: Dismissible(
              key: Key(item.id),
              dismissThresholds: const {DismissDirection.endToStart: 0.25},
              onDismissed: (_) async {
                await itemNotifier.delete();
                // Also remove from parent checklist to trigger task update
                await checklistNotifier.unlinkItem(itemId);
              },
              background: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ColoredBox(
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
                        LottiTertiaryButton(
                          label: context.messages.checklistItemDeleteCancel,
                          onPressed: () => Navigator.of(context).pop(false),
                        ),
                        LottiTertiaryButton(
                          label: context.messages.checklistItemDeleteConfirm,
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ],
                    );
                  },
                );
                return result ?? false;
              },
              child: ChecklistItemWithSuggestionWidget(
                itemId: item.id,
                title: item.data.title,
                isChecked: item.data.isChecked,
                hideCompleted: hideIfChecked,
                onChanged: (checked) =>
                    ref.read(provider.notifier).updateChecked(checked: checked),
                onTitleChange: ref.read(provider.notifier).updateTitle,
              ),
            ),
          ),
        );

        return child;
      },
      error: ErrorWidget.new,
      loading: (_) => const SizedBox.shrink(),
    );
  }
}
