import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor_styles.dart';
import 'package:lotti/widgets/journal/editor_toolbar.dart';

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
            Visibility(
              visible: Platform.isMacOS && !_readOnly,
              child: ToolbarWidget(
                controller: _controller,
                saveFn: _saveFn,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: _padding),
                child: QuillEditor(
                  controller: _controller,
                  readOnly: _readOnly,
                  scrollController: ScrollController(),
                  scrollable: true,
                  focusNode: FocusNode(),
                  autoFocus: true,
                  expands: false,
                  padding: const EdgeInsets.only(top: 8, bottom: 16),
                  keyboardAppearance: Brightness.dark,
                  customStyles: customEditorStyles(
                    textColor: AppColors.editorTextColor,
                    codeBlockBackground: AppColors.codeBlockBackground,
                  ),
                ),
              ),
            ),
            Visibility(
              visible: (Platform.isIOS || Platform.isAndroid) && !_readOnly,
              child: ToolbarWidget(
                controller: _controller,
                saveFn: _saveFn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
