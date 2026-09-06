import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/keyboard/ui/list_detail_focus_traversal.dart';
import 'package:lotti/features/relationships/repository/relationship_repository.dart';
import 'package:lotti/features/relationships/service/contacts_service.dart';
import 'package:lotti/features/relationships/state/relationships_providers.dart';
import 'package:lotti/features/relationships/ui/model/people_list_model.dart';
import 'package:lotti/features/relationships/ui/pages/contact_import_page.dart';
import 'package:lotti/features/relationships/ui/pages/relationship_details_page.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/features/relationships/ui/widgets/people_summary_card.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:material_ui/material_ui.dart';

/// The People tab (design 2026-09-06 §2–3).
///
/// Phones show the list scaffold alone; tapping a row beams to
/// `/people/<id>`. Desktop renders the Tasks/Projects list-detail split: the
/// list scaffold in a resizable left pane (width from
/// [paneWidthControllerProvider] via a [ResizableDivider]) and, on the right,
/// the page of the person selected in
/// `NavService.desktopSelectedRelationshipId` — written by the location from
/// the URL, so the route stays the single source of truth — or the empty
/// state. With a selection the list can move offstage into focus mode while
/// keeping its state.
class RelationshipsPage extends ConsumerWidget {
  const RelationshipsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isDesktopLayout(context)) {
      return const _PeopleListScaffold(selectedRelationshipId: null);
    }
    final tokens = context.designTokens;
    final paneWidths = ref.watch(paneWidthControllerProvider);
    // Scales the flat default proportionally on large windows — see
    // scaledPaneWidth's doc comment. A no-op once the user has dragged the
    // list pane to any other width.
    final resolvedListPane = resolvedPaneWidth(
      storedWidth: paneWidths.listPaneWidth,
      flatDefault: defaultListPaneWidth,
      minValue: minListPaneWidth,
      maxValue: maxListPaneWidth,
      screenWidth: MediaQuery.sizeOf(context).width,
      onDelta: (delta) => ref
          .read(paneWidthControllerProvider.notifier)
          .updateListPaneWidth(delta, allowWhileCollapsed: true),
    );
    final listPaneWidth = resolvedListPane.width;
    final paneController = ref.read(paneWidthControllerProvider.notifier);

    return ColoredBox(
      color: tokens.colors.background.level01,
      child: ValueListenableBuilder<String?>(
        valueListenable: getIt<NavService>().desktopSelectedRelationshipId,
        builder: (context, selectedId, _) {
          final canHideListPane = selectedId != null;
          final listPaneVisible =
              !paneWidths.listPaneCollapsed || !canHideListPane;
          return ListDetailFocusTraversal(
            debugLabel: 'people-split',
            listPaneVisible: listPaneVisible,
            canHideListPane: canHideListPane,
            onListPaneVisibilityChanged: (visible) {
              if (visible) {
                paneController.expandListPane();
              } else {
                paneController.collapseListPane();
              }
            },
            listPane: SizedBox(
              width: listPaneWidth,
              child: _PeopleListScaffold(selectedRelationshipId: selectedId),
            ),
            divider: ResizableDivider(
              currentValue: listPaneWidth,
              minValue: minListPaneWidth,
              maxValue: maxListPaneWidth,
              onDrag: resolvedListPane.onDrag,
            ),
            // The page carries its own show-list-pane control in the hero
            // while the list is folded away, so nothing is overlaid here.
            detailPane: selectedId != null
                ? RelationshipDetailsPage(
                    key: ValueKey(selectedId),
                    relationshipId: selectedId,
                  )
                : DesktopDetailEmptyState(
                    message: context.messages.relationshipsSelectPersonHint,
                    icon: LottiIcons.people,
                  ),
          );
        },
      ),
    );
  }
}

/// The list itself: header, summary card, then the rows in their bands.
class _PeopleListScaffold extends ConsumerWidget {
  const _PeopleListScaffold({required this.selectedRelationshipId});

