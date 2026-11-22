import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/dividers/design_system_divider.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/search/design_system_search.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/features/relationships/ui/widgets/people_summary_card.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:material_ui/material_ui.dart';

/// The People list's header: the `People · 5` title row with the
/// import-from-contacts door, and, once there is someone to find, a search
/// field the full width of the pane.
///
/// The title row and the search row are the two rows every other tab's
/// header has (`TabSectionHeader`); that header is not used here because it
/// sets a filter button beside its field, and nothing narrows a search
/// field. People has no filters to put there.
///
/// Adding a person is not up here: like adding a task, it is the page's
/// bottom action — the floating button on desktop, the launcher's docked
/// chip on phones.
class PeopleListHeader extends StatelessWidget {
  const PeopleListHeader({
    required this.itemCount,
    required this.searchController,
    required this.onQueryChanged,
    required this.onImport,
    super.key,
  });

  /// How many people there are; null until the first load lands, and the
  /// search row waits for at least one.
  final int? itemCount;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;

  /// Opens contact import; null where the device has no address book
  /// (ADR 0041 §2).
  final VoidCallback? onImport;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final count = itemCount;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                messages.relationshipsPageTitle,
                style: calmPageTitleStyle(tokens),
              ),
              if (count != null) ...[
                SizedBox(width: tokens.spacing.step2),
                Text(
                  '· $count',
                  style: tokens.typography.styles.others.caption.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ],
              const Spacer(),
              if (onImport != null)
                // A full-size touch target and a spoken label around the
                // glyph.
                DesignSystemIconAction(
                  icon: LottiIcons.contactImport,
                  tooltip: messages.relationshipImportAction,
                  onPressed: onImport,
                ),
            ],
          ),
          if (count != null && count > 0) ...[
            SizedBox(height: tokens.spacing.step4),
            DesignSystemSearch(
              key: const ValueKey('people-search'),
              controller: searchController,
              hintText: messages.relationshipPickerSearchHint,
              size: DesignSystemSearchSize.small,
              onChanged: onQueryChanged,
              onClear: () => onQueryChanged(''),
            ),
          ],
        ],
      ),
    );
  }
}

/// The list below the header, as one lazily built sliver: the summary card,
/// then each band's heading over its rows card.
///
/// Each row draws its own part of the band's card ([PeopleRowsCardSegment]),
/// so the card reads as one surface while only the rows on screen are
/// built — an imported address book can put hundreds of people in one
/// band. Every slot carries a key and the list looks keys up
/// (`findChildIndexCallback`), so a person who moves band, or arrives at the
/// top, keeps their row's element instead of every row below being rebuilt.
///
/// With a [query] the bands hold only the people it matches and the summary
/// card steps aside, since its counts describe everyone; a query that
/// matches nobody shows [PeopleSearchMiss] in place of the bands.
class PeopleListSliver extends StatelessWidget {
  const PeopleListSliver({
    required this.items,
    required this.query,
    required this.selectedRelationshipId,
    required this.onOpen,
    required this.onSpeak,
    required this.onClearSearch,
    super.key,
  });

