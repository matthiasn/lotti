import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/ai_response_type.dart';
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/journal/state/entry_controller.dart';
import 'package:lotti/features/journal/state/linked_entries_activity_filter.dart';
import 'package:lotti/features/journal/state/linked_entries_controller.dart';
import 'package:lotti/features/journal/ui/widgets/entry_details_widget.dart';
import 'package:lotti/features/journal/ui/widgets/linked_entries_activity_filter_bar.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the outgoing linked-entries list for `item` (the entries this
/// task/entry links to), in the order from [sortedLinkedEntriesProvider].
///
/// Above the list sits the [LinkedEntriesActivityFilterBar] (Timer/Audio/
/// Images pills + sort). Each link is rendered through [_FilteredEntryDetails],
/// which applies the active pill set and the flagged-only toggle per row, and
/// each row carries an optional caller-provided [GlobalKey] (for scroll-to),
/// highlight, and active-timer flags. When `hideTaskEntries` is set the list
/// collapses entirely if it would contain only tasks (they appear in the
/// dedicated Linked Tasks section instead). When the filters hide every entry
/// the list says so and offers to clear them, rather than going blank.
class LinkedEntriesWidget extends ConsumerWidget {
  const LinkedEntriesWidget(
    this.item, {
    this.entryKeyBuilder,
    this.highlightedEntryId,
    this.activeTimerEntryId,
    this.hideTaskEntries = false,
    this.showActivityFilters = true,
    super.key,
  });

  final JournalEntity item;
  final GlobalKey Function(String entryId)? entryKeyBuilder;
  final String? highlightedEntryId;
  final String? activeTimerEntryId;
  final bool hideTaskEntries;

  /// Whether the Timer/Audio/Images pills and the sort sit above the list.
  /// A short list — a check-in with a recording and a comment — has nothing
  /// to filter, and the pills would only read as noise.
  final bool showActivityFilters;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final orderedLinks = ref.watch(sortedLinkedEntriesProvider(item.id));

    // The filters apply only while their bar is there to undo them: a
    // list whose host hides the bar shows everything, so a filter set
    // before the bar went away cannot strand cards out of reach.
    final activeKinds = showActivityFilters
        ? ref.watch(linkedEntriesActivityFilterControllerProvider(item.id))
        : LinkedEntryActivityFilter.values.toSet();
    final showFlaggedOnly =
        showActivityFilters &&
        ref.watch(showFlaggedOnlyControllerProvider(item.id));

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

    // Only a narrowing filter can empty the list, so the entries are only
    // resolved (and watched) while one is set.
    final isNarrowed =
        showFlaggedOnly ||
        activeKinds.length < LinkedEntryActivityFilter.values.length;
    final filteredToNothing =
        isNarrowed &&
        !ref
            .watch(resolvedOutgoingLinkedEntriesProvider(item.id))
            .any(
              (entry) =>
                  _isListed(entry, hideTaskEntries: hideTaskEntries) &&
                  _passesFilters(entry, activeKinds, showFlaggedOnly),
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showActivityFilters)
          LinkedEntriesActivityFilterBar(entryId: item.id),
        if (filteredToNothing) _FilteredEmpty(entryId: item.id),
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

/// Whether the pill set and the flagged-only toggle let [entry] show.
bool _passesFilters(
  JournalEntity entry,
  Set<LinkedEntryActivityFilter> activeKinds,
  bool showFlaggedOnly,
) {
  final kind = LinkedEntryActivityFilter.fromEntity(entry);
  if (kind != null && !activeKinds.contains(kind)) return false;
  return !showFlaggedOnly || entry.meta.isFlagged;
}

/// Whether [entry] is one the list draws at all, filters aside — the rule
/// [EntryDetailsWidget] applies to a linked row.
bool _isListed(JournalEntity entry, {required bool hideTaskEntries}) {
  if (entry.meta.deletedAt != null) return false;
  if (entry is AiResponseEntry) {
    return entry.data.type == AiResponseType.promptGeneration;
  }
  return !(hideTaskEntries && (entry is Task || entry is PullRequestEntry));
}

/// What the list shows when its filters hide every entry: that nothing
/// matches, and the way back.
class _FilteredEmpty extends ConsumerWidget {
  const _FilteredEmpty({required this.entryId});

  final String entryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step3,
        vertical: tokens.spacing.step4,
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: tokens.spacing.step3,
        children: [
          Text(
            context.messages.logbookNoMatchesTitle,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          DesignSystemButton(
            label: context.messages.projectsClearFilters,
            variant: DesignSystemButtonVariant.tertiary,
            size: DesignSystemButtonSize.dense,
            onPressed: () => ref
              ..invalidate(
                linkedEntriesActivityFilterControllerProvider(entryId),
              )
              ..invalidate(showFlaggedOnlyControllerProvider(entryId)),
          ),
        ],
      ),
    );
  }
}

/// Wraps [EntryDetailsWidget] so the activity-filter pill set and the
/// flagged-only toggle can hide entries without forcing the parent to
/// pre-resolve every linked entity.
class _FilteredEntryDetails extends ConsumerWidget {
  const _FilteredEntryDetails({
    required this.itemId,
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
  final bool hideTaskEntries;
  final bool isHighlighted;
  final bool isActiveTimer;
  final JournalEntity? linkedFrom;
  final EntryLink? link;
  final Set<LinkedEntryActivityFilter> activeKinds;
  final bool showFlaggedOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(entryControllerProvider(itemId)).value?.entry;
    if (entry != null && !_passesFilters(entry, activeKinds, showFlaggedOnly)) {
      return const SizedBox.shrink();
    }
    return EntryDetailsWidget(
      itemId: itemId,
      linkedFrom: linkedFrom,
      link: link,
      showAiEntry: false,
      hideTaskEntries: hideTaskEntries,
      isHighlighted: isHighlighted,
      isActiveTimer: isActiveTimer,
    );
  }
}
