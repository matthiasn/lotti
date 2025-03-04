import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_widget.dart';

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
        const Text('Drag into checklist to add items'),
        const SizedBox(height: 10),
        ...checklistItems.map(
          (checklistItem) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ChecklistItemWidget(
              title: checklistItem.title,
              isChecked: checklistItem.isChecked,
              onChanged: (checked) {},
              showEditIcon: false,
            ),
          ),
        ),
      ],
    );
  }
}
