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
    final savePad = context.designTokens.spacing.step3;

    // QuillSimpleToolbar paints its own Container background; brighten the card
    // surface a touch so the bar reads as a distinct (but related) strip.
    final toolbarColor = context.colorScheme.surface.brighten(15);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adaptive: show every control inline when there is room; only trim to
        // essentials + a "…" overflow on narrow widths where the full row would
        // clip.
        final showAll = constraints.maxWidth >= fullToolbarMinWidth;

        final toolbar = Material(
          elevation: 1,
          color: toolbarColor,
          surfaceTintColor: Colors.transparent,
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
                            toolbarColor,
                          )
                        : _essentialsConfig(notifier, toolbarColor),
                  ),
                ),
                if (!showAll)
                  _MoreFormattingButton(
                    controller: controller,
                    notifier: notifier,
                  ),
                // Fence the save action off from the formatting controls so it
                // reads as a pinned, categorically-different primary action and
                // can't be mis-tapped against the adjacent control.
                const _ToolbarSeparator(),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: savePad),
                  child: _ToolbarSaveButton(entryId: entryId),
                ),
              ],
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

/// A thin vertical rule that fences the save action off from the formatting
/// controls (and matches Quill's own section dividers).
class _ToolbarSeparator extends StatelessWidget {
  const _ToolbarSeparator();

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step4),
      child: Container(
        width: 1,
        height: tokens.spacing.sectionGap,
        color: tokens.colors.text.lowEmphasis,
      ),
    );
  }
}

/// The full formatting set, shown inline when the toolbar is wide enough.
QuillSimpleToolbarConfig _fullConfig(
  BuildContext context,
  QuillController controller,
  EntryController notifier,
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
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base:
          QuillToolbarBaseButtonOptions<
            dynamic,
            QuillToolbarBaseButtonExtraOptions
          >(afterButtonPressed: notifier.focusNode.requestFocus),
      codeBlock: const QuillToolbarToggleStyleButtonOptions(
        iconData: Icons.data_object,
      ),
      toggleCheckList: const QuillToolbarToggleCheckListButtonOptions(
        iconData: Icons.checklist_rounded,
      ),
    ),
  );
}

/// The essential, always-visible formatting controls.
QuillSimpleToolbarConfig _essentialsConfig(
  EntryController notifier,
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
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base:
          QuillToolbarBaseButtonOptions<
            dynamic,
            QuillToolbarBaseButtonExtraOptions
          >(afterButtonPressed: notifier.focusNode.requestFocus),
      codeBlock: const QuillToolbarToggleStyleButtonOptions(
        iconData: Icons.data_object,
      ),
      toggleCheckList: const QuillToolbarToggleCheckListButtonOptions(
        iconData: Icons.checklist_rounded,
      ),
    ),
  );
}

/// The advanced formatting controls, surfaced in the "…" overflow sheet.
QuillSimpleToolbarConfig _advancedConfig(
  BuildContext context,
  QuillController controller,
  EntryController notifier,
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
    buttonOptions: QuillSimpleToolbarButtonOptions(
      base:
          QuillToolbarBaseButtonOptions<
            dynamic,
            QuillToolbarBaseButtonExtraOptions
          >(afterButtonPressed: notifier.focusNode.requestFocus),
      codeBlock: const QuillToolbarToggleStyleButtonOptions(
        iconData: Icons.data_object,
      ),
      toggleCheckList: const QuillToolbarToggleCheckListButtonOptions(
        iconData: Icons.checklist_rounded,
      ),
    ),
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
        final toolbarColor = context.colorScheme.surface.brighten(15);
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

/// Pinned save control: always present while editing, quiet/disabled until there
/// are unsaved changes, then a clear accent.
class _ToolbarSaveButton extends ConsumerWidget {
  const _ToolbarSaveButton({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = saveButtonControllerProvider(id: entryId);
    final unsaved = ref.watch(provider).value ?? false;
    final tokens = context.designTokens;

    // A persistent pill container with an always-visible outline (matching the
    // small button's corner radius) gives the control a perceivable shape in
    // BOTH states. So the clean→dirty change is figure-ground (the outline fills
    // with teal) plus a leading save glyph — never carried by the teal hue
    // alone, and the clean state never has a near-invisible (1:1) boundary.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radii.l),
        border: Border.all(
          color: unsaved ? Colors.transparent : tokens.colors.text.lowEmphasis,
        ),
      ),
      child: DesignSystemButton(
        label: context.messages.saveLabel,
        leadingIcon: unsaved ? Icons.save_rounded : null,
        // null onPressed → the button renders its disabled (quiet) state.
        onPressed: unsaved
            ? () {
                ref.read(provider.notifier).save();
                FocusManager.instance.primaryFocus?.unfocus();
              }
            : null,
      ),
    );
  }
}
