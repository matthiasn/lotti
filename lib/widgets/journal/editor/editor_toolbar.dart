import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/link_service.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ToolbarWidget extends StatelessWidget {
  ToolbarWidget({
    super.key,
    this.toolbarIconSize = 20,
    this.iconTheme,
    this.unlinkFn,
  });

  final LinkService linkService = getIt<LinkService>();
  final double toolbarIconSize;
  final WrapAlignment toolbarIconAlignment = WrapAlignment.start;
  final QuillIconTheme? iconTheme;
  final Future<void> Function()? unlinkFn;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState snapshot,
      ) {
        final controller = context.read<EntryCubit>().controller;
        final id = context.read<EntryCubit>().entryId;

        return QuillToolbar(
          key: key,
          toolbarHeight: toolbarIconSize * 2,
          toolbarSectionSpacing: 0,
          toolbarIconAlignment: toolbarIconAlignment,
          multiRowsDisplay: false,
          children: [
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
            ToggleStyleButton(
              attribute: Attribute.strikeThrough,
              icon: Icons.format_strikethrough,
              iconSize: toolbarIconSize,
              controller: controller,
              iconTheme: iconTheme,
            ),
            ToggleStyleButton(
              attribute: Attribute.inlineCode,
              icon: Icons.code,
              iconSize: toolbarIconSize,
              controller: controller,
              iconTheme: iconTheme,
            ),
            SelectHeaderStyleButton(
              controller: controller,
              iconSize: toolbarIconSize,
              iconTheme: iconTheme,
              attributes: const [
                Attribute.h1,
                Attribute.h2,
              ],
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
            ClearFormatButton(
              icon: Icons.format_clear,
              iconSize: toolbarIconSize,
              controller: controller,
              iconTheme: iconTheme,
            ),
            IconButton(
              icon: const Icon(Icons.add_link),
              iconSize: toolbarIconSize,
              tooltip: localizations.journalLinkFromHint,
              onPressed: () => linkService.linkFrom(id),
            ),
            IconButton(
              icon: const Icon(MdiIcons.target),
              iconSize: toolbarIconSize,
              tooltip: localizations.journalLinkToHint,
              onPressed: () => linkService.linkTo(id),
            ),
            if (unlinkFn != null)
              IconButton(
                icon: const Icon(MdiIcons.closeCircleOutline),
                iconSize: toolbarIconSize,
                tooltip: localizations.journalUnlinkHint,
                onPressed: unlinkFn,
              ),
          ],
        );
      },
    );
  }
}
