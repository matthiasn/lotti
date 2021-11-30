import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class ToolbarWidget extends StatelessWidget {
  const ToolbarWidget({
    Key? key,
    required QuillController controller,
    double toolbarIconSize = 24.0,
    required Function saveFn,
    this.iconTheme,
  })  : _controller = controller,
        _saveFn = saveFn,
        _toolbarIconSize = toolbarIconSize,
        super(key: key);

  final QuillController _controller;
  final double _toolbarIconSize;
  final Function _saveFn;
  final WrapAlignment toolbarIconAlignment = WrapAlignment.start;
  final QuillIconTheme? iconTheme;

  @override
  Widget build(BuildContext context) {
    return QuillToolbar(
      key: key,
      toolbarHeight: _toolbarIconSize * 2,
      toolbarSectionSpacing: 4,
      toolbarIconAlignment: toolbarIconAlignment,
      multiRowsDisplay: false,
      children: [
        IconButton(
          icon: const Icon(Icons.save),
          iconSize: _toolbarIconSize,
          tooltip: 'Save',
          onPressed: () => _saveFn(),
        ),
        ToggleStyleButton(
          attribute: Attribute.bold,
          icon: Icons.format_bold,
          iconSize: _toolbarIconSize,
          controller: _controller,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.italic,
          icon: Icons.format_italic,
          iconSize: _toolbarIconSize,
          controller: _controller,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.underline,
          icon: Icons.format_underline,
          iconSize: _toolbarIconSize,
          controller: _controller,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.inlineCode,
          icon: Icons.code,
          iconSize: _toolbarIconSize,
          controller: _controller,
          iconTheme: iconTheme,
        ),
        ClearFormatButton(
          icon: Icons.format_clear,
          iconSize: _toolbarIconSize,
          controller: _controller,
          iconTheme: iconTheme,
        ),
        SelectHeaderStyleButton(
          controller: _controller,
          iconSize: _toolbarIconSize,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.ol,
          controller: _controller,
          icon: Icons.format_list_numbered,
          iconSize: _toolbarIconSize,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.ul,
          controller: _controller,
          icon: Icons.format_list_bulleted,
          iconSize: _toolbarIconSize,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.codeBlock,
          controller: _controller,
          icon: Icons.code,
          iconSize: _toolbarIconSize,
          iconTheme: iconTheme,
        ),
      ],
    );
  }
}
