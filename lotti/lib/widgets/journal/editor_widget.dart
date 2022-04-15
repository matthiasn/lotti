import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor_styles.dart';
import 'package:lotti/widgets/journal/editor_toolbar.dart';
import 'package:lotti/widgets/journal/editor_tools.dart';

class EditorWidget extends StatelessWidget {
  final EditorStateService _editorStateService = getIt<EditorStateService>();
  final JournalEntity? _journalEntity;

  EditorWidget({
    Key? key,
    required QuillController controller,
    JournalEntity? journalEntity,
    double minHeight = 80,
    double maxHeight = double.maxFinite,
    double padding = 16.0,
    bool readOnly = false,
    bool autoFocus = true,
    required Function saveFn,
    required FocusNode focusNode,
  })  : _controller = controller,
        _maxHeight = maxHeight,
        _minHeight = minHeight,
        _readOnly = readOnly,
        _journalEntity = journalEntity,
        _padding = padding,
        _saveFn = saveFn,
        _focusNode = focusNode,
        _autoFocus = autoFocus,
        super(key: key);

  final QuillController _controller;
  final double _maxHeight;
  final double _minHeight;
  final bool _readOnly;
  final bool _autoFocus;
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

  void tempSaveDelta(RawKeyEvent event) {
    String id = _journalEntity?.meta.id ?? 'none';

    EasyDebounce.debounce(
      'tempSaveDelta-$id',
      const Duration(seconds: 2),
      () {
        Delta delta = deltaFromController(_controller);
        _editorStateService.saveTempState(id, delta);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        keyFormatter(event, 'b', Attribute.bold);
        keyFormatter(event, 'i', Attribute.italic);
        saveViaKeyboard(event);
        tempSaveDelta(event);
      },
      child: Container(
        color: AppColors.editorBgColor,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: _maxHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolbarWidget(
                controller: _controller,
                saveFn: _saveFn,
                journalEntity: _journalEntity,
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
                    autoFocus: _autoFocus,
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
