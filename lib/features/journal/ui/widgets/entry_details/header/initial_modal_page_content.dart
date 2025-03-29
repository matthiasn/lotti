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
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class InitialModalPageContent extends StatelessWidget {
  const InitialModalPageContent({
    required this.entryId,
    required this.linkedFromId,
    required this.inLinkedEntries,
    required this.link,
    required this.pageIndexNotifier,
    super.key,
  });

  final String entryId;
  final String? linkedFromId;
  final bool inLinkedEntries;
  final EntryLink? link;
  final ValueNotifier<int> pageIndexNotifier;

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
        SpeechModalListTile(
          entryId: entryId,
          pageIndexNotifier: pageIndexNotifier,
        ),
        ShareButtonListTile(entryId: entryId),
        TagAddListTile(
          entryId: entryId,
          pageIndexNotifier: pageIndexNotifier,
        ),
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
