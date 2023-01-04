import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/editor/editor_styles.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';

class TextViewerWidget extends StatelessWidget {
  const TextViewerWidget({
    super.key,
    required this.entryText,
    required this.maxHeight,
  });

  final EntryText? entryText;
  final double? maxHeight;

  @override
  Widget build(BuildContext context) {
    if (entryText == null || entryText?.plainText == '\n') {
      return const SizedBox.shrink();
    }

    final controller = makeController(serializedQuill: entryText?.quill);

    return IgnorePointer(
      child: SingleChildScrollView(
        child: QuillEditor(
          controller: controller,
          readOnly: true,
          scrollController: ScrollController(),
          scrollable: true,
          focusNode: FocusNode(canRequestFocus: false),
          autoFocus: false,
          expands: false,
          maxHeight: maxHeight,
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          keyboardAppearance: keyboardAppearance(),
          customStyles: customTextViewerStyles(
            textColor: styleConfig().primaryTextColor,
            codeBlockBackground: styleConfig().primaryColorLight,
          ),
        ),
      ),
    );
  }
}
