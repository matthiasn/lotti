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

    return Column(
      children: [
        StreamBuilder<List<String>>(
          stream: stream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<String>> snapshot,
          ) {
            if (snapshot.data == null || snapshot.data!.isEmpty) {
              return Container();
            } else {
              List<String> itemIds = snapshot.data!;
              return StreamBuilder<List<String>>(
                  stream: _db.watchSortedLinkedEntityIds(itemIds),
                  builder: (context, itemsSnapshot) {
                    if (itemsSnapshot.data == null ||
                        itemsSnapshot.data!.isEmpty) {
                      return Container();
                    } else {
                      List<String> itemIds = itemsSnapshot.data!;

                      return Container(
                        margin: const EdgeInsets.all(8.0),
                        child: Column(
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

                                void unlink(DismissDirection direction) {
                                  String fromId = widget.item.meta.id;
                                  String toId = itemId;
                                  _db.removeLink(fromId: fromId, toId: toId);
                                }

                                return Dismissible(
                                  key: Key(itemId),
                                  onDismissed: unlink,
                                  child: EntryDetailWidget(
                                    key: Key(itemId),
                                    entryId: itemId,
                                    popOnDelete: false,
                                  ),
                                );
                              },
                              growable: true,
                            )
                          ],
                        ),
                      );
                    }
                  });
            }
          },
        ),
      ],
    );
  }
}
