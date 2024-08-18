import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/features/journal/ui/widgets/journal_card.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/themes/theme.dart';

class LinkedFromEntriesWidget extends StatelessWidget {
  const LinkedFromEntriesWidget({
    required this.item,
    super.key,
  });

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
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
          return Column(
            children: [
              Text(
                context.messages.journalLinkedFromLabel,
                style: TextStyle(
                  color: context.colorScheme.outline,
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
                        showLinkedDuration: true,
                      );
                    },
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
