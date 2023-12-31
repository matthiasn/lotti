import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ToolbarWidget extends StatelessWidget {
  const ToolbarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: QuillToolbar(
        key: key,
        configurations: const QuillToolbarConfigurations(
          toolbarSize: 44,
          toolbarSectionSpacing: 0,
          toolbarIconAlignment: WrapAlignment.start,
          multiRowsDisplay: false,
          showColorButton: false,
          showFontFamily: false,
          showBackgroundColorButton: false,
          showSubscript: false,
          showSuperscript: false,
          showIndent: false,
          showFontSize: false,
        ),
      ),
    );
  }
}
