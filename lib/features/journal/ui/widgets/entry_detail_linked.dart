import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_activity_filter_bar.dart';

class LinkedEntriesWidget extends ConsumerWidget {
  const LinkedEntriesWidget(
    this.item, {
    this.entryKeyBuilder,
    this.highlightedEntryId,
    this.activeTimerEntryId,
    this.hideTaskEntries = false,
    super.key,
  });

  final JournalEntity item;
  final GlobalKey Function(String entryId)? entryKeyBuilder;
  final String? highlightedEntryId;
  final String? activeTimerEntryId;
  final bool hideTaskEntries;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final orderedLinks = ref.watch(sortedLinkedEntriesProvider(item.id));

    final includeAiEntries = ref.watch(
      includeAiEntriesControllerProvider(id: item.id),
    );
    final activeKinds = ref.watch(
      linkedEntriesActivityFilterControllerProvider(id: item.id),
    );
    final showFlaggedOnly = ref.watch(
      showFlaggedOnlyControllerProvider(id: item.id),
    );

    if (orderedLinks.isEmpty) {
      return const SizedBox.shrink();
    }

    if (hideTaskEntries) {
      final hasNonTaskEntries = ref.watch(
        hasNonTaskLinkedEntriesProvider(item.id),
      );
      if (!hasNonTaskEntries) {
        return const SizedBox.shrink();
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinkedEntriesActivityFilterBar(entryId: item.id),
        ...List.generate(
          orderedLinks.length,
          (int index) {
            final link = orderedLinks.elementAt(index);
            final toId = link.toId;

            return RepaintBoundary(
              child: _FilteredEntryDetails(
                key: entryKeyBuilder != null
                    ? entryKeyBuilder!(toId)
                    : Key('${item.id}-$toId'),
                itemId: toId,
                linkedFrom: item,
                link: link,
                showAiEntry: includeAiEntries,
                hideTaskEntries: hideTaskEntries,
                isHighlighted: highlightedEntryId == toId,
                isActiveTimer: activeTimerEntryId == toId,
                activeKinds: activeKinds,
                showFlaggedOnly: showFlaggedOnly,
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Wraps [EntryDetailsWidget] so the activity-filter pill set and the
/// flagged-only toggle can hide entries without forcing the parent to
/// pre-resolve every linked entity.
class _FilteredEntryDetails extends ConsumerWidget {
  const _FilteredEntryDetails({
    required this.itemId,
    required this.showAiEntry,
    required this.activeKinds,
    required this.showFlaggedOnly,
    super.key,
    this.hideTaskEntries = false,
    this.linkedFrom,
    this.link,
    this.isHighlighted = false,
    this.isActiveTimer = false,
  });

  final String itemId;
  final bool showAiEntry;
  final bool hideTaskEntries;
  final bool isHighlighted;
  final bool isActiveTimer;
  final JournalEntity? linkedFrom;
  final EntryLink? link;
  final Set<LinkedEntryActivityFilter> activeKinds;
  final bool showFlaggedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(entryControllerProvider(id: itemId)).value?.entry;
    if (entry != null) {
      final kind = LinkedEntryActivityFilter.fromEntity(entry);
      if (kind != null && !activeKinds.contains(kind)) {
        return const SizedBox.shrink();
      }
      if (showFlaggedOnly && entry.meta.flag != EntryFlag.import) {
        return const SizedBox.shrink();
      }
    }
    return EntryDetailsWidget(
      itemId: itemId,
      linkedFrom: linkedFrom,
      link: link,
      showAiEntry: showAiEntry,
      hideTaskEntries: hideTaskEntries,
      isHighlighted: isHighlighted,
      isActiveTimer: isActiveTimer,
    );
  }
}
