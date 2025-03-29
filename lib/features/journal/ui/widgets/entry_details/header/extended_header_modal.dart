import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/delete_icon_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/extended_header_items.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/share_button_widget.dart';
import 'package:lotti/features/journal/ui/widgets/tags/tag_add.dart';
import 'package:lotti/features/speech/ui/widgets/speech_modal/speech_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/utils/modals.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:wolt_modal_sheet/wolt_modal_sheet.dart';

class ExtendedHeaderModal {
  static Future<void> show({
    required BuildContext context,
    required String entryId,
    required String? linkedFromId,
    required EntryLink? link,
    required bool inLinkedEntries,
  }) async {
    final initialModalPage = ModalUtils.modalSheetPage(
      context: context,
      title: context.messages.entryActions,
      child: _InitialModalPageContent(
        entryId: entryId,
        linkedFromId: linkedFromId,
        inLinkedEntries: inLinkedEntries,
        link: link,
      ),
    );

    return WoltModalSheet.show<void>(
      context: context,
      pageListBuilder: (modalSheetContext) {
        return [
          initialModalPage,
        ];
      },
      modalTypeBuilder: ModalUtils.modalTypeBuilder,
      barrierDismissible: true,
    );
  }
}

class _InitialModalPageContent extends StatelessWidget {
  const _InitialModalPageContent({
    required this.entryId,
    required this.linkedFromId,
    required this.inLinkedEntries,
    required this.link,
  });

  final String entryId;
  final String? linkedFromId;
  final bool inLinkedEntries;
  final EntryLink? link;

  @override
  Widget build(BuildContext context) {
    final linkService = getIt<LinkService>();
    final linkedFromId = this.linkedFromId;
    final link = this.link;

    return Column(
      children: [
        TogglePrivateListTile(entryId: entryId),
        ToggleMapListTile(entryId: entryId),
        DeleteIconListTile(
          entryId: entryId,
          beamBack: !inLinkedEntries,
        ),
        SpeechModalListTile(entryId: entryId),
        ShareButtonListTile(entryId: entryId),
        TagAddListTile(entryId: entryId),
        ListTile(
          leading: const Icon(Icons.add_link),
          title: Text(context.messages.journalLinkFromHint),
          onTap: () {
            linkService.linkFrom(entryId);
            Navigator.of(context).pop();
          },
        ),
        ListTile(
          leading: Icon(MdiIcons.target),
          title: Text(context.messages.journalLinkToHint),
          onTap: () {
            linkService.linkTo(entryId);
            Navigator.of(context).pop();
          },
        ),
        if (linkedFromId != null)
          UnlinkListTile(
            entryId: entryId,
            linkedFromId: linkedFromId,
          ),
        if (link != null)
          ToggleHiddenListTile(
            entryId: entryId,
            link: link,
          ),
        CopyImageListTile(entryId: entryId),
        verticalModalSpacer,
      ],
    );
  }
}
