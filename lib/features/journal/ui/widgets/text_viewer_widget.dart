import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_styles.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/features/journal/ui/widgets/editor/embed_builders.dart';

class TextViewerWidget extends StatelessWidget {
  const TextViewerWidget({
    required this.entryText,
    required this.maxHeight,
    super.key,
  });

  final EntryText? entryText;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final serializedQuill = entryText?.quill;
    final markdown = entryText?.markdown ?? entryText?.plainText ?? '';
    final quill = serializedQuill ?? markdownToDelta(markdown);
    final controller = makeController(serializedQuill: quill)..readOnly = true;

    return LimitedBox(
      maxHeight: maxHeight,
      child: QuillEditor(
        controller: controller,
        scrollController: ScrollController(),
        focusNode: FocusNode(),
        config: QuillEditorConfig(
          embedBuilders: [
            const DividerEmbedBuilder(),
            ...FlutterQuillEmbeds.defaultEditorBuilders(),
          ],
          unknownEmbedBuilder: const UnknownEmbedBuilder(),
          customStyles: customEditorStyles(themeData: Theme.of(context)),
        ),
      ),
    );
  }
}
