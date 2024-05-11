import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/widgets/journal/entry_details/duration_widget.dart';
import 'package:lotti/widgets/journal/entry_details/entry_datetime_widget.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

class EntryDetailFooter extends ConsumerWidget {
  const EntryDetailFooter({
    required this.entryId,
    super.key,
  });

  final String entryId;

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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            EntryDatetimeWidget(entryId: entry.meta.id),
            DurationWidget(item: entry),
          ],
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
