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
    required Function saveFn,
  })  : _controller = controller,
        _height = height,
        _readOnly = readOnly,
        _padding = padding,
        _saveFn = saveFn,
        super(key: key);

  final QuillController _controller;
  final double _height;
  final bool _readOnly;
  final double _padding;
  final Function _saveFn;

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

  void saveViaKeyboard(RawKeyEvent event) {
    if (event.data.isMetaPressed && event.character == 's') {
      _saveFn();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        keyFormatter(event, 'b', Attribute.bold);
        keyFormatter(event, 'i', Attribute.italic);
        saveViaKeyboard(event);
      },
      child: Container(
        height: _height,
        color: AppColors.editorBgColor,
        child: Column(
          children: [
            Container(
              color: Colors.grey[100],
              width: double.maxFinite,
              child: Wrap(
                //mainAxisAlignment: MainAxisAlignment.center,
                //crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.save),
                    iconSize: 20,
                    tooltip: 'Save',
                    onPressed: () => _saveFn(),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 3.0),
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
                      showAlignmentButtons: false,
                    ),
                  ),
                ],
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
