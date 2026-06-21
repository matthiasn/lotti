import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/duration_widget.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

/// Footer below an entry's body: the timer/[DurationWidget] for text entries
/// and — when the entry's map is toggled on — a map of its geolocation.
///
/// Saving is no longer here: the save action lives in the editor toolbar
/// (always present while editing), so the footer carries only read-only chrome.
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

    final showMap = entryState?.showMap ?? false;
    final tokens = context.designTokens;

    // A summary entry with no duration collapses the footer entirely (rather
    // than reserving an empty band) so it never adds dead space under a card.
    final hasDuration = entry is JournalEntry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDuration)
          Padding(
            // The read-only duration value line shares the body rhythm step so
            // the card reads evenly top to bottom.
            padding: EdgeInsets.only(top: tokens.spacing.cardItemSpacing),
            // Duration sits left under the content gutter.
            child: DurationWidget(item: entry, linkedFrom: linkedFrom),
          ),
        if (showMap)
          Padding(
            padding: EdgeInsets.only(
              top: tokens.spacing.step1,
              bottom: tokens.spacing.step3,
            ),
            child: MapWidget(geolocation: entry.geolocation),
          ),
      ],
    );
  }
}
