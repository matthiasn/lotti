import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_details_widget.dart';

class LinkedEntriesWidget extends StatefulWidget {
  const LinkedEntriesWidget({
    Key? key,
    this.navigatorKey,
    required this.item,
  }) : super(key: key);

  final GlobalKey? navigatorKey;
  final JournalEntity item;

  @override
  _LinkedEntriesWidgetState createState() => _LinkedEntriesWidgetState();
}

class _LinkedEntriesWidgetState extends State<LinkedEntriesWidget> {
  final JournalDb _db = getIt<JournalDb>();
  late Stream<List<String>> stream;

  @override
  void initState() {
    super.initState();
    stream = _db.watchLinkedEntityIds(widget.item.meta.id);
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<String>>(
        stream: stream,
        builder: (context, itemsSnapshot) {
          if (itemsSnapshot.data == null || itemsSnapshot.data!.isEmpty) {
            return Container();
          } else {
            List<String> itemIds = itemsSnapshot.data!;

            return Column(
              children: [
                Text(
                  localizations.journalLinkedEntriesLabel,
                  style: TextStyle(
                    color: AppColors.entryTextColor,
                    fontFamily: 'Oswald',
                  ),
                ),
                ...List.generate(
                  itemIds.length,
                  (int index) {
                    String itemId = itemIds.elementAt(index);

                    void onDismissed(DismissDirection _) {
                      String fromId = widget.item.meta.id;
                      String toId = itemId;
                      _db.removeLink(fromId: fromId, toId: toId);
                    }

                    return Dismissible(
                      key: ValueKey('Dismissible-$itemId'),
                      onDismissed: onDismissed,
                      background: Container(
                        color: AppColors.error,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6.0),
                              child: Text(
                                localizations.journalUnlinkText,
                                style: TextStyle(
                                  color: AppColors.bodyBgColor,
                                  fontFamily: 'Oswald',
                                  fontWeight: FontWeight.w300,
                                  fontSize: 24,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.link_off,
                                size: 32,
                                color: AppColors.bodyBgColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      child: EntryDetailWidget(
                        entryId: itemId,
                        popOnDelete: false,
                      ),
                    );
                  },
                  growable: true,
                )
              ],
            );
          }
        });
  }
}
