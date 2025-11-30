import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_styles.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_toolbar.dart';
import 'package:lotti/features/journal/ui/widgets/editor/embed_builders.dart';
import 'package:lotti/features/speech/services/speech_dictionary_service.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// Returns the appropriate user-facing message for a speech dictionary result.
/// Returns null for edge cases that should be silent (no user notification needed).
///
/// This is extracted as a top-level function for testability.
String? getDictionaryResultMessage(
  SpeechDictionaryResult result,
  AppLocalizations messages,
) {
  return switch (result) {
    SpeechDictionaryResult.success => messages.addToDictionarySuccess,
    SpeechDictionaryResult.noCategory => messages.addToDictionaryNoCategory,
    SpeechDictionaryResult.duplicate => messages.addToDictionaryDuplicate,
    SpeechDictionaryResult.termTooLong => messages.addToDictionaryTooLong,
    SpeechDictionaryResult.saveFailed => messages.addToDictionarySaveFailed,
    // Silent for truly unexpected edge cases
    SpeechDictionaryResult.emptyTerm ||
    SpeechDictionaryResult.entryNotFound ||
    SpeechDictionaryResult.categoryNotFound =>
      null,
  };
}

/// Extracts the currently selected text from a QuillController.
/// Returns an empty string if no text is selected (selection is collapsed).
///
/// This is extracted as a top-level function for testability.
String getSelectedText(QuillController controller) {
  final selection = controller.selection;
  if (selection.isCollapsed) {
    return '';
  }
  return controller.document.getPlainText(
    selection.start,
    selection.end - selection.start,
  );
}

/// Shows a snackbar with the dictionary result message if applicable.
/// Returns true if a snackbar was shown, false otherwise.
///
/// This is extracted as a top-level function for testability.
bool showDictionaryResultSnackbar(
  BuildContext context,
  SpeechDictionaryResult result,
  AppLocalizations messages,
) {
  final message = getDictionaryResultMessage(result, messages);
  if (message == null) {
    return false;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
  return true;
}

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
                  embedBuilders: [
                    const DividerEmbedBuilder(),
                    ...FlutterQuillEmbeds.defaultEditorBuilders(),
                  ],
                  unknownEmbedBuilder: const UnknownEmbedBuilder(),
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
                  contextMenuBuilder: (context, rawEditorState) =>
                      _buildContextMenu(
                    context,
                    rawEditorState,
                    ref,
                    controller,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a custom context menu with standard items plus "Add to Dictionary".
  ///
  /// The "Add to Dictionary" option appears only when text is selected.
  /// It adds the selected term to the speech dictionary of the entry's category.
  Widget _buildContextMenu(
    BuildContext context,
    QuillRawEditorState rawEditorState,
    WidgetRef ref,
    QuillController controller,
  ) {
    final selectedText = getSelectedText(controller);
    final trimmedText = selectedText.trim();

    final buttonItems = <ContextMenuButtonItem>[
      // Standard context menu items
      ...rawEditorState.contextMenuButtonItems,

      // Add "Add to Dictionary" option if text is selected
      if (trimmedText.isNotEmpty)
        ContextMenuButtonItem(
          label: context.messages.addToDictionary,
          onPressed: () {
            _addToDictionary(context, ref, trimmedText);
            // Hide context menu
            ContextMenuController.removeAny();
          },
        ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: rawEditorState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  /// Adds the selected term to the entry's category speech dictionary.
  ///
  /// Shows a success snackbar on success, or an informative message
  /// if the entry has no associated category. Silent for other edge cases.
  Future<void> _addToDictionary(
    BuildContext context,
    WidgetRef ref,
    String term,
  ) async {
    final service = ref.read(speechDictionaryServiceProvider);
    final result = await service.addTermForEntry(
      entryId: entryId,
      term: term,
    );

    if (!context.mounted) return;

    showDictionaryResultSnackbar(context, result, context.messages);
  }
}
