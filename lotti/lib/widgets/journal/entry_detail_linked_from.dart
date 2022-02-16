import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/journal_card.dart';

class LinkedFromEntriesWidget extends StatefulWidget {
  const LinkedFromEntriesWidget({
    Key? key,
    this.navigatorKey,
    required this.item,
  }) : super(key: key);

  final GlobalKey? navigatorKey;
  final JournalEntity item;

  @override
  _LinkedFromEntriesWidgetState createState() =>
      _LinkedFromEntriesWidgetState();
}

class _LinkedFromEntriesWidgetState extends State<LinkedFromEntriesWidget> {
  final JournalDb _db = getIt<JournalDb>();
  late Stream<List<JournalEntity>> stream;

  @override
  void initState() {
    super.initState();
    stream = _db.watchLinkedToEntities(linkedTo: widget.item.meta.id);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<JournalEntity>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        if (snapshot.data == null || snapshot.data!.isEmpty) {
          return Container();
        } else {
          List<JournalEntity> items = snapshot.data!;
          return Container(
            margin: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Text(
                  'Linked from:',
                  style: TextStyle(
                    color: AppColors.entryTextColor,
                    fontFamily: 'Oswald',
                  ),
                ),
                ...List.generate(
                  items.length,
                  (int index) {
                    JournalEntity item = items.elementAt(index);
                    return item.maybeMap(journalImage: (JournalImage image) {
                      return JournalImageCard(
                        item: image,
                        index: index,
                      );
                    }, orElse: () {
                      return JournalCard(
                        item: item,
                        index: index,
                      );
                    });
                  },
                  growable: true,
                )
              ],
            ),
          );
        }
      },
    );
  }
}
