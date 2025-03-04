import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class ChecklistSuggestionsWidget extends ConsumerWidget {
  const ChecklistSuggestionsWidget({
    required this.itemId,
    super.key,
  });

  final String itemId;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final checklistItems = ref
        .watch(
          checklistItemSuggestionsControllerProvider(id: itemId),
        )
        .valueOrNull;

    if (checklistItems == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 20),
        Text(
          context.messages.checklistItemDrag,
          style: context.textTheme.titleSmall?.copyWith(
            color: context.colorScheme.outline,
          ),
        ),
        const SizedBox(height: 10),
        ...checklistItems.map(
          (checklistItem) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: DragItemWidget(
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
      ],
    );
  }
}
