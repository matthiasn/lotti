import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:wisely/theme.dart';

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    Key? key,
    required QuillController controller,
  })  : _controller = controller,
        super(key: key);

  final QuillController _controller;

  void keyFormatter(RawKeyEvent event, String char, Attribute attribute) {
    if (event.data.isMetaPressed && event.character == char) {
      if (_controller
          .getSelectionStyle()
          .attributes
          .keys
          .contains(attribute.key)) {
        _controller.formatSelection(Attribute.clone(attribute, null));
      } else {
        _controller.formatSelection(attribute);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        keyFormatter(event, 'b', Attribute.bold);
        keyFormatter(event, 'i', Attribute.italic);
      },
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(8.0)),
        child: Container(
          padding: const EdgeInsets.all(8.0),
          height: 300,
          color: AppColors.editorBgColor,
          child: Column(
            children: [
              QuillToolbar.basic(
                controller: _controller,
                showColorButton: false,
                showBackgroundColorButton: false,
                showListCheck: false,
                showIndent: false,
                showQuote: false,
                showSmallButton: false,
                showImageButton: false,
                showLink: false,
                showUnderLineButton: false,
              ),
              Expanded(
                child: QuillEditor.basic(
                  controller: _controller,
                  readOnly: false, // true for view only mode
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
