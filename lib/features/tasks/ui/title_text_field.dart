import 'package:flutter/material.dart';
import 'package:lotti/features/tasks/ui/checklists/consts.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

typedef StringCallback = void Function(String?);

class TitleTextField extends StatefulWidget {
  const TitleTextField({
    required this.onSave,
    this.onCancel,
    this.focusNode,
    this.clearOnSave = false,
    this.resetToInitialValue = false,
    this.initialValue,
    this.semanticsLabel,
    this.hintText,
    this.onTapOutside,
    this.autofocus = false,
    super.key,
  });

  final String? initialValue;
  final StringCallback onSave;
  final VoidCallback? onCancel;
  final String? semanticsLabel;
  final bool clearOnSave;
  final bool resetToInitialValue;
  final bool autofocus;
  final FocusNode? focusNode;
  final String? hintText;
  final void Function(PointerDownEvent)? onTapOutside;

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
    final initialValue = widget.initialValue;

    void onSave(String? value) {
      widget.onSave(value ?? _controller.text);
      if (widget.clearOnSave) {
        _controller.clear();
      }
      setState(() {
        _showClearButton = widget.resetToInitialValue;
        _dirty = false;
      });
      widget.focusNode?.requestFocus();
    }

    void onCancel() {
      if (widget.resetToInitialValue && initialValue != null) {
        _controller.text = initialValue;
      } else {
        _controller.clear();
      }
      widget.onCancel?.call();
      setState(() {
        _showClearButton = widget.resetToInitialValue;
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
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onTapOutside: (data) {
        if (!_dirty) {
          widget.onTapOutside?.call(data);
        }
      },
      decoration: inputDecoration(
        labelText: widget.hintText ?? context.messages.checklistAddItem,
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
              duration: checklistActionIconFadeDuration,
              child: IconButton(
                icon: const Icon(
                  Icons.check_circle,
                  size: 30,
                  semanticLabel: 'save item',
                ),
                onPressed: () => onSave(_controller.text),
              ),
            ),
            if (widget.onCancel != null)
              AnimatedOpacity(
                curve: Curves.easeInOutQuint,
                opacity: _showClearButton ? 1.0 : 0.0,
                duration: checklistActionIconFadeDuration,
                child: IconButton(
                  icon: Icon(
                    Icons.cancel_outlined,
                    color: context.colorScheme.outline,
                    size: 30,
                    semanticLabel: 'discard changes',
                  ),
                  onPressed: onCancel,
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
