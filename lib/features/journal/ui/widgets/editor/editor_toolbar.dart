import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

/// The editor's formatting toolbar, shown while an entry is being edited.
///
/// Layout: formatting controls on the left and a pinned save button on the
/// right (always present while editing — quiet/disabled until there are unsaved
/// changes, then a clear accent). The formatting set is width-adaptive: when the
/// toolbar is wide enough ([fullToolbarMinWidth]) every control is shown inline;
/// on narrower widths it trims to the essentials plus a "…" overflow that opens
/// the advanced controls in a sheet. The whole bar animates open the first time
/// it appears.
class ToolbarWidget extends ConsumerWidget {
  const ToolbarWidget({
    required this.controller,
    required this.entryId,
    super.key,
  });

  final QuillController controller;
  final String entryId;

  static const double height = 48;

  /// Above this content width the full formatting set fits inline, so the "…"
  /// overflow is dropped — on a roomy (desktop) editor every control is one
  /// click away. Measured: the full row needs ~870px, so 900 leaves a margin.
  static const double fullToolbarMinWidth = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(entryControllerProvider(id: entryId).notifier);
    const duration = Duration(milliseconds: 400);
    const curve = Curves.easeInOutQuint;
    final tokens = context.designTokens;
    final savePad = tokens.spacing.step3;

    // The toolbar shares the editor card's surface so the strip and the text
    // area read as one panel rather than a brighter bar bolted onto a darker
    // box; a single hairline divider (below) marks the seam instead of a
    // brightness jump + shadow. QuillSimpleToolbar paints its own background, so
    // this colour is also threaded into each config.
    final toolbarColor = context.colorScheme.surface.brighten();

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adaptive: show every control inline when there is room; only trim to
        // essentials + a "…" overflow on narrow widths where the full row would
        // clip.
        final showAll = constraints.maxWidth >= fullToolbarMinWidth;

        final toolbar = Material(
          // No elevation: the toolbar and the text area share one flat surface,
          // separated only by the hairline below.
          color: toolbarColor,
          surfaceTintColor: Colors.transparent,
          child: DecoratedBox(
            decoration: BoxDecoration(
              // One hairline marks the toolbar/content seam; the strip and the
              // text area otherwise share a single surface.
              border: Border(
                bottom: BorderSide(color: context.colorScheme.outlineVariant),
              ),
            ),
            child: SizedBox(
              height: height,
              child: Row(
                children: [
                  Expanded(
                    child: QuillSimpleToolbar(
                      controller: controller,
                      config: showAll
                          ? _fullConfig(
                              context,
                              controller,
                              notifier,
                              tokens,
                              toolbarColor,
                            )
                          : _essentialsConfig(notifier, tokens, toolbarColor),
                    ),
                  ),
                  if (!showAll)
                    _MoreFormattingButton(
                      controller: controller,
                      notifier: notifier,
                    ),
                  // A generous, deterministic gap fences the save/discard actions
                  // off from the formatting controls so they read as the pinned,
                  // primary cluster and an overshoot can't land on them (no orphan
                  // divider glyph).
                  SizedBox(width: tokens.spacing.step5),
                  _ToolbarActions(entryId: entryId, savePad: savePad),
                ],
              ),
            ),
          ),
        );

        if (notifier.animationCompleted) {
          return SizedBox(height: height, child: toolbar);
        }
        return toolbar
            .animate(onComplete: (_) => notifier.animationCompleted = true)
            .scaleY(
              duration: duration,
              curve: curve,
              begin: 0,
              end: 1,
              alignment: Alignment.topCenter,
            )
            .custom(
              duration: duration,
              curve: curve,
              builder: (context, value, child) =>
                  SizedBox(height: height * value, child: child),
            );
      },
    );
  }
}

