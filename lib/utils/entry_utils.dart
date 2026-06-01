import 'dart:convert';

import 'package:lotti/classes/entry_text.dart';

EntryText? entryTextFromPlain(String? plain) {
  if (plain == null) {
    return null;
  }

  final plainText = '$plain\n';
  return EntryText(
    plainText: plainText,
    quill: jsonEncode([
      {'insert': plainText},
    ]),
    markdown: plainText,
  );
}
