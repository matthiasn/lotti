import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details/header/modern_action_items.dart';
import 'package:lotti/themes/theme.dart';

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
    final entryState = ref.watch(entryControllerProvider(id: entryId)).value;
    final entry = entryState?.entry;

    // Determine entry type for conditional rendering
    final isTask = entry is Task;
    final isAudio = entry is JournalAudio;
    final isImage = entry is JournalImage;
    final hasGeolocation = entry?.geolocation != null && !isTask;
    final hasText = entryState != null &&
        ref
            .read(entryControllerProvider(id: entryId).notifier)
            .controller
            .document
            .toPlainText()
            .trim()
            .isNotEmpty;

    // Check if linked entry is a task (for cover art generation)
    final linkedEntryState = linkedFromId != null
        ? ref.watch(entryControllerProvider(id: linkedFromId)).value
        : null;
    final linkedIsTask = linkedEntryState?.entry is Task;

    final items = <Widget>[
      // Always shown for all entries
      ModernToggleStarredItem(entryId: entryId),
      ModernTogglePrivateItem(entryId: entryId),
      ModernToggleFlaggedItem(entryId: entryId),

      // Labels - only for non-task entries
      if (!isTask && entry != null) ModernLabelsItem(entryId: entryId),

      // Copy text - only if entry has text
      if (hasText) ModernCopyEntryTextItem(entryId: entryId, markdown: false),
      if (hasText) ModernCopyEntryTextItem(entryId: entryId, markdown: true),

      // Map toggle - only for entries with geolocation (not tasks)
      if (hasGeolocation) ModernToggleMapItem(entryId: entryId),

      // Delete - always shown
      ModernDeleteItem(
        entryId: entryId,
        beamBack: !inLinkedEntries,
      ),

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

      // Share - only for image/audio entries
      if (isImage || isAudio) ModernShareItem(entryId: entryId),

      // Tags - always shown
      ModernTagAddItem(pageIndexNotifier: pageIndexNotifier),

      // Link actions - always shown
      ModernLinkFromItem(entryId: entryId),
      ModernLinkToItem(entryId: entryId),

      // Unlink - only when viewing from a linked context
      if (linkedFromId != null)
        ModernUnlinkItem(
          entryId: entryId,
          linkedFromId: linkedFromId,
        ),

      // Toggle hidden - only when there's a link
      if (link != null)
        ModernToggleHiddenItem(
          link: link,
        ),

      // Copy image - only for image entries
      if (isImage) ModernCopyImageItem(entryId: entryId),
    ];

    return _ActionMenuList(items: items);
  }
}

/// Builds the list of action items with dividers between them.
class _ActionMenuList extends StatelessWidget {
  const _ActionMenuList({required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          items[i],
          if (i < items.length - 1)
            Divider(
              height: 1,
              thickness: 0.5,
              indent: AppTheme.cardPadding,
              endIndent: AppTheme.cardPadding,
              color: context.colorScheme.outline
                  .withValues(alpha: AppTheme.alphaDivider),
            ),
        ],
      ],
    );
  }
}
