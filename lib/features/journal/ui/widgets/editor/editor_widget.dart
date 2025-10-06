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
    this.margin,
  });

  final String entryId;
  final double maxHeight;
  final double minHeight;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider);

    final controller = notifier.controller;
    final focusNode = notifier.focusNode;

    final shouldShowEditorToolBar =
        entryState.value?.shouldShowEditorToolBar ?? false;

    final contentPadding = shouldShowEditorToolBar
        ? const EdgeInsets.only(top: 5, bottom: 15, left: 10, right: 10)
        : EdgeInsets.zero;

    return Card(
      margin: margin,
      color: shouldShowEditorToolBar
          ? context.colorScheme.surface.brighten()
          : Colors.transparent,
      elevation: 0,
      clipBehavior: shouldShowEditorToolBar ? Clip.hardEdge : Clip.none,
      shape: RoundedRectangleBorder(
        borderRadius:
            const BorderRadius.all(Radius.circular(inputBorderRadius)),
        side: BorderSide(
          color: shouldShowEditorToolBar
              ? context.colorScheme.outline.withAlpha(100)
              : Colors.transparent,
        ),
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
                config: QuillEditorConfig(
                  textSelectionThemeData: TextSelectionThemeData(
                    cursorColor: context.colorScheme.onSurface,
                    selectionColor: context.colorScheme.primary.withAlpha(127),
                  ),
                  spaceShortcutEvents: [
                    formatHyphenToBulletList,
                    formatOrderedNumberToList,
                    formatHeaderToHeaderStyle,
                    formatHeader2ToHeaderStyle,
                    formatHeader3ToHeaderStyle,
                  ],
                  minHeight: minHeight,
                  placeholder: context.messages.editorPlaceholder,
                  padding: contentPadding,
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
