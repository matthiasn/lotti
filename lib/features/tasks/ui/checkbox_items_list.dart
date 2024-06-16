import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

class CheckboxItemsList extends StatefulWidget {
  const CheckboxItemsList({
    required this.itemIds,
    super.key,
  });

  final List<String> itemIds;

  @override
  State<CheckboxItemsList> createState() => _CheckboxItemsListState();
}

class _CheckboxItemsListState extends State<CheckboxItemsList> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Checklist'),
      subtitle: const LinearProgressIndicator(
        value: 0.87,
        semanticsLabel: 'Checklist progress',
      ),
      children: [
        TitleTextField(
          onSave: (title) {
            debugPrint('Saved: $title');
          },
          semanticsLabel: 'Add item to checklist',
        ),
        ...widget.itemIds.map(CheckboxItemWrapper.new),
      ],
    );
  }
}
