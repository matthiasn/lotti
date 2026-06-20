import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/save_button_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/duration_widget.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/save_button.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

/// Footer below an entry's body: the timer/[DurationWidget] for text entries,
/// an inline [SaveButton] when shown inside a parent's linked-entries list, and
/// — when the entry's map is toggled on — a map of its geolocation.
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
    final tokens = context.designTokens;

    // Only summary entries with no duration and no unsaved edits would leave an
    // empty footer; collapsing it (rather than reserving an invisible
    // large-button height) removes the dead band that sat under every card.
    final hasDuration = entry is JournalEntry;
    final unsaved =
        inLinkedEntries &&
        (ref.watch(saveButtonControllerProvider(id: entryId)).value ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasDuration || unsaved)
          Padding(
            // The read-only duration value line shares the body rhythm step so
            // the card reads evenly top to bottom; the transient save button
            // sits close to its content with a tight gap, not a wide rhythm
            // band above it.
            padding: EdgeInsets.only(
              top: unsaved
                  ? tokens.spacing.step2
                  : tokens.spacing.cardItemSpacing,
            ),
            child: Row(
              children: [
                // Duration sits left under the content gutter (no longer
                // floating centered in the footer's dead space).
                if (hasDuration)
                  DurationWidget(item: entry, linkedFrom: linkedFrom),
                const Spacer(),
                if (unsaved) SaveButton(entryId: entryId),
              ],
            ),
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
