import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/duration_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_widget.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

class EntryDetailFooter extends ConsumerWidget {
  const EntryDetailFooter({
    required this.entryId,
    required this.linkedFrom,
    super.key,
  });

  final String entryId;
  final JournalEntity? linkedFrom;

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

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              EntryDatetimeWidget(entryId: entry.meta.id),
              DurationWidget(
                item: entry,
                linkedFrom: linkedFrom,
              ),
            ],
          ),
        ),
        Visibility(
          visible: entryState?.showMap ?? false,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            child: MapWidget(
              geolocation: entry.geolocation,
            ),
          ),
        ),
      ],
    );
  }
}
