import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_styles.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';

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
        configurations: QuillEditorConfigurations(
          customStyles: customEditorStyles(themeData: Theme.of(context)),
        ),
      ),
    );
  }
}
