import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/themes/theme.dart';
import 'package:lotti/widgets/journal/journal_card.dart';

class LinkedFromEntriesWidget extends StatelessWidget {
  const LinkedFromEntriesWidget({
    required this.item,
    super.key,
  });

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return StreamBuilder<List<JournalEntity>>(
      stream: getIt<JournalDb>().watchLinkedToEntities(linkedTo: item.meta.id),
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
                    color: styleConfig().primaryTextColor,
                    fontFamily: 'Oswald',
                  ),
                ),
                ...List.generate(
                  items.length,
                  (int index) {
                    final item = items.elementAt(index);
                    return item.maybeMap(
                      journalImage: (JournalImage image) {
                        return JournalImageCard(
                          item: image,
                          key: Key('${item.meta.id}-${item.meta.id}'),
                        );
                      },
                      orElse: () {
                        return JournalCard(
                          item: item,
                          key: Key('${item.meta.id}-${item.meta.id}'),
                        );
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
