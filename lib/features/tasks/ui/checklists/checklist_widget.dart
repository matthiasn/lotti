import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/checklist_item_wrapper.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/colors.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:tinycolor2/tinycolor2.dart';

class ChecklistWidget extends StatefulWidget {
  const ChecklistWidget({
    required this.title,
    required this.itemIds,
    required this.onTitleSave,
    required this.onCreateChecklistItem,
    required this.completionRate,
    required this.id,
    required this.updateItemOrder,
    this.onDelete,
    super.key,
  });

  final String id;
  final String title;
  final List<String> itemIds;
  final StringCallback onTitleSave;
  final Future<String?> Function(String?) onCreateChecklistItem;
  final Future<void> Function(List<String> linkedChecklistItems)
      updateItemOrder;
  final double completionRate;
  final VoidCallback? onDelete;

  @override
  State<ChecklistWidget> createState() => _ChecklistWidgetState();
}

class _ChecklistWidgetState extends State<ChecklistWidget> {
  bool _isEditing = false;
  late List<String> _itemIds;

  @override
  void initState() {
    super.initState();
    _itemIds = widget.itemIds;
  }

  @override
  void didUpdateWidget(ChecklistWidget oldWidget) {
    if (oldWidget.itemIds != widget.itemIds) {
      setState(() {
        _itemIds = widget.itemIds;
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      maintainState: true,
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
      children: [
        Row(
          children: [
            const SizedBox(width: 20),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  color: successColor,
                  backgroundColor: successColor.desaturate().withAlpha(77),
                  value: widget.completionRate,
                  semanticsLabel: 'Checklist progress',
                ),
              ),
            ),
            if (_isEditing)
              IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(
                  MdiIcons.trashCanOutline,
                  size: 20,
                  color: context.colorScheme.outline,
                ),
                onPressed: () async {
                  final result = await showDialog<bool>(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: Text(context.messages.checklistDelete),
                        content: Text(
                          context.messages.checklistItemDeleteWarning,
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: Text(
                              context.messages.checklistItemDeleteCancel,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: Text(
                              context.messages.checklistItemDeleteConfirm,
                            ),
                          ),
                        ],
                      );
                    },
                  );
                  if (result ?? false) {
                    widget.onDelete?.call();
                  }
                },
              ),
            const SizedBox(width: 15),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 10,
          ),
          child: TitleTextField(
            onSave: (title) async {
              final id = await widget.onCreateChecklistItem.call(title);
              setState(() {
                if (id != null) {
                  _itemIds = [..._itemIds, id];
                }
              });
            },
            clearOnSave: true,
            semanticsLabel: 'Add item to checklist',
          ),
        ),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: _isEditing,
          onReorder: (int oldIndex, int newIndex) {
            final itemIds = [..._itemIds];
            final movedItem = itemIds.removeAt(oldIndex);
            final insertionIndex =
                newIndex > oldIndex ? newIndex - 1 : newIndex;
            itemIds.insert(insertionIndex, movedItem);
            setState(() {
              _itemIds = itemIds;
            });

            widget.updateItemOrder(itemIds);
          },
          children: List.generate(
            _itemIds.length,
            (int index) {
              final itemId = _itemIds.elementAt(index);
              return ChecklistItemWrapper(
                itemId,
                checklistId: widget.id,
                key: Key('$itemId${widget.id}$index'),
              );
            },
          ),
        ),
      ],
    );
  }
}
