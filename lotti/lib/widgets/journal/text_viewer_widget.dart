import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor_styles.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';

class TextViewerWidget extends StatelessWidget {
  const TextViewerWidget({
    Key? key,
    required this.entryText,
  }) : super(key: key);

  final EntryText? entryText;

  @override
  Widget build(BuildContext context) {
    QuillController _controller =
        makeController(serializedQuill: entryText?.quill);

    return IgnorePointer(
      child: SingleChildScrollView(
        child: QuillEditor(
          controller: _controller,
          readOnly: true,
          scrollController: ScrollController(),
          scrollable: true,
          focusNode: FocusNode(canRequestFocus: false),
          autoFocus: false,
          expands: false,
          maxHeight: 120,
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          keyboardAppearance: Brightness.dark,
          customStyles: customEditorStyles(
            textColor: AppColors.entryTextColor,
            codeBlockBackground: AppColors.bodyBgColor,
          ),
        ),
      ),
    );
  }
}
