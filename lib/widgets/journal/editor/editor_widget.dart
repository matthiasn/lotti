// ignore_for_file: avoid_dynamic_calls

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
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
    this.unlinkFn,
  });

  final double maxHeight;
  final double minHeight;
  final bool autoFocus;
  final double padding;
  final Future<void> Function()? unlinkFn;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState snapshot,
      ) {
        final controller = context.read<EntryCubit>().controller;
        final focusNode = context.read<EntryCubit>().focusNode;

        void keyFormatter<T>(
          // ignore: deprecated_member_use
          RawKeyEvent event,
          String char,
          Attribute<T> attribute,
        ) {
          // ignore: deprecated_member_use
          if (event.data.isMetaPressed && event.character == char) {
            final attributes = controller.getSelectionStyle().attributes;
            final alreadySet = attributes.keys.toSet().contains(attribute.key);
            final selection = controller.selection;

            if (alreadySet) {
              controller.formatText(
                selection.baseOffset,
                selection.extentOffset - selection.baseOffset,
                Attribute.clone(attribute, null),
              );
            } else {
              controller.formatText(
                selection.baseOffset,
                selection.extentOffset - selection.baseOffset,
                attribute,
              );
            }
          }
        }

        // ignore: deprecated_member_use
        void saveViaKeyboard(RawKeyEvent event) {
          // ignore: deprecated_member_use
          if (event.data.isMetaPressed && event.character == 's') {
            context.read<EntryCubit>().save();
          }
        }

        // ignore: deprecated_member_use
        return RawKeyboardListener(
          focusNode: FocusNode(),
          // ignore: deprecated_member_use
          onKey: (RawKeyEvent event) {
            keyFormatter(event, 'b', Attribute.bold);
            keyFormatter(event, 'i', Attribute.italic);
            saveViaKeyboard(event);
          },
          child: Card(
            color: Theme.of(context).colorScheme.surface.brighten(),
            elevation: 0,
            clipBehavior: Clip.hardEdge,
            shape: const RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.all(Radius.circular(inputBorderRadius)),
              side: BorderSide(),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (snapshot.isFocused)
                    ToolbarWidget(
                      controller: controller,
                    ),
                  Flexible(
                    child: QuillEditor(
                      scrollController: ScrollController(),
                      focusNode: focusNode,
                      configurations: QuillEditorConfigurations(
                        autoFocus: autoFocus,
                        minHeight: minHeight,
                        placeholder: localizations.editorPlaceholder,
                        padding: EdgeInsets.only(
                          top: 8,
                          bottom: 16,
                          left: padding,
                          right: padding,
                        ),
                        keyboardAppearance: Theme.of(context).brightness,
                        customStyles: customEditorStyles(
                          themeData: Theme.of(context),
                        ),
                        controller: controller,
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
