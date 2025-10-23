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

    testWidgets('renders divider embeds with DividerEmbedBuilder',
        (tester) async {
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

      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('renders fallback widget for unknown embed types',
        (tester) async {
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

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}
