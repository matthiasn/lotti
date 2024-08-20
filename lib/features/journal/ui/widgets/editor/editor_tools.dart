import 'dart:convert';

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