  /// Everyone, unfiltered.
  final List<RelationshipListItem> items;
  final String query;
  final String? selectedRelationshipId;
  final ValueChanged<String> onOpen;
  final ValueChanged<RelationshipListItem> onSpeak;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final searching = query.trim().isNotEmpty;
    final shown = searching
        ? [
            for (final item in items)
              if (personMatchesQuery(item.relationship, query)) item,
          ]
        : items;
    if (shown.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(top: tokens.spacing.step9),
          child: PeopleSearchMiss(query: query.trim(), onClear: onClearSearch),
        ),
      );
    }

    final slots = <_Slot>[
      if (!searching)
        _Slot(
          const ValueKey('people-summary'),
          (key) => PeopleSummaryCard(
            key: key,
            summary: peopleSummaryOf(items),
            onOpenNextDue: onOpen,
          ),
        ),
      for (final section in peopleListSections(shown)) ...[
        _Slot(
          ValueKey('people-group-${section.group.name}'),
          (key) => Padding(
            key: key,
            // The break above a band beats the one under its heading, or
            // three bands read as one list with captions in it.
            padding: EdgeInsets.only(
              top: tokens.spacing.sectionGap,
              bottom: tokens.spacing.step3,
            ),
            child: _GroupHeading(
              group: section.group,
              count: section.items.length,
            ),
          ),
        ),
        for (final (index, item) in section.items.indexed)
          _Slot(
            ValueKey('people-row-${item.relationship.id}'),
            (key) => PeopleRowsCardSegment(
              key: key,
              first: index == 0,
              last: index == section.items.length - 1,
              child: PeopleListRow(
                item: item,
                selected: item.relationship.id == selectedRelationshipId,
                onTap: () => onOpen(item.relationship.id),
                // Straight to speaking about them, without opening the page.
                onLongPress: () => onSpeak(item),
              ),
            ),
          ),
      ],
    ];
    final indexOfKey = {
      for (final (index, slot) in slots.indexed) slot.key: index,
    };
    return SliverList.builder(
      itemCount: slots.length,
      itemBuilder: (context, index) => slots[index].build(slots[index].key),
      findChildIndexCallback: (key) => indexOfKey[key],
    );
  }
}

/// One child of [PeopleListSliver], built lazily under its [key].
class _Slot {
  const _Slot(this.key, this.build);

  final Key key;
  final Widget Function(Key key) build;
}

/// A row's share of its band's rows card — `DsRowsCard`'s surface
/// (`background.level02`, `radii.l`, no border, a [DesignSystemDivider]
/// between rows) drawn one row at a time, so the list can stay lazy.
///
/// The [first] row takes the card's top corners and the [last] its bottom
/// ones; every row but the first carries the divider above it. The segment
/// clips, so a selected or hovered row's fill stops at the card's corners.
class PeopleRowsCardSegment extends StatelessWidget {
  const PeopleRowsCardSegment({
    required this.first,
    required this.last,
    required this.child,
    super.key,
  });

  final bool first;
  final bool last;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final corner = Radius.circular(tokens.radii.l);
    return Material(
      color: tokens.colors.background.level02,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: first ? corner : Radius.zero,
          bottom: last ? corner : Radius.zero,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [if (!first) const DesignSystemDivider(), child],
      ),
    );
  }
}

/// A band's caption: `Due · 1`, `On track · 3`, `No reminders · 1`.
class _GroupHeading extends StatelessWidget {
  const _GroupHeading({required this.group, required this.count});

  final PeopleListGroup group;
  final int count;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final label = switch (group) {
      PeopleListGroup.due => messages.relationshipsGroupDue,
      PeopleListGroup.onTrack => messages.relationshipCadenceOnTrack,
      PeopleListGroup.notEnrolled => messages.relationshipNotEnrolled,
    };
    return Text(
      '$label · $count',
      // The organising label of the list must not share a tier with the
      // row metadata it organises: `calmEyebrowStyle` is the design
      // system's structural voice for exactly this.
      style: calmEyebrowStyle(tokens),
    );
  }
}

/// A search that matches nobody: it says so with the words typed, and
/// offers the way back to everyone.
class PeopleSearchMiss extends StatelessWidget {
  const PeopleSearchMiss({
    required this.query,
    required this.onClear,
    super.key,
  });

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final messages = context.messages;
    return DesignSystemEmptyState(
      key: const ValueKey('people-search-miss'),
      icon: LottiIcons.search,
      title: messages.relationshipsSearchNoMatch(query),
      action: DesignSystemButton(
        key: const ValueKey('people-search-clear'),
        label: messages.designSystemSearchClearLabel,
        variant: DesignSystemButtonVariant.secondary,
        onPressed: onClear,
      ),
    );
  }
}
