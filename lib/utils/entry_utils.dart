import 'package:lotti/classes/entry_text.dart';

EntryText? entryTextFromPlain(String? plain) {
  if (plain == null) {
    return null;
  }

  return EntryText(
    plainText: '$plain\n',
    quill: '[{"insert":"$plain\\n"}]',
    markdown: '$plain\n',
  );
}
