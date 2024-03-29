import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/widgets/journal/entry_details_widget.dart';
import 'package:lotti/widgets/modal/modal_action_sheet.dart';
import 'package:lotti/widgets/modal/modal_sheet_action.dart';

class LinkedEntriesWidget extends StatelessWidget {
  const LinkedEntriesWidget({
    required this.item,
    super.key,
  });

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<String>>(
      stream: db.watchLinkedEntityIds(item.meta.id),
      builder: (context, itemsSnapshot) {
        if (itemsSnapshot.data == null || itemsSnapshot.data!.isEmpty) {
          return Container();
        } else {
          final itemIds = itemsSnapshot.data!;

          return Column(
            children: [
              Text(
                localizations.journalLinkedEntriesLabel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              ...List.generate(
                itemIds.length,
                (int index) {
                  final itemId = itemIds.elementAt(index);

                  Future<void> unlink() async {
                    const unlinkKey = 'unlinkKey';
                    final result = await showModalActionSheet<String>(
                      context: context,
                      title: localizations.journalUnlinkQuestion,
                      actions: [
                        ModalSheetAction(
                          icon: Icons.warning,
                          label: localizations.journalUnlinkConfirm,
                          key: unlinkKey,
                          isDestructiveAction: true,
                          isDefaultAction: true,
                        ),
                      ],
                    );

                    if (result == unlinkKey) {
                      await db.removeLink(
                        fromId: item.meta.id,
                        toId: itemId,
                      );
                    }
                  }

                  return EntryDetailWidget(
                    key: Key('$itemId-$itemId'),
                    itemId: itemId,
                    popOnDelete: false,
                    unlinkFn: unlink,
                    parentTags: item.meta.tagIds?.toSet(),
                    linkedFromId: item.meta.id,
                  );
                },
              ),
            ],
          );
        }
      },
    );
  }
}
