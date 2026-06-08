import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/journal/ui/widgets/editor/embed_builders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Quill embed builders', () {
    late QuillEditorConfig config;

    setUp(() {
      config = QuillEditorConfig(
        embedBuilders: [
          const DividerEmbedBuilder(),
          ...FlutterQuillEmbeds.defaultEditorBuilders(),
        ],
        unknownEmbedBuilder: const UnknownEmbedBuilder(),
      );
    });

    testWidgets('renders divider embeds with DividerEmbedBuilder', (
      tester,
    ) async {
      final controller = QuillController(
        document: Document.fromDelta(
          Delta()
            ..insert(const BlockEmbed('divider', 'hr'))
            ..insert('\n'),
        ),
        selection: const TextSelection.collapsed(offset: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuillEditor(
              controller: controller,
              scrollController: ScrollController(),
              focusNode: FocusNode(),
              config: config,
            ),
          ),
        ),
      );

      // Builder contract: registered under the 'divider' key, expanded.
      const builder = DividerEmbedBuilder();
      expect(builder.key, 'divider');
      expect(builder.expanded, isTrue);

      // Rendered output: a hairline divider with the dimmed theme color,
      // padded vertically.
      final divider = tester.widget<Divider>(find.byType(Divider));
      expect(divider.thickness, 1);
      expect(divider.height, 1);
      final theme = Theme.of(tester.element(find.byType(Divider)));
      expect(
        divider.color,
        theme.dividerColor.withValues(alpha: 0.6),
      );
      expect(
        find.ancestor(
          of: find.byType(Divider),
          matching: find.byType(Padding),
        ),
        findsWidgets,
      );
    });

    testWidgets('renders fallback widget for unknown embed types', (
      tester,
    ) async {
      final controller = QuillController(
        document: Document.fromDelta(
          Delta()
            ..insert(
              BlockEmbed.custom(
                const CustomBlockEmbed('unsupported', 'data'),
              ),
            )
            ..insert('\n'),
        ),
        selection: const TextSelection.collapsed(offset: 0),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QuillEditor(
              controller: controller,
              scrollController: ScrollController(),
              focusNode: FocusNode(),
              config: config,
            ),
          ),
        ),
      );

      // The QuillEditor renders the embed synchronously; a single bounded
      // pump is sufficient (no entrance animation to settle).
      await tester.pump();

      // Builder contract: registered as the unknown fallback, expanded.
      const builder = UnknownEmbedBuilder();
      expect(builder.key, 'unknown');
      expect(builder.expanded, isTrue);

      // Rendered output: warning glyph plus the labelled fallback text
      // carrying the unknown embed's type name.
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
      expect(find.text('Unsupported content (unsupported)'), findsOneWidget);
    });
  });
}
