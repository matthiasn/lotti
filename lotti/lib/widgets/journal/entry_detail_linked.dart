import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/main.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/journal_card.dart';

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
  late Stream<List<JournalEntity>> stream;

  @override
  void initState() {
    super.initState();
    stream = _db.watchLinkedEntities(linkedFrom: widget.item.meta.id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<List<JournalEntity>>(
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
                      'Linked:',
                      style: TextStyle(
                        color: AppColors.entryTextColor,
                        fontFamily: 'Oswald',
                      ),
                    ),
                    ...List.generate(
                      items.length,
                      (int index) {
                        JournalEntity item = items.elementAt(index);
                        return item.maybeMap(
                            journalImage: (JournalImage image) {
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
        ),
      ],
    );
  }
}
