import 'dart:async';

import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_styles.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_toolbar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class EditorWidget extends ConsumerWidget {
  const EditorWidget({
    required this.entryId,
    super.key,
    this.minHeight = 40,
    this.maxHeight = double.maxFinite,
    this.padding = 16,
    this.autoFocus = false,
    this.unlinkFn,
  });

  final String entryId;
  final double maxHeight;
  final double minHeight;
  final bool autoFocus;
  final double padding;
  final Future<void> Function()? unlinkFn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider);

    final controller = notifier.controller;
    final focusNode = notifier.focusNode;

    final shouldShowEditorToolBar =
        entryState.value?.shouldShowEditorToolBar ?? false;

    return Card(
      color: context.colorScheme.surface.brighten(),
      elevation: 0,
      clipBehavior: Clip.hardEdge,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(inputBorderRadius)),
        side: BorderSide(),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (shouldShowEditorToolBar)
              ToolbarWidget(
                controller: controller,
                entryId: entryId,
              ),
            Flexible(
              child: QuillEditor(
                controller: controller,
                scrollController: ScrollController(),
                focusNode: focusNode,
                configurations: QuillEditorConfigurations(
                  textSelectionThemeData: TextSelectionThemeData(
                    cursorColor: context.colorScheme.onSurface,
                    selectionColor:
                        context.colorScheme.primary.withOpacity(0.5),
                  ),
                  autoFocus: autoFocus,
                  minHeight: minHeight,
                  placeholder: context.messages.editorPlaceholder,
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
