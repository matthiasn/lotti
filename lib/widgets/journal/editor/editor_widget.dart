// ignore_for_file: avoid_dynamic_calls

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Text;
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/editor/editor_styles.dart';
import 'package:lotti/widgets/journal/editor/editor_toolbar.dart';

class EditorWidget extends StatelessWidget {
  const EditorWidget({
    super.key,
    this.minHeight = 40,
    this.maxHeight = double.maxFinite,
    this.padding = 16,
    this.autoFocus = false,
  });

  final double maxHeight;
  final double minHeight;
  final bool autoFocus;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState snapshot,
      ) {
        final controller = context.read<EntryCubit>().controller;
        final focusNode = context.read<EntryCubit>().focusNode;

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
            context.read<EntryCubit>().save();
          }
        }

        return RawKeyboardListener(
          focusNode: FocusNode(),
          onKey: (RawKeyEvent event) {
            keyFormatter(event, 'b', Attribute.bold);
            keyFormatter(event, 'i', Attribute.italic);
            saveViaKeyboard(event);
          },
          child: ColoredBox(
            color: Colors.white,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ToolbarWidget(),
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
                          textColor: Colors.black,
                          codeBlockBackground: styleConfig().primaryColorLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
