// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/editor/editor_styles.dart';
import 'package:lotti/widgets/journal/editor/editor_toolbar.dart';

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    super.key,
    required this.controller,
    this.journalEntity,
    this.minHeight = 40,
    this.maxHeight = double.maxFinite,
    this.padding = 16,
    this.autoFocus = false,
    required this.saveFn,
    required this.focusNode,
  });

  final JournalEntity? journalEntity;
  final QuillController controller;
  final double maxHeight;
  final double minHeight;
  final bool autoFocus;
  final double padding;
  final Function saveFn;
  final FocusNode focusNode;

  void keyFormatter(
    RawKeyEvent event,
    String char,
    Attribute<dynamic> attribute,
  ) {
    if (event.data.isMetaPressed && event.character == char) {
      if (controller
          .getSelectionStyle()
          .attributes
          .keys
          .contains(attribute.key)) {
        controller.formatSelection(Attribute.clone(attribute, null));
      } else {
        controller.formatSelection(attribute);
      }
    }
  }

  void saveViaKeyboard(RawKeyEvent event) {
    if (event.data.isMetaPressed && event.character == 's') {
      saveFn();
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
      child: ColoredBox(
        color: AppColors.editorBgColor,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ToolbarWidget(
                id: journalEntity?.meta.id,
                lastSaved: journalEntity?.meta.updatedAt ??
                    DateTime.fromMillisecondsSinceEpoch(0),
                controller: controller,
                saveFn: saveFn,
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding),
                  child: QuillEditor(
                    controller: controller,
                    readOnly: false,
                    scrollController: ScrollController(),
                    scrollable: true,
                    focusNode: focusNode,
                    autoFocus: autoFocus,
                    expands: false,
                    minHeight: minHeight,
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
