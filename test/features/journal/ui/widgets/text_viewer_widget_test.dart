import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget.dart';

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
        TextViewerWidget(entryText: entryText, maxHeight: maxHeight),
      ),
    );
    await tester.pump();
  }

  QuillController editorController(WidgetTester tester) =>
      tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;

  group('TextViewerWidget', () {
    testWidgets('renders an empty read-only document for null entryText', (
      tester,
    ) async {
      await pumpViewer(tester, entryText: null);

      final controller = editorController(tester);
      expect(controller.document.toPlainText().trim(), isEmpty);
      expect(controller.readOnly, isTrue);
    });

    testWidgets('renders plainText when no markdown or quill present', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        entryText: const EntryText(plainText: 'just the plain text'),
      );

      expect(
        editorController(tester).document.toPlainText(),
        contains('just the plain text'),
      );
    });

    testWidgets('prefers markdown over plainText', (tester) async {
      await pumpViewer(
        tester,
        entryText: const EntryText(
          plainText: 'plain fallback that must not render',
          markdown: '# Markdown heading',
        ),
      );

      final text = editorController(tester).document.toPlainText();
      expect(text, contains('Markdown heading'));
      expect(text, isNot(contains('plain fallback')));
    });

    testWidgets('prefers serialized quill over markdown and plainText', (
      tester,
    ) async {
      await pumpViewer(
        tester,
        entryText: const EntryText(
          plainText: 'plain fallback',
          markdown: 'markdown fallback',
          quill: r'[{"insert":"From the quill delta\n"}]',
        ),
      );

      final text = editorController(tester).document.toPlainText();
      expect(text, contains('From the quill delta'));
      expect(text, isNot(contains('markdown fallback')));
      expect(text, isNot(contains('plain fallback')));
    });

    testWidgets('applies maxHeight to the LimitedBox', (tester) async {
      await pumpViewer(
        tester,
        entryText: const EntryText(plainText: 'sized'),
        maxHeight: 123,
      );

      final limitedBox = tester.widget<LimitedBox>(
        find.ancestor(
          of: find.byType(QuillEditor),
          matching: find.byType(LimitedBox),
        ),
      );
      expect(limitedBox.maxHeight, 123);
    });
  });
}
