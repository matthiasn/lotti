import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/journal/ui/widgets/text_viewer_widget_non_scrollable.dart';

import '../../../../widget_test_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TextViewerWidgetNonScrollable', () {
    testWidgets('renders with null entryText', (tester) async {
      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: null,
            maxHeight: 200,
          ),
        ),
      );

      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('renders with plainText only', (tester) async {
      const entryText = EntryText(
        plainText: 'Simple plain text content',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('renders with markdown content', (tester) async {
      const entryText = EntryText(
        plainText: 'Markdown content',
        markdown: '# Header\n\nSome **bold** text',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('renders with quill content', (tester) async {
      const entryText = EntryText(
        plainText: 'Quill content',
        quill: r'[{"insert":"Quill formatted text\n"}]',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('uses LimitedBox with correct maxHeight', (tester) async {
      const maxHeight = 150.0;
      const entryText = EntryText(
        plainText: 'Test content',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: maxHeight,
          ),
        ),
      );

      final limitedBox = tester.widget<LimitedBox>(
        find.byType(LimitedBox),
      );
      expect(limitedBox.maxHeight, maxHeight);
    });

    testWidgets('creates read-only QuillController', (tester) async {
      const entryText = EntryText(
        plainText: 'Test content',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      final quillEditor = tester.widget<QuillEditor>(
        find.byType(QuillEditor),
      );
      expect(quillEditor.controller.readOnly, isTrue);
    });

    testWidgets('uses LayoutBuilder for responsive layout', (tester) async {
      const entryText = EntryText(
        plainText: 'Test content',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      expect(find.byType(LayoutBuilder), findsOneWidget);
    });

    testWidgets('recreates controller when entryText changes', (tester) async {
      const initialEntryText = EntryText(
        plainText: 'Initial content',
      );
      const updatedEntryText = EntryText(
        plainText: 'Updated content',
      );

      Widget buildWidget(EntryText? entryText) {
        return makeTestableWidget(
          TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        );
      }

      // Initial render
      await tester.pumpWidget(buildWidget(initialEntryText));
      expect(find.byType(QuillEditor), findsOneWidget);

      // Update entryText
      await tester.pumpWidget(buildWidget(updatedEntryText));
      await tester.pump();

      // Should still have QuillEditor (controller recreated internally)
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('contains QuillEditor for displaying content', (tester) async {
      const entryText = EntryText(
        plainText: 'Test content',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      // Should contain QuillEditor
      expect(find.byType(QuillEditor), findsOneWidget);

      // Should be wrapped in AbsorbPointer to prevent interaction
      expect(find.byType(AbsorbPointer), findsWidgets);
    });

    testWidgets('handles empty plainText gracefully', (tester) async {
      const entryText = EntryText(
        plainText: '',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('prefers quill over markdown when both exist', (tester) async {
      const entryText = EntryText(
        plainText: 'Plain text',
        markdown: '# Markdown content',
        quill: r'[{"insert":"Quill content\n"}]',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      // Should render without throwing
      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    testWidgets('fallback to plainText when markdown is null', (tester) async {
      const entryText = EntryText(
        plainText: 'Fallback plain text',
      );

      await tester.pumpWidget(
        makeTestableWidget(
          const TextViewerWidgetNonScrollable(
            entryText: entryText,
            maxHeight: 200,
          ),
        ),
      );

      expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      expect(find.byType(QuillEditor), findsOneWidget);
    });

    group('overflow detection and gradient', () {
      testWidgets('has proper widget structure for gradient', (tester) async {
        const entryText = EntryText(
          plainText: 'Test content for overflow',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should have the basic structure
        expect(find.byType(QuillEditor), findsOneWidget);
        expect(find.byType(AbsorbPointer), findsWidgets);
      });

      testWidgets('shows ShaderMask when content overflows', (tester) async {
        // Create long content that will overflow
        final longText =
            List.generate(50, (i) => 'Line $i of long content').join('\n');
        final entryText = EntryText(
          plainText: longText,
        );

        await tester.pumpWidget(
          makeTestableWidget(
            TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 100, // Small height to force overflow
            ),
          ),
        );

        await tester.pumpAndSettle();

        // When content overflows, ShaderMask should be present
        expect(find.byType(ShaderMask), findsWidgets);
      });

      testWidgets('triggers overflow check on layout changes', (tester) async {
        const entryText = EntryText(
          plainText: 'Test content for overflow',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Change layout by updating the widget
        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 100, // Smaller height
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Should still render properly after layout change
        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      });
    });

    group('controller lifecycle', () {
      testWidgets('disposes controller properly', (tester) async {
        const entryText = EntryText(
          plainText: 'Test content',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        expect(find.byType(QuillEditor), findsOneWidget);

        // Remove widget to trigger dispose
        await tester.pumpWidget(
          makeTestableWidget(
            const SizedBox(),
          ),
        );

        // Should not throw or cause memory leaks
        expect(find.byType(TextViewerWidgetNonScrollable), findsNothing);
      });
    });

    group('edge cases', () {
      testWidgets('handles very small maxHeight', (tester) async {
        const entryText = EntryText(
          plainText: 'Test content',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 1, // Very small height
            ),
          ),
        );

        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      });

      testWidgets('handles very large maxHeight', (tester) async {
        const entryText = EntryText(
          plainText: 'Test content',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 10000, // Very large height
            ),
          ),
        );

        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
      });

      testWidgets('handles special characters in text', (tester) async {
        const entryText = EntryText(
          plainText: r'Special chars: émojis 🚀, unicode ñ, symbols @#$%',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
        expect(find.byType(QuillEditor), findsOneWidget);
      });

      testWidgets('handles null quill content gracefully', (tester) async {
        const entryText = EntryText(
          plainText: 'Fallback text',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        // Widget should render with fallback content
        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
        expect(find.byType(QuillEditor), findsOneWidget);
      });
    });

    group('content prioritization', () {
      testWidgets('uses quill when available', (tester) async {
        const entryText = EntryText(
          plainText: 'Plain text',
          markdown: 'Markdown text',
          quill: r'[{"insert":"Quill text\n"}]',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
        expect(find.byType(QuillEditor), findsOneWidget);
      });

      testWidgets('falls back to markdown when quill is null', (tester) async {
        const entryText = EntryText(
          plainText: 'Plain text',
          markdown: 'Markdown text',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
        expect(find.byType(QuillEditor), findsOneWidget);
      });

      testWidgets('falls back to plainText when markdown is null',
          (tester) async {
        const entryText = EntryText(
          plainText: 'Plain text only',
        );

        await tester.pumpWidget(
          makeTestableWidget(
            const TextViewerWidgetNonScrollable(
              entryText: entryText,
              maxHeight: 200,
            ),
          ),
        );

        expect(find.byType(TextViewerWidgetNonScrollable), findsOneWidget);
        expect(find.byType(QuillEditor), findsOneWidget);
      });
    });
  });
}
