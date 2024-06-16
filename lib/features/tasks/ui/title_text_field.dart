import 'package:flutter/material.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

typedef StringCallback = void Function(String);

class TitleTextField extends StatefulWidget {
  const TitleTextField({
    required this.onSave,
    this.onClear,
    this.clearOnSave = false,
    this.initialValue,
    this.semanticsLabel,
    super.key,
  });

  final String? initialValue;
  final StringCallback onSave;
  final VoidCallback? onClear;
  final String? semanticsLabel;
  final bool clearOnSave;

  @override
  State<TitleTextField> createState() => _TitleTextFieldState();
}

class _TitleTextFieldState extends State<TitleTextField> {
  final _controller = TextEditingController();
  bool _showClearButton = false;
  bool _dirty = false;

  @override
  void initState() {
    _controller.text = widget.initialValue ?? '';
    if (widget.initialValue != null) {
      _showClearButton = true;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    void onSave(String? value) {
      widget.onSave(value ?? _controller.text);
      if (widget.clearOnSave) {
        _controller.clear();
      }
      setState(() {
        _showClearButton = false;
        _dirty = false;
      });
    }

    return TextField(
      controller: _controller,
      onChanged: (value) {
        setState(() {
          _dirty = value != widget.initialValue;
          _showClearButton = value != widget.initialValue;
        });
      },
      decoration: inputDecoration(
        labelText: context.messages.checklistAddItem,
        semanticsLabel: widget.semanticsLabel,
        themeData: Theme.of(context),
      ).copyWith(
        floatingLabelBehavior: FloatingLabelBehavior.never,
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AnimatedOpacity(
              curve: Curves.easeInOutQuint,
              opacity: _dirty ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  size: 30,
                  semanticLabel: 'save item',
                ),
                onPressed: () => onSave(_controller.text),
              ),
            ),
            AnimatedOpacity(
              curve: Curves.easeInOutQuint,
              opacity: _showClearButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 400),
              child: IconButton(
                icon: const Icon(
                  Icons.cancel_outlined,
                  size: 30,
                  semanticLabel: 'discard changes',
                ),
                onPressed: () {
                  _controller.clear();
                  widget.onClear?.call();
                  setState(() => _showClearButton = false);
                },
              ),
            ),
          ],
        ),
      ),
      showCursor: true,
      minLines: 1,
      maxLines: 3,
      textInputAction: TextInputAction.done,
      onSubmitted: onSave,
    );
  }
}