/// Shared button options for every config: brighten the icons toward white so
/// they are legible on the toolbar strip (low-vision), light a toggled-on
/// control teal so the active state is perceivable, and give code-block and
/// checklist distinct glyphs so they don't collide with inline code / the
/// bulleted list.
QuillSimpleToolbarButtonOptions _buttonOptions(
  EntryController notifier,
  DsTokens tokens,
) {
  return QuillSimpleToolbarButtonOptions(
    base:
        QuillToolbarBaseButtonOptions<
          dynamic,
          QuillToolbarBaseButtonExtraOptions
        >(
          afterButtonPressed: notifier.focusNode.requestFocus,
          iconTheme: QuillIconTheme(
            iconButtonUnselectedData: IconButtonData(
              color: tokens.colors.text.highEmphasis,
            ),
            iconButtonSelectedData: IconButtonData(
              color: tokens.colors.interactive.enabled,
            ),
          ),
        ),
    codeBlock: const QuillToolbarToggleStyleButtonOptions(
      iconData: Icons.data_object,
    ),
    toggleCheckList: const QuillToolbarToggleCheckListButtonOptions(
      iconData: Icons.checklist_rounded,
    ),
  );
}

/// The full formatting set, shown inline when the toolbar is wide enough.
QuillSimpleToolbarConfig _fullConfig(
  BuildContext context,
  QuillController controller,
  EntryController notifier,
  DsTokens tokens,
  Color toolbarColor,
) {
  return QuillSimpleToolbarConfig(
    toolbarSize: 44,
    toolbarSectionSpacing: 0,
    toolbarIconAlignment: WrapAlignment.start,
    color: toolbarColor,
    multiRowsDisplay: false,
    // Hidden everywhere (rarely used in notes).
    showUndo: false,
    showRedo: false,
    showFontFamily: false,
    showFontSize: false,
    showUnderLineButton: false,
    showSubscript: false,
    showSuperscript: false,
    showIndent: false,
    showLeftAlignment: false,
    showCenterAlignment: false,
    showRightAlignment: false,
    showJustifyAlignment: false,
    showSearchButton: false,
    customButtons: [
      QuillToolbarCustomButtonOptions(
        icon: const Icon(Icons.horizontal_rule),
        tooltip: context.messages.editorInsertDivider,
        onPressed: () => insertDividerEmbed(controller),
      ),
    ],
    buttonOptions: _buttonOptions(notifier, tokens),
  );
}

/// The essential, always-visible formatting controls.
QuillSimpleToolbarConfig _essentialsConfig(
  EntryController notifier,
  DsTokens tokens,
  Color toolbarColor,
) {
  return QuillSimpleToolbarConfig(
    toolbarSize: 44,
    toolbarSectionSpacing: 0,
    toolbarIconAlignment: WrapAlignment.start,
    color: toolbarColor,
    multiRowsDisplay: false,
    // Everything else lives behind the "…" overflow.
    showUndo: false,
    showRedo: false,
    showFontFamily: false,
    showFontSize: false,
    showColorButton: false,
    showBackgroundColorButton: false,
    showUnderLineButton: false,
    showStrikeThrough: false,
    showInlineCode: false,
    showClearFormat: false,
    showSubscript: false,
    showSuperscript: false,
    showCodeBlock: false,
    showQuote: false,
    showIndent: false,
    showLeftAlignment: false,
    showCenterAlignment: false,
    showRightAlignment: false,
    showJustifyAlignment: false,
    showSearchButton: false,
    buttonOptions: _buttonOptions(notifier, tokens),
  );
}

/// The advanced formatting controls, surfaced in the "…" overflow sheet.
QuillSimpleToolbarConfig _advancedConfig(
  BuildContext context,
  QuillController controller,
  EntryController notifier,
  DsTokens tokens,
  Color toolbarColor,
) {
  return QuillSimpleToolbarConfig(
    toolbarSize: 44,
    toolbarSectionSpacing: 0,
    color: toolbarColor,
    // Hidden everywhere / already inline.
    showUndo: false,
    showRedo: false,
    showBoldButton: false,
    showItalicButton: false,
    showUnderLineButton: false,
    showHeaderStyle: false,
    showListNumbers: false,
    showListBullets: false,
    showListCheck: false,
    showLink: false,
    showFontFamily: false,
    showFontSize: false,
    showSubscript: false,
    showSuperscript: false,
    showIndent: false,
    showSearchButton: false,
    customButtons: [
      QuillToolbarCustomButtonOptions(
        icon: const Icon(Icons.horizontal_rule),
        tooltip: context.messages.editorInsertDivider,
        onPressed: () => insertDividerEmbed(controller),
      ),
    ],
    buttonOptions: _buttonOptions(notifier, tokens),
  );
}

