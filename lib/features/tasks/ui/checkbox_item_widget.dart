import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/consts.dart';
import 'package:lotti/features/tasks/ui/title_text_field.dart';

// ignore: avoid_positional_boolean_parameters
typedef BoolCallback = void Function(bool);

class CheckboxItemWidget extends StatefulWidget {
  const CheckboxItemWidget({
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.onDelete,
    this.onTitleChange,
    this.onEdit,
    super.key,
  });

  final String title;
  final bool isChecked;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final StringCallback? onTitleChange;

  @override
  State<CheckboxItemWidget> createState() => _CheckboxItemWidgetState();
}

class _CheckboxItemWidgetState extends State<CheckboxItemWidget> {
  late bool _isChecked;
  bool _isEditing = false;

  @override
  void initState() {
    _isChecked = widget.isChecked;
    super.initState();
  }

  @override
  void didUpdateWidget(CheckboxItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isChecked != widget.isChecked) {
      setState(() {
        _isChecked = widget.isChecked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
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
              if (widget.onDelete != null)
                IconButton(
                  icon: const Icon(
                    Icons.delete_forever_rounded,
                    size: 20,
                  ),
                  onPressed: widget.onDelete,
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
      onChanged: (bool? value) {
        final isChecked = value ?? false;
        setState(() {
          _isChecked = isChecked;
        });

        widget.onChanged(isChecked);
      },
    );
  }
}
