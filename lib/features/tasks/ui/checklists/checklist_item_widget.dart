import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

// ignore: avoid_positional_boolean_parameters
typedef BoolCallback = void Function(bool);

class ChecklistItemWidget extends StatefulWidget {
  const ChecklistItemWidget({
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.onDelete,
    this.onTitleChange,
    this.showEditIcon = true,
    this.readOnly = false,
    this.onEdit,
    super.key,
  });

  final String title;
  final bool readOnly;
  final bool isChecked;
  final bool showEditIcon;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final StringCallback? onTitleChange;

  @override
  State<ChecklistItemWidget> createState() => _ChecklistItemWidgetState();
}

class _ChecklistItemWidgetState extends State<ChecklistItemWidget> {
  late bool _isChecked;
  bool _isEditing = false;

  @override
  void initState() {
    _isChecked = widget.isChecked;
    super.initState();
  }

  @override
  void didUpdateWidget(ChecklistItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isChecked != widget.isChecked) {
      setState(() {
        _isChecked = widget.isChecked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        listTileTheme: Theme.of(context).listTileTheme.copyWith(
              dense: true,
              minVerticalPadding: 0,
              minTileHeight: 0,
            ),
      ),
      child: CheckboxListTile(
        title: AnimatedCrossFade(
          duration: checklistCrossFadeDuration,
          firstChild: TitleTextField(
            initialValue: widget.title,
            onSave: (title) {
              setState(() {
                _isEditing = false;
              });
              widget.onTitleChange?.call(title);
            },
            resetToInitialValue: true,
            onClear: () {
              setState(() {
                _isEditing = false;
              });
            },
          ),
          secondChild: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.title,
                    softWrap: true,
                    maxLines: 3,
                  ),
                ),
                if (widget.showEditIcon)
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
          ),
          crossFadeState:
              _isEditing ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        ),
        value: _isChecked,
        controlAffinity: ListTileControlAffinity.leading,
        secondary: widget.onEdit != null
            ? IconButton(
                icon: const Icon(
                  Icons.edit,
                  size: 20,
                ),
                onPressed: widget.onEdit,
              )
            : null,
        onChanged: widget.readOnly
            ? null
            : (bool? value) {
                final isChecked = value ?? false;
                setState(() {
                  _isChecked = isChecked;
                });

                widget.onChanged(isChecked);
              },
      ),
    );
  }
}
