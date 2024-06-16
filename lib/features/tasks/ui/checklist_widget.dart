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
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: AnimatedCrossFade(
        duration: const Duration(milliseconds: 200),
        firstChild: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: TitleTextField(
            initialValue: 'Checklist',
            onSave: (title) {
              debugPrint('Saved: $title');
              setState(() {
                _isEditing = false;
              });
            },
            resetToInitialValue: true,
            onClear: () {
              setState(() {
                _isEditing = false;
              });
            },
          ),
        ),
        secondChild: Row(
          children: [
            const Text('Checklist'),
            IconButton(
              icon: const Icon(
                Icons.edit,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _isEditing = !_isEditing;
                });
              },
            ),
          ],
        ),
        crossFadeState:
            _isEditing ? CrossFadeState.showFirst : CrossFadeState.showSecond,
      ),
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
