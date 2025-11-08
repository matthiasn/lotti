import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/ui/widgets/entry_detail_linked.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/time_service.dart';

/// Wrapper widget that listens to the active timer and rebuilds only
/// LinkedEntriesWidget instead of the entire page.
class LinkedEntriesWithTimer extends ConsumerWidget {
  const LinkedEntriesWithTimer({
    required this.item,
    required this.highlightedEntryId,
    this.entryKeyBuilder,
    super.key,
  });

  final JournalEntity item;
  final String? highlightedEntryId;
  final GlobalKey Function(String entryId)? entryKeyBuilder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeService = getIt<TimeService>();

    // Only react to changes of the active timer entry ID, not every tick.
    return StreamBuilder<String?>(
      stream: timeService.getStream().map((e) => e?.meta.id).distinct(),
      builder: (context, snapshot) {
        final activeTimerEntryId = snapshot.data;

        return LinkedEntriesWidget(
          item,
          entryKeyBuilder: entryKeyBuilder,
          highlightedEntryId: highlightedEntryId,
          activeTimerEntryId: activeTimerEntryId,
        );
      },
    );
  }
}
