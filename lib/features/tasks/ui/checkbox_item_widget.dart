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
    this.onTitleChange,
    this.onEdit,
    super.key,
  });

  final String title;
  final bool isChecked;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;
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
  Widget build(BuildContext context) {
    return CheckboxListTile(
      title: GestureDetector(
        onTap: () {
          setState(() {
            _isEditing = true;
          });
        },
        child: AnimatedCrossFade(
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
            child: Text(widget.title),
          ),
          crossFadeState:
              _isEditing ? CrossFadeState.showFirst : CrossFadeState.showSecond,
        ),
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
        setState(() {
          _isChecked = value ?? false;
        });
        widget.onChanged(_isChecked);
      },
    );
  }
}
