import 'dart:convert';
import 'dart:math' as math;

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:lotti/classes/entry_text.dart';

Delta deltaFromController(QuillController controller) {
  return controller.document.toDelta();
}

String quillJsonFromDelta(Delta delta) {
  return jsonEncode(delta.toJson());
}

EntryText entryTextFromController(QuillController controller) {
  final delta = deltaFromController(controller);
  final json = quillJsonFromDelta(delta);
  final markdown = deltaToMarkdown(json);

  return EntryText(
    plainText: controller.document.toPlainText(),
    markdown: markdown,
    quill: json,
  );
}

QuillController makeController({
  String? serializedQuill,
  TextSelection? selection,
}) {
  var controller = QuillController.basic();

  if (serializedQuill != null && serializedQuill != '[]') {
    final editorJson = json.decode(serializedQuill) as List<dynamic>;
    controller = QuillController(
      document: Document.fromJson(editorJson),
      selection: selection ?? const TextSelection.collapsed(offset: 0),
    );
  }
  return controller;
}

/// Inserts a Quill `divider` embed at the current selection.
///
/// The function preserves editor focus by toggling [QuillController.skipRequestKeyboard]
/// during the mutation, replaces any currently selected text with the divider,
/// and moves the caret directly after the inserted embed so users can continue typing.
void insertDividerEmbed(QuillController controller) {
  final selection = controller.selection;
  final index = math.min(selection.baseOffset, selection.extentOffset);
  final length = (selection.baseOffset - selection.extentOffset).abs();

  controller
    ..skipRequestKeyboard = true
    ..replaceText(
      index,
      length,
      const BlockEmbed('divider', 'hr'),
      null,
    )
    ..moveCursorToPosition(index + 1)
    ..skipRequestKeyboard = false;
}
