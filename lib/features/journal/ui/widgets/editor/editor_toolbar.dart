import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';

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

    final toolbar = Material(
      elevation: 1,
      child: QuillToolbar.simple(
        controller: controller,
        configurations: const QuillSimpleToolbarConfigurations(
          toolbarSize: height,
          toolbarSectionSpacing: 0,
          toolbarIconAlignment: WrapAlignment.start,
          showUndo: false,
          showRedo: false,
          multiRowsDisplay: false,
          showColorButton: false,
          showFontFamily: false,
          showBackgroundColorButton: false,
          showSubscript: false,
          showSuperscript: false,
          showIndent: false,
          showFontSize: false,
          showDividers: false,
        ),
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
