import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/entry_text.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme/theme.dart';
import 'package:lotti/widgets/journal/editor/editor_styles.dart';
import 'package:lotti/widgets/journal/editor/editor_tools.dart';

class TextViewerWidget extends StatelessWidget {
  const TextViewerWidget({
    super.key,
    required this.entryText,
  });

  final EntryText? entryText;

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
          maxHeight: 120,
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          keyboardAppearance: Brightness.dark,
          customStyles: customTextViewerStyles(
            textColor: getIt<ThemeService>().colors.entryTextColor,
            codeBlockBackground: getIt<ThemeService>().colors.bodyBgColor,
          ),
        ),
      ),
    );
  }
}
