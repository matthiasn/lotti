import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/editor_state_service.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ToolbarWidget extends StatelessWidget {
  final LinkService linkService = getIt<LinkService>();
  final JournalEntity? journalEntity;
  final QuillController controller;
  final double toolbarIconSize;
  final String? id;
  final Function saveFn;
  final WrapAlignment toolbarIconAlignment = WrapAlignment.start;
  final QuillIconTheme? iconTheme;

  ToolbarWidget({
    Key? key,
    required this.id,
    required this.controller,
    required this.saveFn,
    this.journalEntity,
    this.toolbarIconSize = 24.0,
    this.iconTheme,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return QuillToolbar(
      key: key,
      toolbarHeight: toolbarIconSize * 2,
      toolbarSectionSpacing: 4,
      toolbarIconAlignment: toolbarIconAlignment,
      multiRowsDisplay: true,
      children: [
        SaveButton(
          id: id,
          toolbarIconSize: toolbarIconSize,
          localizations: localizations,
          saveFn: saveFn,
        ),
        ToggleStyleButton(
          attribute: Attribute.bold,
          icon: Icons.format_bold,
          iconSize: toolbarIconSize,
          controller: controller,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.italic,
          icon: Icons.format_italic,
          iconSize: toolbarIconSize,
          controller: controller,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.underline,
          icon: Icons.format_underline,
          iconSize: toolbarIconSize,
          controller: controller,
          iconTheme: iconTheme,
        ),
        // TODO: bring back when supported by delta_markdown
        // ToggleStyleButton(
        //   attribute: Attribute.inlineCode,
        //   icon: Icons.code,
        //   iconSize: toolbarIconSize,
        //   controller: controller,
        //   iconTheme: iconTheme,
        // ),
        SelectHeaderStyleButton(
          controller: controller,
          iconSize: toolbarIconSize,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.ul,
          controller: controller,
          icon: Icons.format_list_bulleted,
          iconSize: toolbarIconSize,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.ol,
          controller: controller,
          icon: Icons.format_list_numbered,
          iconSize: toolbarIconSize,
          iconTheme: iconTheme,
        ),
        ToggleStyleButton(
          attribute: Attribute.codeBlock,
          controller: controller,
          icon: Icons.code,
          iconSize: toolbarIconSize,
          iconTheme: iconTheme,
        ),
        if (journalEntity != null)
          IconButton(
            icon: const Icon(Icons.add_link),
            iconSize: toolbarIconSize,
            tooltip: localizations.journalLinkFromHint,
            onPressed: () => linkService.linkFrom(journalEntity!.meta.id),
          ),
        if (journalEntity != null)
          IconButton(
            icon: const Icon(MdiIcons.target),
            iconSize: toolbarIconSize,
            tooltip: localizations.journalLinkToHint,
            onPressed: () => linkService.linkTo(journalEntity!.meta.id),
          ),
        ClearFormatButton(
          icon: Icons.format_clear,
          iconSize: toolbarIconSize,
          controller: controller,
          iconTheme: iconTheme,
        ),
      ],
    );
  }
}

class SaveButton extends StatelessWidget {
  final EditorStateService editorStateService = getIt<EditorStateService>();

  SaveButton({
    Key? key,
    required this.id,
    required this.toolbarIconSize,
    required this.localizations,
    required this.saveFn,
  }) : super(key: key);

  final String? id;
  final double toolbarIconSize;
  final AppLocalizations localizations;
  final Function saveFn;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
        stream: editorStateService.getUnsavedStream(id),
        builder: (context, snapshot) {
          bool unsaved = snapshot.data ?? false;
          return IconButton(
            icon: const Icon(Icons.save),
            color: unsaved ? AppColors.error : Colors.black,
            iconSize: toolbarIconSize,
            tooltip: localizations.journalToolbarSaveHint,
            onPressed: () => saveFn(),
          );
        });
  }
}
