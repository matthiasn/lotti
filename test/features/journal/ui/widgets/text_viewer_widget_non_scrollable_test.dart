import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/journal/ui/widgets/editor/embed_builders.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget_non_scrollable.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpViewer(
    WidgetTester tester, {
    required EntryText? entryText,
    double maxHeight = 200,
  }) async {
    await tester.pumpWidget(
      makeTestableWidget(
        TextViewerWidgetNonScrollable(
          entryText: entryText,
          maxHeight: maxHeight,
        ),
      ),
    );
    await tester.pump();
  }

  QuillController editorController(WidgetTester tester) =>
      tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

  String editorText(WidgetTester tester) =>
      editorController(tester).document.toPlainText();

  group('TextViewerWidgetNonScrollable', () {
    testWidgets('renders an empty document for null entryText', (
      tester,
    ) async {
      await pumpViewer(tester, entryText: null);

      expect(editorText(tester).trim(), isEmpty);
    });

    testWidgets('renders an empty document for empty plainText', (
      tester,
    ) async {
      await pumpViewer(tester, entryText: const EntryText(plainText: ''));

      expect(editorText(tester).trim(), isEmpty);
    });

    group('content prioritization', () {
      // quill > markdown > plainText — assert what actually lands in the
      // rendered document, not just that an editor exists.
      for (final (label, entryText, mustContain, mustNotContain) in [
        (
          'plainText renders when alone',
          const EntryText(plainText: 'Plain text only'),
          'Plain text only',
          <String>[],
        ),
        (
          'markdown wins over plainText',
          const EntryText(
            plainText: 'plain fallback',
            markdown: '# Markdown heading',
          ),
          'Markdown heading',
          ['plain fallback'],
        ),
        (
          'quill wins over markdown and plainText',
          const EntryText(
            plainText: 'plain fallback',
            markdown: 'markdown fallback',
            quill: r'[{"insert":"Quill text\n"}]',
          ),
          'Quill text',
          ['markdown fallback', 'plain fallback'],
        ),
      ]) {
        testWidgets(label, (tester) async {
          await pumpViewer(tester, entryText: entryText);

          final text = editorText(tester);
          expect(text, contains(mustContain));
          for (final absent in mustNotContain) {
            expect(text, isNot(contains(absent)));
          }
        });
      }
    });

    testWidgets('renders special characters intact', (tester) async {
      const specials = r'Special chars: émojis 🚀, unicode ñ, symbols @#$%';
      await pumpViewer(
        tester,
        entryText: const EntryText(plainText: specials),
      );

      expect(editorText(tester), contains(specials));
    });

    testWidgets('configures embed builders with unknown fallback', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        entryText: const EntryText(plainText: 'Supports embeds'),
      );

      final quillEditor = tester.widget<QuillEditor>(find.byType(QuillEditor));
      final builders = quillEditor.config.embedBuilders;

      expect(builders, isNotNull);
      expect(
        builders!.any((builder) => builder is DividerEmbedBuilder),
        isTrue,
      );
      expect(
        quillEditor.config.unknownEmbedBuilder,
        isA<UnknownEmbedBuilder>(),
      );
    });

    testWidgets('creates a read-only controller behind AbsorbPointer', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        entryText: const EntryText(plainText: 'Test content'),
      );

      expect(editorController(tester).readOnly, isTrue);
      expect(
        find.ancestor(
          of: find.byType(QuillEditor),
          matching: find.byType(AbsorbPointer),
        ),
        findsWidgets,
      );
      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('applies maxHeight to the LimitedBox, small or large', (
      tester,
    ) async {
      for (final maxHeight in [1.0, 150.0, 10000.0]) {
        await pumpViewer(
          tester,
          entryText: const EntryText(plainText: 'Test content'),
          maxHeight: maxHeight,
        );

        final limitedBox = tester.widget<LimitedBox>(find.byType(LimitedBox));
        expect(limitedBox.maxHeight, maxHeight, reason: '$maxHeight');
      }
    });

    testWidgets('recreates the controller when entryText changes', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        entryText: const EntryText(plainText: 'Initial content'),
      );
      expect(editorText(tester), contains('Initial content'));

      await pumpViewer(
        tester,
        entryText: const EntryText(plainText: 'Updated content'),
      );

      // The rendered document follows the new entryText.
      expect(editorText(tester), contains('Updated content'));
      expect(editorText(tester), isNot(contains('Initial content')));
    });

    group('overflow detection and gradient', () {
      testWidgets('shows ShaderMask when content overflows', (tester) async {
        final longText = List.generate(
          50,
          (i) => 'Line $i of long content',
        ).join('\n');

        await pumpViewer(
          tester,
          entryText: EntryText(plainText: longText),
          maxHeight: 100, // Small height to force overflow.
        );
        await tester.pump();

        expect(find.byType(ShaderMask), findsWidgets);
      });

      testWidgets('short content within maxHeight needs no gradient mask', (
        tester,
      ) async {
        await pumpViewer(
          tester,
          entryText: const EntryText(plainText: 'fits easily'),
          maxHeight: 500,
        );
        await tester.pump();

        expect(find.byType(ShaderMask), findsNothing);
      });

      testWidgets('re-evaluates overflow when maxHeight shrinks', (
        tester,
      ) async {
        final longText = List.generate(
          50,
          (i) => 'Line $i of long content',
        ).join('\n');

        await pumpViewer(
          tester,
          entryText: EntryText(plainText: longText),
          maxHeight: 5000,
        );
        await tester.pump();
        expect(find.byType(ShaderMask), findsNothing);

        await pumpViewer(
          tester,
          entryText: EntryText(plainText: longText),
          maxHeight: 100,
        );
        await tester.pump();

        expect(find.byType(ShaderMask), findsWidgets);
      });
    });

    group('controller lifecycle', () {
      testWidgets('disposes controller cleanly on unmount', (tester) async {
        await pumpViewer(
          tester,
          entryText: const EntryText(plainText: 'Test content'),
        );
        expect(find.byType(QuillEditor), findsOneWidget);

        await tester.pumpWidget(makeTestableWidget(const SizedBox()));

        expect(find.byType(TextViewerWidgetNonScrollable), findsNothing);
      });
    });
  });
}
