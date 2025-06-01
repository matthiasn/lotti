import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A custom TextField widget that provides context menu support for copy/paste operations
/// and handles keyboard shortcuts properly
class CopyableTextField extends StatefulWidget {
  const CopyableTextField({
    required this.onChanged,
    required this.controller,
    required this.decoration,
    this.obscureText = false,
    this.maxLines = 1,
    this.keyboardType,
    super.key,
  });

  final ValueChanged<String>? onChanged;
  final TextEditingController controller;
  final InputDecoration decoration;
  final bool obscureText;
  final int? maxLines;
  final TextInputType? keyboardType;

  @override
  State<CopyableTextField> createState() => _CopyableTextFieldState();
}

class _CopyableTextFieldState extends State<CopyableTextField> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleCopy() {
    final selection = widget.controller.selection;
    if (selection.isValid) {
      final selectedText = selection.textInside(widget.controller.text);
      if (selectedText.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: selectedText));
      }
    } else {
      // Copy entire text if nothing is selected
      Clipboard.setData(ClipboardData(text: widget.controller.text));
    }
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      final text = widget.controller.text;
      final selection = widget.controller.selection;

      if (selection.isValid) {
        // Replace selected text
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          data.text!,
        );
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: selection.start + data.text!.length,
          ),
        );
      } else {
        // Insert at cursor position
        final cursorPosition = selection.baseOffset;
        final newText = text.substring(0, cursorPosition) +
            data.text! +
            text.substring(cursorPosition);
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: cursorPosition + data.text!.length,
          ),
        );
      }

      widget.onChanged?.call(widget.controller.text);
    }
  }

  void _handleCut() {
    final selection = widget.controller.selection;
    if (selection.isValid) {
      final selectedText = selection.textInside(widget.controller.text);
      if (selectedText.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: selectedText));
        final newText = widget.controller.text.replaceRange(
          selection.start,
          selection.end,
          '',
        );
        widget.controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start),
        );
        widget.onChanged?.call(widget.controller.text);
      }
    }
  }

  void _handleSelectAll() {
    widget.controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use CallbackShortcuts to avoid keyboard event conflicts
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true): _handleCopy,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            _handlePaste,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true): _handleCut,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            _handleSelectAll,
      },
      child: TextField(
        focusNode: _focusNode,
        controller: widget.controller,
        onChanged: widget.onChanged,
        decoration: widget.decoration,
        obscureText: widget.obscureText,
        maxLines: widget.maxLines,
        keyboardType: widget.keyboardType,
        contextMenuBuilder: (context, editableTextState) {
          final buttonItems = [
            ContextMenuButtonItem(
              label: 'Cut',
              onPressed: () {
                _handleCut();
                ContextMenuController.removeAny();
              },
            ),
            ContextMenuButtonItem(
              label: 'Copy',
              onPressed: () {
                _handleCopy();
                ContextMenuController.removeAny();
              },
            ),
            ContextMenuButtonItem(
              label: 'Paste',
              onPressed: () {
                _handlePaste();
                ContextMenuController.removeAny();
              },
            ),
            ContextMenuButtonItem(
              label: 'Select All',
              onPressed: () {
                _handleSelectAll();
                ContextMenuController.removeAny();
              },
            ),
          ];

          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: buttonItems,
          );
        },
      ),
    );
  }
}
