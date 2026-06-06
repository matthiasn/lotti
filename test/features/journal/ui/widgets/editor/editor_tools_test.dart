import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

  group('makeController', () {
    test('returns a basic controller for null or empty quill', () {
      expect(makeController().document.toPlainText(), '\n');
      // The '[]' guard branch: treated as empty, not parsed.
      expect(
        makeController(serializedQuill: '[]').document.toPlainText(),
        '\n',
      );
    });

    test('deserializes quill JSON and applies the given selection', () {
      const quill = r'[{"insert":"Hello world\n"}]';
      final controller = makeController(
        serializedQuill: quill,
        selection: const TextSelection.collapsed(offset: 5),
      );

      expect(controller.document.toPlainText(), 'Hello world\n');
      expect(controller.selection, const TextSelection.collapsed(offset: 5));
    });
  });

  group('entryTextFromController', () {
    test('produces consistent plainText, markdown, and quill fields', () {
      final controller = makeController(
        serializedQuill: r'[{"insert":"Hello world\n"}]',
      );

      final entryText = entryTextFromController(controller);

      expect(entryText.plainText, 'Hello world\n');
      expect(entryText.markdown, 'Hello world\n');
      expect(entryText.quill, r'[{"insert":"Hello world\n"}]');
    });
  });

  group('round-trip properties', () {
    /// Deterministic plain-text fragments — newline-terminated documents as
    /// Quill requires.
    String docText(int seed) {
      const fragments = [
        'hello',
        'world',
        'line one',
        'Ünïcode',
        'a "quoted" bit',
        r'back\slash',
        'tabs\tinside',
      ];
      final length = (seed % 3) + 1;
      final parts = [
        for (var i = 0; i < length; i++)
          fragments[(seed >> (2 * i)) % fragments.length],
      ];
      return '${parts.join(' ')}\n';
    }

    glados.Glados<int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'serialize → makeController → re-serialize is the identity',
      (seed) {
        final original = QuillController(
          document: Document.fromDelta(Delta()..insert(docText(seed))),
          selection: const TextSelection.collapsed(offset: 0),
        );
        final encoded = quillJsonFromDelta(deltaFromController(original));

        final decoded = makeController(serializedQuill: encoded);
        final reEncoded = quillJsonFromDelta(deltaFromController(decoded));

        expect(reEncoded, encoded, reason: 'seed=$seed text=${docText(seed)}');
        expect(
          decoded.document.toPlainText(),
          original.document.toPlainText(),
        );
      },
      tags: 'glados',
    );

    glados.Glados2<int, int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.IntAnys(glados.any).intInRange(0, 64),
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'insertDividerEmbed always lands the caret after the embed with '
      'keyboard skipping reset',
      (seed, cursorSeed) {
        final text = docText(seed);
        final cursor = cursorSeed % text.length;
        final controller = QuillController(
          document: Document.fromDelta(Delta()..insert(text)),
          selection: TextSelection.collapsed(offset: cursor),
        );

        insertDividerEmbed(controller);

        expect(
          controller.selection,
          TextSelection.collapsed(offset: cursor + 1),
          reason: 'seed=$seed cursor=$cursor',
        );
        expect(controller.skipRequestKeyboard, isFalse);
        // The embed's object-replacement char is present at the cursor spot.
        expect(
          controller.document.toPlainText().codeUnitAt(cursor),
          0xFFFC,
          reason: 'seed=$seed cursor=$cursor',
        );
      },
      tags: 'glados',
    );

    glados.Glados<int>(
      glados.IntAnys(glados.any).intInRange(0, 1 << 12),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'entryTextFromController is total for generated documents',
      (seed) {
        final controller = QuillController(
          document: Document.fromDelta(Delta()..insert(docText(seed))),
          selection: const TextSelection.collapsed(offset: 0),
        );

        final entryText = entryTextFromController(controller);

        expect(entryText.plainText, isNotNull);
        expect(entryText.plainText, controller.document.toPlainText());
        expect(entryText.markdown, isNotEmpty);
        expect(entryText.quill, isNotEmpty);
      },
      tags: 'glados',
    );
  });
}
