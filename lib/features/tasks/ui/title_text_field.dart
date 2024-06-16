import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

typedef StringCallback = void Function(String);

class TitleTextField extends StatefulWidget {
  const TitleTextField({
    required this.onSave,
    this.semanticsLabel,
    super.key,
  });

  final StringCallback onSave;
  final String? semanticsLabel;

  @override
  State<TitleTextField> createState() => _TitleTextFieldState();
}

class _TitleTextFieldState extends State<TitleTextField> {
  final _controller = TextEditingController();
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    void onSave(String? value) {
      widget.onSave(value ?? _controller.text);
      setState(() => _isEditing = false);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 10,
      ),
      child: TextField(
        controller: _controller,
        onChanged: (value) {
          setState(() {
            _isEditing = value.isNotEmpty;
          });
        },
        decoration: inputDecoration(
          labelText: context.messages.checklistAddItem,
          semanticsLabel: widget.semanticsLabel,
          themeData: Theme.of(context),
        ).copyWith(
          floatingLabelBehavior: FloatingLabelBehavior.never,
          suffixIcon: AnimatedOpacity(
            curve: Curves.easeInOutQuint,
            opacity: _isEditing ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 400),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.check_circle,
                    size: 30,
                    semanticLabel: 'save item',
                  ),
                  onPressed: () => onSave(_controller.text),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 30,
                    semanticLabel: 'discard changes',
                  ),
                  onPressed: () {
                    _controller.clear();
                    setState(() => _isEditing = false);
                  },
                ),
              ],
            ),
          ),
        ),
        showCursor: true,
        minLines: 1,
        maxLines: 3,
        textInputAction: TextInputAction.done,
        onSubmitted: onSave,
      ),
    );
  }
}
