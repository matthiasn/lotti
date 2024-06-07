import 'package:flutter/material.dart';

// ignore: avoid_positional_boolean_parameters
typedef BoolCallback = void Function(bool);

class CheckboxItemWidget extends StatefulWidget {
  const CheckboxItemWidget({
    required this.title,
    required this.isChecked,
    required this.onChanged,
    this.onEdit,
    super.key,
  });

  final String title;
  final bool isChecked;
  final BoolCallback onChanged;
  final VoidCallback? onEdit;

  @override
  State<CheckboxItemWidget> createState() => _CheckboxItemWidgetState();
}

class _CheckboxItemWidgetState extends State<CheckboxItemWidget> {
  late bool _isChecked;

  @override
  void initState() {
    _isChecked = widget.isChecked;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
        horizontal: 10,
      ),
      child: CheckboxListTile(
        title: Text(widget.title),
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
      ),
    );
  }
}
