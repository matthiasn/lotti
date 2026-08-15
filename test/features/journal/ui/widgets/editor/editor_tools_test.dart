// Flutter Quill marks its clipboard test seam experimental. These tests use it
// deliberately to exercise the real paste precedence end to end.
// ignore_for_file: cascade_invocations, experimental_member_use

import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill/src/editor_toolbar_controller_shared/clipboard/clipboard_service.dart';
import 'package:flutter_quill/src/editor_toolbar_controller_shared/clipboard/clipboard_service_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';

class _TestRichClipboardService extends ClipboardService {
  _TestRichClipboardService({this.htmlText});

  final String? htmlText;

  @override
  Future<void> copyImage(Uint8List imageBytes) async {}

  @override
  Future<Uint8List?> getGifFile() async => null;

  @override
  Future<String?> getHtmlFile() async => null;

  @override
  Future<String?> getHtmlText() async => htmlText;

  @override
  Future<Uint8List?> getImageFile() async => null;

  @override
  Future<String?> getMarkdownFile() async => null;
}

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

    test('wires Markdown conversion only when explicitly enabled', () async {
      final controller = makeController(markdownPasteEnabled: true);
      final clipboardConfig = controller.config.clipboardConfig;

      expect(clipboardConfig, isNotNull);
      expect(clipboardConfig!.enableExternalRichPaste, isTrue);

      final replacement = await clipboardConfig.onPlainTextPaste!(
        '# Pasted title',
      );

      expect(replacement, isEmpty);
      expect(controller.document.toPlainText(), 'Pasted title\n\n');
      expect(
        controller.document.toDelta().toList()[1].attributes,
        containsPair('header', 1),
      );
    });
  });

  group('Markdown paste', () {
    final markdown =
        '''
# Title
## Section
### Details

This is **bold** and `lib/features/journal/editor.dart`.

> Quoted from AFFiNE

---

- Bullet
1. Ordered

Done ✅'''
            .trimLeft();

    test('detects supported Markdown without claiming ordinary text', () {
      const markdownCases = [
        '# Heading',
        '###### Compact heading',
        'A **bold** word',
        'Use `code` here',
        '> Quote',
        '---',
        '- Bullet',
        '1. Ordered',
      ];
      const plainTextCases = [
        'A normal sentence.',
        'C# is a language.',
        'The result is 1 * 2.',
        'A hashtag #withoutSpace stays plain.',
        'Emoji survives ✅',
      ];

      for (final value in markdownCases) {
        expect(
          containsMarkdownFormatting(value),
          isTrue,
          reason: value,
        );
      }
      for (final value in plainTextCases) {
        expect(
          containsMarkdownFormatting(value),
          isFalse,
          reason: value,
        );
      }
    });

    test('converts AFFiNE-style Markdown into Quill formatting', () {
      final delta = markdownDeltaForPaste(markdown)!;
      final operations = delta.toList();

      bool hasTextAttribute(String text, String attribute, Object value) =>
          operations.any(
            (operation) =>
                operation.value == text &&
                operation.attributes?[attribute] == value,
          );
      bool hasNewlineAttribute(String attribute, Object value) =>
          operations.any(
            (operation) =>
                operation.value == '\n' &&
                operation.attributes?[attribute] == value,
          );

      expect(hasNewlineAttribute('header', 1), isTrue);
      expect(hasNewlineAttribute('header', 2), isTrue);
      expect(hasNewlineAttribute('header', 3), isTrue);
      expect(hasTextAttribute('bold', 'bold', true), isTrue);
      expect(
        hasTextAttribute('lib/features/journal/editor.dart', 'code', true),
        isTrue,
      );
      expect(hasNewlineAttribute('blockquote', true), isTrue);
      expect(hasNewlineAttribute('list', 'bullet'), isTrue);
      expect(hasNewlineAttribute('list', 'ordered'), isTrue);
      expect(
        operations.any(
          (operation) =>
              operation.data is Map<String, dynamic> &&
              (operation.data! as Map<String, dynamic>)['divider'] == 'hr',
        ),
        isTrue,
      );

      final document = Document.fromDelta(delta);
      expect(document.toPlainText(), contains('Done ✅'));
      expect(document.toPlainText(), isNot(contains('**bold**')));
      expect(document.toPlainText(), isNot(contains('`lib/features')));
    });

    test('replaces the current selection with converted Markdown', () {
      final controller = QuillController(
        document: Document.fromDelta(
          Delta()..insert('before selected after\n'),
        ),
        selection: const TextSelection(baseOffset: 7, extentOffset: 15),
      );

      final replacement = handlePlainTextMarkdownPaste(
        controller,
        '**bold**',
      );

      expect(replacement, isEmpty);
      expect(controller.document.toPlainText(), 'before bold after\n');
      expect(
        controller.document.toDelta().toList().any(
          (operation) =>
              operation.value == 'bold' &&
              operation.attributes?['bold'] == true,
        ),
        isTrue,
      );
      expect(
        controller.selection,
        const TextSelection.collapsed(offset: 11),
      );
    });

    test('removes only a synthetic unformatted terminal newline', () {
      final inlineDelta = markdownDeltaForPaste('**bold**')!;
      final explicitNewlineDelta = markdownDeltaForPaste('**bold**\n')!;
      final headingDelta = markdownDeltaForPaste('# Heading')!;
      final horizontalRuleDelta = markdownDeltaForPaste('---')!;

      expect(inlineDelta.toList().last.value, 'bold');
      expect(explicitNewlineDelta.toList().last.value, '\n');
      expect(headingDelta.toList().last.value, '\n');
      expect(
        headingDelta.toList().last.attributes,
        containsPair('header', 1),
      );
      expect(
        horizontalRuleDelta.toList().any(
          (operation) =>
              operation.data is Map<String, dynamic> &&
              (operation.data! as Map<String, dynamic>)['divider'] == 'hr',
        ),
        isTrue,
      );
    });

    test('preserves interior whitespace and trims one code-span pad', () {
      final delta = markdownDeltaForPaste(
        'Use `alpha  beta\tgamma` and ` padded `.',
      )!;
      final codeValues = delta
          .toList()
          .where((operation) => operation.attributes?['code'] == true)
          .map((operation) => operation.value)
          .toList();

      expect(codeValues, ['alpha  beta\tgamma', 'padded']);
    });

    test('converts ATX heading levels four through six as headings', () {
      for (var level = 4; level <= 6; level++) {
        final marker = List.filled(level, '#').join();
        final delta = markdownDeltaForPaste('$marker Details')!;

        expect(delta.toList().last.value, '\n');
        expect(
          delta.toList().last.attributes,
          containsPair('header', 3),
          reason: 'ATX level $level uses Quill’s smallest heading style',
        );
      }
    });

    test('does not normalize heading markers inside fenced code', () {
      final delta = markdownDeltaForPaste('```\n#### literal code\n```')!;

      expect(
        Document.fromDelta(delta).toPlainText(),
        contains('#### literal code'),
      );
    });

    test('allows shorter backtick runs inside longer code spans', () {
      final delta = markdownDeltaForPaste('Use ``a ` b`` here')!;
      final operations = delta.toList();

      expect(
        operations.any(
          (operation) =>
              operation.value == 'a ` b' &&
              operation.attributes?['code'] == true,
        ),
        isTrue,
      );
      expect(
        operations
            .map((operation) => operation.value)
            .whereType<String>()
            .join(),
        isNot(contains('``')),
      );
    });

    test('leaves genuinely plain text to Quill unchanged', () {
      final controller = makeController(markdownPasteEnabled: true);

      final replacement = handlePlainTextMarkdownPaste(
        controller,
        'A normal pasted sentence. ✅',
      );

      expect(replacement, isNull);
      expect(controller.document.toPlainText(), '\n');
      expect(markdownDeltaForPaste('A normal pasted sentence. ✅'), isNull);
    });

    test('clipboardPaste converts Markdown carried as text/plain', () async {
      ClipboardServiceProvider.setInstance(_TestRichClipboardService());
      addTearDown(ClipboardServiceProvider.setInstanceToDefault);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': '# Clipboard heading'};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final controller = makeController(markdownPasteEnabled: true);

      final handled = await controller.clipboardPaste();

      expect(handled, isTrue);
      expect(controller.document.toPlainText(), 'Clipboard heading\n\n');
      expect(
        controller.document.toDelta().toList()[1].attributes,
        containsPair('header', 1),
      );
    });

    test('clipboardPaste keeps ordinary text unchanged', () async {
      const plainText = 'An ordinary clipboard sentence. ✅';
      ClipboardServiceProvider.setInstance(_TestRichClipboardService());
      addTearDown(ClipboardServiceProvider.setInstanceToDefault);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.getData') {
          return <String, dynamic>{'text': plainText};
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final controller = makeController(markdownPasteEnabled: true);

      final handled = await controller.clipboardPaste();

      expect(handled, isTrue);
      expect(controller.document.toPlainText(), '$plainText\n');
      expect(
        controller.document.toDelta().toList(),
        hasLength(1),
      );
      expect(controller.document.toDelta().toList().single.attributes, isNull);
    });

    test(
      'clipboardPaste keeps HTML ahead of the plain-text fallback',
      () async {
        ClipboardServiceProvider.setInstance(
          _TestRichClipboardService(
            htmlText: '<p><strong>HTML wins</strong></p>',
          ),
        );
        addTearDown(ClipboardServiceProvider.setInstanceToDefault);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        messenger.setMockMethodCallHandler(SystemChannels.platform, (
          call,
        ) async {
          if (call.method == 'Clipboard.getData') {
            return <String, dynamic>{'text': '# Markdown fallback'};
          }
          return null;
        });
        addTearDown(
          () =>
              messenger.setMockMethodCallHandler(SystemChannels.platform, null),
        );
        final controller = makeController(markdownPasteEnabled: true);

        final handled = await controller.clipboardPaste();

        expect(handled, isTrue);
        expect(controller.document.toPlainText(), contains('HTML wins'));
        expect(controller.document.toPlainText(), isNot(contains('Markdown')));
        expect(
          controller.document.toDelta().toList().any(
            (operation) =>
                operation.value == 'HTML wins' &&
                operation.attributes?['bold'] == true,
          ),
          isTrue,
        );
      },
    );
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
