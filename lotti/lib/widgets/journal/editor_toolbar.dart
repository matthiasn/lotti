import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/link_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ToolbarWidget extends StatelessWidget {
  final LinkService _linkService = getIt<LinkService>();
  final JournalEntity? _journalEntity;

  ToolbarWidget({
    Key? key,
    required QuillController controller,
    JournalEntity? journalEntity,
    double toolbarIconSize = 24.0,
    required Function saveFn,
    this.iconTheme,
  })  : _controller = controller,
        _saveFn = saveFn,
        _journalEntity = journalEntity,
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
        if (_journalEntity != null)
          IconButton(
            icon: const Icon(Icons.add_link),
            iconSize: _toolbarIconSize,
            tooltip: 'Link from',
            onPressed: () => _linkService.linkFrom(_journalEntity!.meta.id),
          ),
        if (_journalEntity != null)
          IconButton(
            icon: const Icon(MdiIcons.target),
            iconSize: _toolbarIconSize,
            tooltip: 'Link to',
            onPressed: () => _linkService.linkTo(_journalEntity!.meta.id),
          ),
      ],
    );
  }
}
