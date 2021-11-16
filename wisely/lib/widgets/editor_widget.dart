import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:wisely/theme.dart';

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    Key? key,
    required QuillController controller,
    double height = 300,
    double padding = 16.0,
    bool readOnly = false,
  })  : _controller = controller,
        _height = height,
        _readOnly = readOnly,
        _padding = padding,
        super(key: key);

  final QuillController _controller;
  final double _height;
  final bool _readOnly;
  final double _padding;

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
      child: Container(
        height: _height,
        color: AppColors.editorBgColor,
        child: Column(
          children: [
            Container(
              width: double.maxFinite,
              color: Colors.grey[100],
              child: QuillToolbar.basic(
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
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _padding),
                child: QuillEditor.basic(
                  controller: _controller,
                  readOnly: _readOnly, // true for view only mode
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
