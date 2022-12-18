import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/entry_details_widget.dart';

class LinkedEntriesWidget extends StatelessWidget {
  const LinkedEntriesWidget({
    super.key,
    required this.itemId,
  });

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final db = getIt<JournalDb>();
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<String>>(
      stream: db.watchLinkedEntityIds(itemId),
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
                  color: styleConfig().primaryTextColor,
                  fontFamily: 'Oswald',
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
                        SheetAction(
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
                        fromId: itemId,
                        toId: itemId,
                      );
                    }
                  }

                  return EntryDetailWidget(
                    key: Key('$itemId-$itemId'),
                    itemId: itemId,
                    popOnDelete: false,
                    unlinkFn: unlink,
                  );
                },
              )
            ],
          );
        }
      },
    );
  }
}