/// The "…" button that opens the advanced-formatting sheet.
class _MoreFormattingButton extends StatelessWidget {
  const _MoreFormattingButton({
    required this.controller,
    required this.notifier,
  });

  final QuillController controller;
  final EntryController notifier;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return IconButton(
      icon: const Icon(Icons.more_horiz),
      color: tokens.colors.text.mediumEmphasis,
      tooltip: context.messages.editorMoreFormatting,
      onPressed: () {
        final toolbarColor = context.colorScheme.surface.brighten();
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: toolbarColor,
          showDragHandle: true,
          builder: (sheetContext) => SafeArea(
            child: Padding(
              padding: EdgeInsets.all(tokens.spacing.step4),
              child: QuillSimpleToolbar(
                controller: controller,
                config: _advancedConfig(
                  sheetContext,
                  controller,
                  notifier,
                  tokens,
                  toolbarColor,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The pinned trailing cluster: a discard control that appears only when there
/// are unsaved changes, followed by the always-present save control.
///
/// The discard slot is reserved (a fixed-width box) in both states so the
/// toolbar never reflows the moment editing begins — only the icon inside it
/// appears/disappears. A single watch of the save state drives both controls.
class _ToolbarActions extends ConsumerWidget {
  const _ToolbarActions({required this.entryId, required this.savePad});

  final String entryId;
  final double savePad;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unsaved =
        ref.watch(saveButtonControllerProvider(id: entryId)).value ?? false;
    final tokens = context.designTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reserved, fixed-width discard slot. Discarding only makes sense when
        // there are edits to throw away, but reserving the width in both states
        // keeps the formatting controls from shifting when editing begins. A
        // square slot (== toolbar height) gives the icon a ≥48px tap target.
        SizedBox(
          width: ToolbarWidget.height,
          child: unsaved
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  color: tokens.colors.text.mediumEmphasis,
                  tooltip: context.messages.editorDiscardChanges,
                  onPressed: () => ref
                      .read(entryControllerProvider(id: entryId).notifier)
                      .discard(),
                )
              : null,
        ),
        Padding(
          // A slightly larger trailing inset (== the card's corner radius) keeps
          // the save pill clear of the card's rounded corner instead of pinching
          // it; the smaller leading gap separates it from the discard slot.
          padding: EdgeInsets.only(left: savePad, right: tokens.spacing.step4),
          child: _ToolbarSaveButton(entryId: entryId, unsaved: unsaved),
        ),
      ],
    );
  }
}

/// Pinned save control: always present while editing, quiet/disabled until there
/// are unsaved changes, then a clear accent.
class _ToolbarSaveButton extends ConsumerWidget {
  const _ToolbarSaveButton({required this.entryId, required this.unsaved});

  final String entryId;
  final bool unsaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;

    // A persistent pill container with an always-visible outline (matching the
    // button's corner radius) gives the control a perceivable shape in BOTH
    // states. So the clean→dirty change is figure-ground (the outline fills with
    // teal) plus a leading save glyph — never carried by the teal hue alone, and
    // the clean state never has a near-invisible (1:1) boundary. The medium size
    // gives a ~44px tap target that also aligns with the toolbar's icon row.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.xl),
        border: Border.all(
          color: unsaved ? Colors.transparent : tokens.colors.text.lowEmphasis,
        ),
      ),
      child: DesignSystemButton(
        label: context.messages.saveLabel,
        size: DesignSystemButtonSize.medium,
        // Always present (greyed when clean) so the chip keeps a fixed width and
        // the narrow toolbar never reflows between clean and dirty states.
        leadingIcon: Icons.save_rounded,
        // null onPressed → the button renders its disabled (quiet) state.
        onPressed: unsaved
            ? () {
                ref
                    .read(saveButtonControllerProvider(id: entryId).notifier)
                    .save();
                FocusManager.instance.primaryFocus?.unfocus();
              }
            : null,
      ),
    );
  }
}
