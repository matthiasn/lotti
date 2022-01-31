import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor_styles.dart';
import 'package:lotti/widgets/journal/editor_toolbar.dart';

class EditorWidget extends StatelessWidget {
  EditorWidget({
    Key? key,
    required QuillController controller,
    double minHeight = 80,
    double? maxHeight,
    double padding = 16.0,
    bool readOnly = false,
    required Function saveFn,
    required FocusNode focusNode,
  })  : _controller = controller,
        _maxHeight = maxHeight,
        _minHeight = minHeight,
        _readOnly = readOnly,
        _padding = padding,
        _saveFn = saveFn,
        _focusNode = focusNode,
        super(key: key);

  final QuillController _controller;
  final double? _maxHeight;
  final double _minHeight;
  final bool _readOnly;
  final double _padding;
  final Function _saveFn;
  final FocusNode _focusNode;

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
        color: AppColors.editorBgColor,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _maxHeight ?? MediaQuery.of(context).size.height - 160,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolbarWidget(
                controller: _controller,
                saveFn: _saveFn,
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: _padding),
                  child: QuillEditor(
                    controller: _controller,
                    readOnly: _readOnly,
                    scrollController: ScrollController(),
                    scrollable: true,
                    focusNode: _focusNode,
                    autoFocus: true,
                    expands: false,
                    minHeight: _minHeight,
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    keyboardAppearance: Brightness.dark,
                    customStyles: customEditorStyles(
                      textColor: AppColors.editorTextColor,
                      codeBlockBackground: AppColors.codeBlockBackground,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
