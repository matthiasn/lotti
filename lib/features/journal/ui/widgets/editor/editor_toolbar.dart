import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/editor/editor_tools.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class ToolbarWidget extends ConsumerWidget {
  const ToolbarWidget({
    required this.controller,
    required this.entryId,
    super.key,
  });

  final QuillController controller;
  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = entryControllerProvider(id: entryId);
    final notifier = ref.read(provider.notifier);
    const duration = Duration(milliseconds: 400);
    const curve = Curves.easeInOutQuint;
    const height = 45.0;

    final baseButtonOptions =
        QuillToolbarBaseButtonOptions<
          dynamic,
          QuillToolbarBaseButtonExtraOptions
        >(
          afterButtonPressed: notifier.focusNode.requestFocus,
        );

    // QuillSimpleToolbar paints its own Container background defaulting
    // to Theme.canvasColor (near-black in our dark theme), which would
    // sit on top of any Material color wrapping the toolbar. The entry
    // card uses `surface.brighten()` (≈10pt lightness bump); brighten(15)
    // sits a tad lighter than the card without jumping into mid-gray
    // territory.
    final toolbarColor = context.colorScheme.surface.brighten(15);

    final toolbarConfig = QuillSimpleToolbarConfig(
      toolbarSize: height,
      toolbarSectionSpacing: 0,
      toolbarIconAlignment: WrapAlignment.start,
      color: toolbarColor,
      showUndo: false,
      showRedo: false,
      multiRowsDisplay: false,
      showColorButton: false,
      showFontFamily: false,
      showUnderLineButton: false,
      showBackgroundColorButton: false,
      showSubscript: false,
      showSuperscript: false,
      showIndent: false,
      showFontSize: false,
      showDividers: false,
      customButtons: [
        QuillToolbarCustomButtonOptions(
          icon: const Icon(Icons.horizontal_rule),
          tooltip: context.messages.editorInsertDivider,
          onPressed: () => insertDividerEmbed(controller),
        ),
      ],
      buttonOptions: QuillSimpleToolbarButtonOptions(
        base: baseButtonOptions,
      ),
    );

    final toolbar = Material(
      elevation: 1,
      color: toolbarColor,
      surfaceTintColor: Colors.transparent,
      child: QuillSimpleToolbar(
        controller: controller,
        config: toolbarConfig,
      ),
    );

    if (notifier.animationCompleted) {
      return SizedBox(
        height: height,
        child: toolbar,
      );
    } else {
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
            builder: (context, value, child) {
              return SizedBox(
                height: height * value,
                child: child, // child is the Text widget being animated
              );
            },
          );
    }
  }
}
