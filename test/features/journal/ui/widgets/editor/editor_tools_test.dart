import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';

void main() {
  group('insertDividerEmbed', () {
    test('inserts divider at collapsed cursor', () {
      final controller = QuillController(
        document: Document.fromDelta(
          Delta()..insert('Hello\n'),
        ),
        selection: const TextSelection.collapsed(offset: 5),
      );

      insertDividerEmbed(controller);

      final operations = controller.document.toDelta().toList();
      expect(operations[0].value, equals('Hello'));
      expect(operations[1].data, equals({'divider': 'hr'}));
      expect(operations[2].value, equals('\n'));
      expect(controller.selection, const TextSelection.collapsed(offset: 6));
      expect(controller.skipRequestKeyboard, isFalse);
    });

    test('replaces selected text with divider', () {
      final controller = QuillController(
        document: Document.fromDelta(
          Delta()..insert('Hello\n'),
        ),
        selection: const TextSelection(baseOffset: 0, extentOffset: 5),
      );

      insertDividerEmbed(controller);

      final operations = controller.document.toDelta().toList();
      expect(operations[0].data, equals({'divider': 'hr'}));
      expect(operations[1].value, equals('\n'));
      expect(controller.selection, const TextSelection.collapsed(offset: 1));
      // \u{fffc} is the object replacement character used by Quill to mark embeds.
      expect(controller.document.toPlainText(), equals('\u{fffc}\n'));
      expect(controller.skipRequestKeyboard, isFalse);
    });
  });
}
