import 'package:delta_markdown/delta_markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_styles.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/features/journal/ui/widgets/editor/embed_builders.dart';

class TextViewerWidget extends StatefulWidget {
  const TextViewerWidget({
    required this.entryText,
    required this.maxHeight,
    super.key,
  });

  final EntryText? entryText;
  final double maxHeight;

  @override
  State<TextViewerWidget> createState() => _TextViewerWidgetState();
}

class _TextViewerWidgetState extends State<TextViewerWidget> {
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final serializedQuill = widget.entryText?.quill;
    final markdown =
        widget.entryText?.markdown ?? widget.entryText?.plainText ?? '';
    final quill = serializedQuill ?? markdownToDelta(markdown);
    final controller = makeController(serializedQuill: quill)..readOnly = true;

    return LimitedBox(
      maxHeight: widget.maxHeight,
      child: QuillEditor(
        controller: controller,
        scrollController: _scrollController,
        focusNode: _focusNode,
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
