import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/tasks/state/checklist_controller.dart';
import 'package:lotti/features/tasks/ui/checkbox_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/themes/colors.dart';
import 'package:tinycolor2/tinycolor2.dart';

class ChecklistWidget extends StatefulWidget {
  const ChecklistWidget({
    required this.title,
    required this.itemIds,
    required this.onTitleSave,
    required this.onCreateChecklistItem,
    required this.completionRate,
    required this.id, super.key,
  });

  final String id;
  final String title;
  final List<String> itemIds;
  final StringCallback onTitleSave;
  final StringCallback onCreateChecklistItem;
  final double completionRate;

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: ValueKey('${widget.id} ${widget.completionRate}'),
      initiallyExpanded: widget.completionRate < 1,
      title: AnimatedCrossFade(
        duration: checklistCrossFadeDuration,
        firstChild: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: TitleTextField(
            initialValue: widget.title,
            onSave: (title) {
              widget.onTitleSave.call(title);
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
            Flexible(
              child: Text(
                widget.title,
                softWrap: true,
                maxLines: 3,
              ),
            ),
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
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            minHeight: 5,
            color: successColor,
            backgroundColor: successColor.desaturate().withOpacity(0.3),
            value: widget.completionRate,
            semanticsLabel: 'Checklist progress',
          ),
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          child: TitleTextField(
            onSave: (title) {
              widget.onCreateChecklistItem.call(title);
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

    final completionRate =
        ref.watch(checklistCompletionControllerProvider(id: entryId)).value;

    if (checklist == null || completionRate == null) {
      return const SizedBox.shrink();
    }

    return ChecklistWidget(
      id: checklist.id,
      title: checklist.data.title,
      itemIds: checklist.data.linkedChecklistItems,
      onTitleSave: notifier.updateTitle,
      onCreateChecklistItem: notifier.createChecklistItem,
      completionRate: completionRate,
    );
  }
}
