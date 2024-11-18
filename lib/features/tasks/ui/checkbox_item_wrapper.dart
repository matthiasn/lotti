import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/checklist_item_controller.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_widget.dart';

class CheckboxItemWrapper extends ConsumerWidget {
  const CheckboxItemWrapper(
    this.itemId, {
    super.key,
  });

  final String itemId;

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
        if (item == null) {
          return const SizedBox.shrink();
        }
        return CheckboxItemWidget(
          title: item.data.title,
          isChecked: item.data.isChecked,
          onChanged: (_) => ref.read(provider.notifier).toggleChecked(),
          onTitleChange: ref.read(provider.notifier).updateTitle,
        );
      },
      error: ErrorWidget.new,
      loading: (_) => const SizedBox.shrink(),
    );
  }
}
