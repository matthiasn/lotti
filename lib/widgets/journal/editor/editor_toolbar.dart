import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:lotti/blocs/journal/entry_cubit.dart';
import 'package:lotti/blocs/journal/entry_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class ToolbarWidget extends StatelessWidget {
  ToolbarWidget({
    super.key,
    this.toolbarIconSize = 20,
    this.unlinkFn,
  });

  final LinkService linkService = getIt<LinkService>();
  final double toolbarIconSize;
  final WrapAlignment toolbarIconAlignment = WrapAlignment.start;
  final Future<void> Function()? unlinkFn;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final iconTheme = QuillIconTheme(
      iconSelectedColor: styleConfig().cardColor,
      iconSelectedFillColor: styleConfig().primaryColor,
      iconUnselectedColor: styleConfig().secondaryTextColor,
    );

    return BlocBuilder<EntryCubit, EntryState>(
      builder: (
        context,
        EntryState snapshot,
      ) {
        final cubit = context.read<EntryCubit>();
        final controller = cubit.controller;
        final id = context.read<EntryCubit>().entryId;

        return QuillToolbar(
          key: key,
          toolbarSize: 44,
          toolbarSectionSpacing: 0,
          toolbarIconAlignment: toolbarIconAlignment,
          multiRowsDisplay: false,
          children: [
            ToggleStyleButton(
              attribute: Attribute.bold,
              icon: Icons.format_bold,
              iconSize: toolbarIconSize,
              controller: controller,
              afterButtonPressed: cubit.focus,
              iconTheme: iconTheme,
            ),
            ToggleStyleButton(
              attribute: Attribute.italic,
              icon: Icons.format_italic,
              iconSize: toolbarIconSize,
              controller: controller,
              afterButtonPressed: cubit.focus,
              iconTheme: iconTheme,
            ),
            ToggleStyleButton(
              attribute: Attribute.underline,
              icon: Icons.format_underline,
              iconSize: toolbarIconSize,
              controller: controller,
              afterButtonPressed: cubit.focus,
              iconTheme: iconTheme,
            ),
            ToggleStyleButton(
              attribute: Attribute.strikeThrough,
              icon: Icons.format_strikethrough,
              iconSize: toolbarIconSize,
              controller: controller,
              afterButtonPressed: cubit.focus,
              iconTheme: iconTheme,
            ),
            ToggleStyleButton(
              attribute: Attribute.inlineCode,
              icon: Icons.code,
              iconSize: toolbarIconSize,
              controller: controller,
              afterButtonPressed: cubit.focus,
              iconTheme: iconTheme,
            ),
            SelectHeaderStyleButton(
              controller: controller,
              afterButtonPressed: cubit.focus,
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
              afterButtonPressed: cubit.focus,
              icon: Icons.format_list_bulleted,
              iconSize: toolbarIconSize,
              iconTheme: iconTheme,
            ),
            ToggleStyleButton(
              attribute: Attribute.ol,
              controller: controller,
              afterButtonPressed: cubit.focus,
              icon: Icons.format_list_numbered,
              iconSize: toolbarIconSize,
              iconTheme: iconTheme,
            ),
            ToggleStyleButton(
              attribute: Attribute.codeBlock,
              controller: controller,
              afterButtonPressed: cubit.focus,
              icon: Icons.code,
              iconSize: toolbarIconSize,
              iconTheme: iconTheme,
            ),
            ClearFormatButton(
              icon: Icons.format_clear,
              iconSize: toolbarIconSize,
              controller: controller,
              afterButtonPressed: cubit.focus,
              iconTheme: iconTheme,
            ),
            IconButton(
              icon: Icon(
                Icons.add_link,
                color: styleConfig().secondaryTextColor,
              ),
              iconSize: toolbarIconSize,
              tooltip: localizations.journalLinkFromHint,
              onPressed: () => linkService.linkFrom(id),
            ),
            IconButton(
              icon: Icon(
                MdiIcons.target,
                color: styleConfig().secondaryTextColor,
              ),
              iconSize: toolbarIconSize,
              tooltip: localizations.journalLinkToHint,
              onPressed: () => linkService.linkTo(id),
            ),
            if (unlinkFn != null)
              IconButton(
                icon: Icon(
                  MdiIcons.closeCircleOutline,
                  color: styleConfig().secondaryTextColor,
                ),
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
