import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Handles clipboard operations for text editing
class ClipboardHandler {
  ClipboardHandler(this.controller);

  final TextEditingController controller;

  /// Copies selected text or entire text if nothing is selected
  void copy() {
    final selection = controller.selection;
    if (selection.isValid && selection.start != selection.end) {
      final selectedText = selection.textInside(controller.text);
      if (selectedText.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: selectedText));
      }
    } else {
      // Copy entire text if nothing is selected
      Clipboard.setData(ClipboardData(text: controller.text));
    }
  }

  /// Pastes clipboard content at cursor position or replaces selected text
  Future<void> paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasteText = data?.text;
    if (pasteText != null) {
      final text = controller.text;
      final selection = controller.selection;

      if (selection.isValid && selection.start != selection.end) {
        // Replace selected text
        final newText = text.replaceRange(
          selection.start,
          selection.end,
          pasteText,
        );
        final newCursorPosition = selection.start + pasteText.length;
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: newCursorPosition),
        );
      } else {
        // Insert at cursor position
        final cursorPosition =
            selection.isValid ? selection.baseOffset : text.length;
        final newText = text.substring(0, cursorPosition) +
            pasteText +
            text.substring(cursorPosition);
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(
            offset: cursorPosition + pasteText.length,
          ),
        );
      }
    }
  }

  /// Cuts selected text to clipboard
  void cut() {
    final selection = controller.selection;
    if (selection.isValid && selection.start != selection.end) {
      final selectedText = selection.textInside(controller.text);
      if (selectedText.isNotEmpty) {
        Clipboard.setData(ClipboardData(text: selectedText));
        final newText = controller.text.replaceRange(
          selection.start,
          selection.end,
          '',
        );
        controller.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: selection.start),
        );
      }
    }
  }

  /// Selects all text
  void selectAll() {
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }
}

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
  late final ClipboardHandler _clipboardHandler;

  @override
  void initState() {
    super.initState();
    _clipboardHandler = ClipboardHandler(widget.controller);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _handlePasteWithCallback() async {
    await _clipboardHandler.paste();
    widget.onChanged?.call(widget.controller.text);
  }

  void _handleCutWithCallback() {
    _clipboardHandler.cut();
    widget.onChanged?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    // Use CallbackShortcuts to avoid keyboard event conflicts
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyC, meta: true):
            _clipboardHandler.copy,
        const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
            _handlePasteWithCallback,
        const SingleActivator(LogicalKeyboardKey.keyX, meta: true):
            _handleCutWithCallback,
        const SingleActivator(LogicalKeyboardKey.keyA, meta: true):
            _clipboardHandler.selectAll,
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
                _handleCutWithCallback();
                ContextMenuController.removeAny();
              },
            ),
            ContextMenuButtonItem(
              label: 'Copy',
              onPressed: () {
                _clipboardHandler.copy();
                ContextMenuController.removeAny();
              },
            ),
            ContextMenuButtonItem(
              label: 'Paste',
              onPressed: () {
                _handlePasteWithCallback();
                ContextMenuController.removeAny();
              },
            ),
            ContextMenuButtonItem(
              label: 'Select All',
              onPressed: () {
                _clipboardHandler.selectAll();
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
