import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/utils/entry_utils.dart';

void main() {
  group('Entry utils', () {
    test('entryTextFromPlain returns null when provided a null value', () {
      expect(entryTextFromPlain(null), null);
    });

    test('entryTextFromPlain returns expected EntryText', () {
      expect(
        entryTextFromPlain('some entry text'),
        EntryText(
          plainText: 'some entry text\n',
          quill: r'[{"insert":"some entry text\n"}]',
          markdown: 'some entry text\n',
        ),
      );
    });
  });
}
