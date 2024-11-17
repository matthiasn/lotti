import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

class ChecklistWidget extends StatefulWidget {
  const ChecklistWidget({
    required this.title,
    required this.itemIds,
    this.onTitleSave,
    super.key,
  });

  final String title;
  final List<String> itemIds;
  final StringCallback? onTitleSave;

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      title: AnimatedCrossFade(
        duration: checklistCrossFadeDuration,
        firstChild: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: TitleTextField(
            initialValue: widget.title,
            onSave: (title) {
              widget.onTitleSave?.call(title);
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
            Text(widget.title),
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
              widget.onTitleSave?.call(title);
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

class ChecklistWrapper extends ConsumerWidget {
  const ChecklistWrapper({
    required this.entryId,
    super.key,
  });

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = checklistControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final checklist = ref.watch(provider).value;

    if (checklist == null) {
      return const SizedBox.shrink();
    }

    return ChecklistWidget(
      title: checklist.data.title,
      itemIds: checklist.data.linkedChecklistItems,
      onTitleSave: notifier.updateTitle,
    );
  }
}
