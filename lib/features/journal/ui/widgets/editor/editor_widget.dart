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
    this.padding = 10,
  });

  final String entryId;
  final double maxHeight;
  final double minHeight;
  final double padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    final entryState = ref.watch(provider);

    final controller = notifier.controller;
    final focusNode = notifier.focusNode;

    final shouldShowEditorToolBar =
        entryState.value?.shouldShowEditorToolBar ?? false;

    if (shouldShowEditorToolBar) {
      focusNode.requestFocus();
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Card(
        key: ValueKey('$emptyTextSelectionControls $shouldShowEditorToolBar'),
        color: shouldShowEditorToolBar
            ? context.colorScheme.surface.brighten()
            : Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.hardEdge,
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
                  configurations: QuillEditorConfigurations(
                    textSelectionThemeData: TextSelectionThemeData(
                      cursorColor: context.colorScheme.onSurface,
                      selectionColor:
                          context.colorScheme.primary.withAlpha(127),
                    ),
                    autoFocus: shouldShowEditorToolBar,
                    minHeight: minHeight,
                    placeholder: context.messages.editorPlaceholder,
                    padding: EdgeInsets.only(
                      top: 8,
                      bottom: 16,
                      left: shouldShowEditorToolBar ? padding : 0,
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
      ),
    );
  }
}
