import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/journal_card.dart';

class LinkedFromEntriesWidget extends StatefulWidget {
  const LinkedFromEntriesWidget({
    super.key,
    this.navigatorKey,
    required this.item,
  });

  final GlobalKey? navigatorKey;
  final JournalEntity item;

  @override
  State<LinkedFromEntriesWidget> createState() =>
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
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<JournalEntity>>(
      stream: stream,
      builder: (
        BuildContext context,
        AsyncSnapshot<List<JournalEntity>> snapshot,
      ) {
        if (snapshot.data == null || snapshot.data!.isEmpty) {
          return Container();
        } else {
          final items = snapshot.data!;
          return Container(
            margin: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(
                  localizations.journalLinkedFromLabel,
                  style: TextStyle(
                    color: AppColors.entryTextColor,
                    fontFamily: 'Oswald',
                  ),
                ),
                ...List.generate(
                  items.length,
                  (int index) {
                    final item = items.elementAt(index);
                    return item.maybeMap(
                      journalImage: (JournalImage image) {
                        return JournalImageCard(item: image);
                      },
                      orElse: () {
                        return JournalCard(item: item);
                      },
                    );
                  },
                )
              ],
            ),
          );
        }
      },
    );
  }
}
