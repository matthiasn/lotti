import 'dart:convert';

import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/entry_text.dart';

Delta deltaFromController(QuillController controller) {
  return controller.document.toDelta();
}

EntryText entryTextFromController(QuillController controller) {
  Delta delta = deltaFromController(controller);
  String json = jsonEncode(delta.toJson());
  String markdown = deltaToMarkdown(json);

  return EntryText(
    plainText: controller.document.toPlainText(),
    markdown: markdown,
    quill: json,
  );
}

QuillController makeController({String? serializedQuill}) {
  QuillController controller = QuillController.basic();

  if (serializedQuill != null) {
    var editorJson = json.decode(serializedQuill);
    controller = QuillController(
        document: Document.fromJson(editorJson),
        selection: const TextSelection.collapsed(offset: 0));
  }
  return controller;
}
