import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ToolbarWidget extends StatelessWidget {
  const ToolbarWidget({
    required this.controller,
    super.key,
  });

  final QuillController controller;

  @override
  Widget build(BuildContext context) {
    const duration = Duration(milliseconds: 400);
    const curve = Curves.easeInOutQuint;
    const height = 60.0;

    return Material(
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
    )
        .animate()
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
