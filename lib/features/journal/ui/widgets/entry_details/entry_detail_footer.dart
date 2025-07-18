import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/duration_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

class EntryDetailFooter extends ConsumerWidget {
  const EntryDetailFooter({
    required this.entryId,
    required this.linkedFrom,
    this.inLinkedEntries = false,
    super.key,
  });

  final String entryId;
  final JournalEntity? linkedFrom;
  final bool inLinkedEntries;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final provider = entryControllerProvider(id: entryId);
    final entryState = ref.watch(provider).value;
    final entry = entryState?.entry;

    if (entry == null) {
      return const SizedBox.shrink();
    }

    final showMap = entryState?.showMap ?? false;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 100),
            if (entry is JournalEntry)
              DurationWidget(item: entry, linkedFrom: linkedFrom),
            if (inLinkedEntries)
              SaveButton(entryId: entryId)
            else
              const SizedBox(width: 60),
          ],
        ),
        Visibility(
          visible: showMap,
          child: Padding(
            padding: const EdgeInsets.only(top: 5, bottom: 10),
            child: MapWidget(geolocation: entry.geolocation),
          ),
        ),
      ],
    );
  }
}
