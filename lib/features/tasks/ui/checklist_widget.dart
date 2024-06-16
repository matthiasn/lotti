import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

class ChecklistWidget extends StatefulWidget {
  const ChecklistWidget({
    required this.itemIds,
    super.key,
  });

  final List<String> itemIds;

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: const Text('Checklist'),
      subtitle: const LinearProgressIndicator(
        value: 0.87,
        semanticsLabel: 'Checklist progress',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          child: TitleTextField(
            onSave: (title) {
              debugPrint('Saved: $title');
            },
            clearOnSave: true,
            semanticsLabel: 'Add item to checklist',
          ),
        ),
        ...widget.itemIds.map(CheckboxItemWrapper.new),
      ],
    );
  }
}
