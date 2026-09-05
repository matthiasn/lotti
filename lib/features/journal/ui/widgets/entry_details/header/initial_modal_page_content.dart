import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/state/config_flag_provider.dart';
import 'package:lotti/features/design_system/components/action_modal/ds_action_modal.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/entry_toggle_chips.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/utils/consts.dart';
import 'package:material_ui/material_ui.dart';

/// The body of the entry `•••` menu.
///
/// Ordered by what the reader is looking for rather than by which widget was
/// written first: the entry's own state as chips, then the rows that change
/// what the entry *is* (labels, language, its text), then the media it
/// carries, then the links it sits in — and finally, alone below the list's
/// one divider, the row that destroys it.
///
/// Every visibility decision is taken here, before the rows exist. The row
/// widgets keep their own guards as a safety net, but the list must be the
/// one that decides: a row that hides itself after being listed still costs
/// its slot in the sheet's rhythm.
class InitialModalPageContent extends ConsumerWidget {
  const InitialModalPageContent({
    required this.entryId,
    required this.linkedFromId,
    required this.inLinkedEntries,
    required this.link,
    required this.pageIndexNotifier,
    super.key,
  });

  final String entryId;
  final String? linkedFromId;
  final bool inLinkedEntries;
  final EntryLink? link;
  final ValueNotifier<int> pageIndexNotifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkedFromId = this.linkedFromId;
    final link = this.link;

    // Watch entry state to conditionally include items
    final entryState = ref.watch(entryControllerProvider(entryId)).value;
    final entry = entryState?.entry;

    // Determine entry type for conditional rendering
    final isTask = entry is Task;
    final isJournalEntry = entry is JournalEntry;
    final isAudio = entry is JournalAudio;
    final isImage = entry is JournalImage;
    final hasGeolocation = entry?.geolocation != null && !isTask;
    final hasText =
        entryState != null &&
        ref
            .read(entryControllerProvider(entryId).notifier)
            .controller
            .document
            .toPlainText()
            .trim()
            .isNotEmpty;

    // Check if linked entry is a task (for cover art generation)
    final linkedEntryState = linkedFromId != null
        ? ref.watch(entryControllerProvider(linkedFromId)).value
        : null;
    final linkedIsTask = linkedEntryState?.entry is Task;

    final enableRatings =
        ref
            .watch(configFlagProvider(enableSessionRatingsFlag))
            .unwrapPrevious()
            .whenData((value) => value)
            .value ??
        false;

    return DsActionModalList(
      header: EntryToggleChips(entryId: entryId),
      // Destructive last and alone, on every entry type. It is the only row
      // in the sheet the user cannot undo, and the only one the divider
      // above it exists for.
      destructive: ModernDeleteItem(
        entryId: entryId,
        beamBack: !inLinkedEntries,
      ),
      children: [
        // What the entry is ────────────────────────────────────────────────
        // Labels - only for non-task entries (tasks have their own labels UI)
        if (!isTask && entry != null) ModernLabelsItem(entryId: entryId),

        // Language selection - only for tasks (tasks carry a per-entity
        // language code that drives AI / transcription behavior)
        if (isTask) ModernSetTaskLanguageItem(entryId: entryId),

        // Copy text - only if entry has text
        if (hasText) ModernCopyEntryTextItem(entryId: entryId, markdown: false),
        if (hasText) ModernCopyEntryTextItem(entryId: entryId, markdown: true),

        // Map toggle - only for entries with geolocation (not tasks)
        if (hasGeolocation) ModernToggleMapItem(entryId: entryId),

        // The media it carries ─────────────────────────────────────────────
        // Speech recognition - only for audio entries
        if (isAudio)
          ModernSpeechItem(
            entryId: entryId,
            pageIndexNotifier: pageIndexNotifier,
          ),

        // Cover art generation - only for audio linked to a task
        if (isAudio && linkedFromId != null && linkedIsTask)
          ModernGenerateCoverArtItem(
            entryId: entryId,
            linkedFromId: linkedFromId,
          ),

        // Set cover art - only for images linked to a task
        if (isImage && linkedFromId != null && linkedIsTask)
          ModernSetCoverArtItem(
            entryId: entryId,
            linkedFromId: linkedFromId,
          ),

        // Copy image - only for image entries
        if (isImage) ModernCopyImageItem(entryId: entryId),

        // Reveal media files in the platform file manager
        if (isImage || isAudio) ModernShowInFileManagerItem(entryId: entryId),

        // Share - only for image/audio entries
        if (isImage || isAudio) ModernShareItem(entryId: entryId),

        // Rate session - only for time entries in linked context with flag on
        if (isJournalEntry && inLinkedEntries && enableRatings)
          ModernRateSessionItem(entryId: entryId),

        // Where it sits ────────────────────────────────────────────────────
        // Link actions - always shown
        ModernLinkFromItem(entryId: entryId),
        ModernLinkToItem(entryId: entryId),

        // Toggle hidden - only when there's a link
        if (link != null) ModernToggleHiddenItem(link: link),

        // Unlink - only when viewing from a linked context
        if (linkedFromId != null)
          ModernUnlinkItem(entryId: entryId, linkedFromId: linkedFromId),
      ],
    );
  }
}