  /// The person whose page fills the desktop detail pane; null on phones.
  final String? selectedRelationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final itemsAsync = ref.watch(relationshipsListControllerProvider);
    // Never flash the established list during a background reload — keep the
    // previous value while the refetch runs.
    final items = itemsAsync.value;
    final failedFirstLoad = items == null && itemsAsync.hasError;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _PeopleHeader(itemCount: items?.length)),
            SliverPadding(
              // The last row must clear the overlaid bottom navigation.
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step3,
                tokens.spacing.step5,
                tokens.spacing.step5 +
                    DesignSystemBottomNavigationBar.occupiedHeight(context) +
                    tokens.spacing.step12,
              ),
              sliver: switch (items) {
                null when failedFirstLoad => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
                    child: Text(
                      context.messages.commonError,
                      textAlign: TextAlign.center,
                      style: tokens.typography.styles.body.bodyMedium.copyWith(
                        color: tokens.colors.text.mediumEmphasis,
                      ),
                    ),
                  ),
                ),
                // First load only — a background reload never reaches this
                // arm because the previous value is retained above.
                null => SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
                    child: const Center(
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                ),
                [] => SliverToBoxAdapter(child: _EmptyState()),
                final list => _PeopleList(
                  items: list,
                  selectedRelationshipId: selectedRelationshipId,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The summary card and the banded rows, as one sliver list.
class _PeopleList extends StatelessWidget {
  const _PeopleList({
    required this.items,
    required this.selectedRelationshipId,
  });

  final List<RelationshipListItem> items;
  final String? selectedRelationshipId;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final sections = peopleListSections(items);
    final children = <Widget>[
      PeopleSummaryCard(summary: peopleSummaryOf(items)),
      for (final section in sections) ...[
        Padding(
          padding: EdgeInsets.fromLTRB(
            tokens.spacing.step4,
            tokens.spacing.step5,
            tokens.spacing.step4,
            tokens.spacing.step2,
          ),
          child: _GroupHeading(
            group: section.group,
            count: section.items.length,
          ),
        ),
        for (final item in section.items)
          PeopleListRow(
            key: ValueKey('people-row-${item.relationship.id}'),
            item: item,
            selected: item.relationship.id == selectedRelationshipId,
            onTap: () => beamToNamed('/people/${item.relationship.id}'),
          ),
      ],
    ];
    return SliverList(delegate: SliverChildListDelegate(children));
  }
}

/// A band's caption: `Due · 1`, `On track · 3`, `Not enrolled · 1`.
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
      key: ValueKey('people-group-${group.name}'),
      style: tokens.typography.styles.others.caption.copyWith(
        color: tokens.colors.text.mediumEmphasis,
        fontWeight: tokens.typography.weight.semiBold,
      ),
    );
  }
}

/// The left-aligned `People` title with a count caption and the add
/// affordance: a labelled button on desktop, the teal circle on phones —
/// beside the import-from-contacts door, which exists only where there is
/// an address book (ADR 0041 §2).
class _PeopleHeader extends ConsumerWidget {
  const _PeopleHeader({required this.itemCount});

  final int? itemCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;
    final isDesktop = isDesktopLayout(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step5,
        tokens.spacing.step3,
      ),
      child: Row(
        children: [
          Text(
            messages.relationshipsPageTitle,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          if (itemCount != null) ...[
            SizedBox(width: tokens.spacing.step2),
            Text(
              '· $itemCount',
              style: tokens.typography.styles.others.caption.copyWith(
                color: tokens.colors.text.lowEmphasis,
              ),
            ),
          ],
          const Spacer(),
          if (ref.read(contactsServiceProvider).isSupported) ...[
            _IconButton(
              icon: LottiIcons.contactImport,
              tooltip: messages.relationshipImportAction,
              onTap: () => bottomNavSafeNavigatorOf(context).push(
                MaterialPageRoute<int>(
                  builder: (_) => const ContactImportPage(),
                ),
              ),
            ),
            SizedBox(width: tokens.spacing.step2),
          ],
          if (isDesktop)
            DesignSystemButton(
              key: const ValueKey('people-add-person-button'),
              label: messages.relationshipCreateTitle,
              leadingIcon: LottiIcons.add,
              onPressed: () => showRelationshipCreateModal(context: context),
            )
          else
            _AddPersonButton(
              onTap: () => showRelationshipCreateModal(context: context),
            ),
        ],
      ),
    );
  }
}

class _AddPersonButton extends StatelessWidget {
  const _AddPersonButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The control is a bare glyph, so the name has to come from somewhere:
    // `Semantics` states it for a screen reader, the tooltip shows the same
    // words to a pointer, and `excludeFromSemantics` keeps the tooltip from
    // announcing it a second time.
    final label = context.messages.relationshipCreateTitle;
    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        excludeFromSemantics: true,
        child: Material(
          color: tokens.colors.interactive.enabled,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 34,
              height: 34,
              child: Icon(
                LottiIcons.add,
                size: 20,
                color: tokens.colors.background.level01,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: EdgeInsets.all(tokens.spacing.step2),
          child: Icon(
            icon,
            size: 22,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final messages = context.messages;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            messages.relationshipsEmptyState,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyMedium.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          _AddPersonButton(
            onTap: () => showRelationshipCreateModal(context: context),
          ),
        ],
      ),
    );
  }
}
