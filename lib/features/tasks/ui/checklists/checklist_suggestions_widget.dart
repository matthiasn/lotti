import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/action_item_suggestions.dart';
import 'package:lotti/features/ai/state/checklist_suggestions_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class ChecklistSuggestionsWidget extends ConsumerStatefulWidget {
  const ChecklistSuggestionsWidget({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  ConsumerState<ChecklistSuggestionsWidget> createState() =>
      _ChecklistSuggestionsWidgetState();
}

class _ChecklistSuggestionsWidgetState
    extends ConsumerState<ChecklistSuggestionsWidget> {
  Set<String> removedItems = <String>{};

  @override
  Widget build(BuildContext context) {
    final provider = checklistSuggestionsControllerProvider(id: widget.itemId);
    final notifier = ref.read(provider.notifier);
    final checklistItems = ref.watch(provider).valueOrNull;

    final suggestionsInferenceStatus = ref.watch(
      inferenceStatusControllerProvider(
        id: widget.itemId,
        aiResponseType: actionItemSuggestions,
      ),
    );

    final isRunning = suggestionsInferenceStatus == InferenceStatus.running;

    if (checklistItems == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        if (isRunning)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.messages.checklistSuggestionsRunning,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
              const SizedBox(width: 10),
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        if (!isRunning)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                checklistItems.isEmpty
                    ? context.messages.checklistNoSuggestionsTitle
                    : context.messages.checklistSuggestionsTitle,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.outline,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: context.colorScheme.outline,
                ),
                onPressed: () {
                  setState(() => removedItems = <String>{});
                  ref
                      .read(
                        actionItemSuggestionsControllerProvider(
                          id: widget.itemId,
                        ).notifier,
                      )
                      .getActionItemSuggestion();
                },
              ),
            ],
          ),
        if (!isRunning)
          ...checklistItems
              .where((item) => !removedItems.contains(item.title))
              .map(
                (checklistItem) => DragItemWidget(
                  dragItemProvider: (request) async {
                    final dragItem = DragItem(
                      localData: {
                        'checklistItemTitle': checklistItem.title,
                      },
                    )..add(Formats.plainText(checklistItem.title));
                    return dragItem;
                  },
                  allowedOperations: () => [DropOperation.move],
                  child: DraggableWidget(
                    child: Dismissible(
                      key: Key(checklistItem.title),
                      dismissThresholds: const {
                        DismissDirection.endToStart: 0.25,
                      },
                      onDismissed: (_) {
                        notifier.removeActionItem(title: checklistItem.title);
                        setState(() {
                          removedItems.add(checklistItem.title);
                        });
                      },
                      background: Container(
                        color: context.colorScheme.error,
                        height: double.infinity,
                        child: const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.delete, color: Colors.white),
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
                                  onPressed: () =>
                                      Navigator.of(context).pop(false),
                                  child: Text(
                                    context.messages.checklistItemDeleteCancel,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(context).pop(true),
                                  child: Text(
                                    context.messages.checklistItemDeleteConfirm,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                        return result ?? false;
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: ChecklistItemWidget(
                          title: checklistItem.title,
                          isChecked: checklistItem.isChecked,
                          onChanged: (checked) {},
                          showEditIcon: false,
                          readOnly: true,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        if (!isRunning && checklistItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              context.messages.checklistItemDrag,
              style: context.textTheme.bodySmall?.copyWith(
                color: context.colorScheme.outline,
                fontWeight: FontWeight.w100,
              ),
            ),
          ),
      ],
    );
  }
}
