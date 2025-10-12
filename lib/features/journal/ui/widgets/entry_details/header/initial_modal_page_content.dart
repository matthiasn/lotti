import 'package:flutter/material.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/link_service.dart';
import 'package:lotti/widgets/modal/index.dart';
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
    final linkedFromId = this.linkedFromId;
    final link = this.link;

    return Column(
      children: [
        const SizedBox(height: 8),
        ModernToggleStarredItem(entryId: entryId),
        ModernTogglePrivateItem(entryId: entryId),
        ModernToggleFlaggedItem(entryId: entryId),
        ModernCopyEntryTextItem(entryId: entryId, markdown: false),
        ModernCopyEntryTextItem(entryId: entryId, markdown: true),
        ModernToggleMapItem(entryId: entryId),
        ModernDeleteItem(
          entryId: entryId,
          beamBack: !inLinkedEntries,
        ),
        ModernSpeechItem(
          entryId: entryId,
          pageIndexNotifier: pageIndexNotifier,
        ),
        ModernShareItem(entryId: entryId),
        ModernTagAddItem(pageIndexNotifier: pageIndexNotifier),
        ModernModalActionItem(
          icon: Icons.add_link,
          title: context.messages.journalLinkFromHint,
          onTap: () {
            getIt<LinkService>().linkFrom(entryId);
            Navigator.of(context).pop();
          },
        ),
        ModernModalActionItem(
          icon: MdiIcons.target,
          title: context.messages.journalLinkToHint,
          onTap: () {
            getIt<LinkService>().linkTo(entryId);
            Navigator.of(context).pop();
          },
        ),
        if (linkedFromId != null)
          ModernUnlinkItem(
            entryId: entryId,
            linkedFromId: linkedFromId,
          ),
        if (link != null)
          ModernToggleHiddenItem(
            entryId: entryId,
            link: link,
          ),
        ModernCopyImageItem(entryId: entryId),
      ],
    );
  }
}
