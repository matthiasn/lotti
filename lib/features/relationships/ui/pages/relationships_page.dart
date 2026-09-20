import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
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
import 'package:lotti/features/relationships/ui/widgets/check_in_detail_view.dart';
import 'package:lotti/features/relationships/ui/widgets/people_list_row.dart';
import 'package:lotti/features/relationships/ui/widgets/people_summary_card.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_pane.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/services/nav_service.dart';
import 'package:lotti/widgets/nav_bar/bottom_nav_safe_navigator.dart';
import 'package:lotti/widgets/nav_bar/design_system_bottom_navigation_bar.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_launcher.dart';
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

    final navService = getIt<NavService>();
    return ColoredBox(
      color: tokens.colors.background.level01,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          navService.desktopSelectedRelationshipId,
          navService.desktopRelationshipChatOpen,
        ]),
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final selectedId = navService.desktopSelectedRelationshipId.value;
            final canHideListPane = selectedId != null;
            // The chat docks beside the person page, which needs room of its
            // own: while the chat is open and the list would squeeze the page
            // below a pane's width, the list steps aside for now — the
            // stored preference is untouched, and the page's own control
            // brings the list back.
            final makeRoomForChat =
                navService.desktopRelationshipChatOpen.value &&
                constraints.maxWidth - listPaneWidth <
                    chatSidebarMinDetailWidth;
            final listPaneVisible =
                (!paneWidths.listPaneCollapsed && !makeRoomForChat) ||
                !canHideListPane;
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
                  ? _PersonDetailPane(relationshipId: selectedId)
                  : DesktopDetailEmptyState(
                      message: context.messages.relationshipsSelectPersonHint,
                      icon: LottiIcons.people,
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// The narrowest detail pane that holds the person page and the chat
/// sidebar side by side: the sidebar's width, and at least as much again
/// for the page.
const double chatSidebarMinDetailWidth = 2 * defaultListPaneWidth;

/// The desktop detail pane: the person's page — with their chat as a
/// sidebar beside it while it is open — or one of their check-ins.
///
/// The chat sits beside the page rather than replacing it (design panel
/// 2026-09-19): what the agent is asked about stays in view. The pane
/// follows `NavService.desktopRelationshipChatOpen`, which the location
/// writes from the URL's `/chat` segment, keeping the address bar and the
/// pane in step; the page keeps its key, so opening and closing the chat
/// never rebuilds it.
class _PersonDetailPane extends StatelessWidget {
  const _PersonDetailPane({required this.relationshipId});

  final String relationshipId;

  @override
  Widget build(BuildContext context) {
    final navService = getIt<NavService>();
    return ValueListenableBuilder<String?>(
      valueListenable: navService.desktopRelationshipCheckInId,
      builder: (context, checkInId, _) => checkInId != null
          ? Scaffold(
              key: ValueKey('people-check-in-$checkInId'),
              body: CheckInDetailView(
                relationshipId: relationshipId,
                checkInId: checkInId,
                onBack: () => beamToNamed('/people/$relationshipId'),
              ),
            )
          : _personOrChat(navService),
    );
  }

  Widget _personOrChat(NavService navService) {
    return ValueListenableBuilder<bool>(
      valueListenable: navService.desktopRelationshipChatOpen,
      builder: (context, chatOpen, _) => LayoutBuilder(
        builder: (context, constraints) {
          final page = RelationshipDetailsPage(
            key: ValueKey(relationshipId),
            relationshipId: relationshipId,
          );
          // The chat docks beside the page only while the page keeps at
          // least a list pane's width of its own; a narrower pane — a
          // window near the desktop breakpoint, the sidebar expanded —
          // gives the chat the whole pane instead of squeezing both.
          if (chatOpen && constraints.maxWidth < chatSidebarMinDetailWidth) {
            return Scaffold(
              key: ValueKey('people-chat-$relationshipId'),
              body: RelationshipChatPane(
                relationshipId: relationshipId,
                onBack: () => beamToNamed('/people/$relationshipId'),
                showInternalsAction: true,
              ),
            );
          }
          // The page sits in the same Row whether or not the chat is
          // docked, so opening and closing it never remounts the page.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: page),
              if (chatOpen) ...[
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: context.designTokens.colors.decorative.level01,
                ),
                // As wide as the list pane on the other side of the page. The
                // sidebar is raw content, unlike the person page, which
                // brings its own Scaffold — and the composer's field needs a
                // Material ancestor.
                SizedBox(
                  key: ValueKey('people-chat-sidebar-$relationshipId'),
                  width: defaultListPaneWidth,
                  child: Scaffold(
                    body: RelationshipChatPane(
                      relationshipId: relationshipId,
                      onClose: () => beamToNamed('/people/$relationshipId'),
                      showInternalsAction: true,
                    ),
                  ),
                ),
              ],
            ],
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
    // The mobile navigation launcher docks this page's create action on its
    // own row (see [peopleTabDockAction]); floating a second copy above it
    // would put two create affordances in the same corner.
    final launcherOwnsCreateAction = mobileNavigationLauncherOwnsPageActions(
      context,
    );
    return Scaffold(
      floatingActionButton: !launcherOwnsCreateAction
          ? DesignSystemBottomNavigationFabPadding(
              child: DesignSystemFloatingActionButton(
                key: const ValueKey('people-add-person-fab'),
                semanticLabel: context.messages.relationshipCreateTitle,
                // Worded like the task list's: the app adds entries, tasks,
                // habits and people from the same glyph in the same corner.
                label: context.messages.relationshipCreateTitle,
                onPressed: () => showRelationshipCreateModal(context: context),
              ),
            )
          : null,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _PeopleHeader(itemCount: items?.length)),
            SliverPadding(
              // The last row must clear the overlaid bottom navigation and,
              // where one floats, the add button's own footprint (step12).
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step3,
                tokens.spacing.step5,
                tokens.spacing.step5 +
                    DesignSystemBottomNavigationBar.occupiedHeight(context) +
                    (launcherOwnsCreateAction ? 0 : tokens.spacing.step12),
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

/// The left-aligned `People` title with a count caption and the
/// import-from-contacts door, which exists only where there is an address
/// book (ADR 0041 §2).
///
/// Adding a person is not up here: like adding a task, it is the page's
/// bottom action — the floating button on desktop, the launcher's docked
/// chip on phones.
class _PeopleHeader extends ConsumerWidget {
  const _PeopleHeader({required this.itemCount});

  final int? itemCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final messages = context.messages;

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
          if (ref.read(contactsServiceProvider).isSupported)
            _IconButton(
              icon: LottiIcons.contactImport,
              tooltip: messages.relationshipImportAction,
              onTap: () => bottomNavSafeNavigatorOf(context).push(
                MaterialPageRoute<int>(
                  builder: (_) => const ContactImportPage(),
                ),
              ),
            ),
        ],
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
            size: IconSizes.m,
            color: tokens.colors.text.mediumEmphasis,
          ),
        ),
      ),
    );
  }
}

/// The empty list's message. It carries no add button of its own: adding a
/// person is the page's bottom action, which is already on screen.
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return Padding(
      padding: EdgeInsets.only(top: tokens.spacing.sectionGap),
      child: Text(
        context.messages.relationshipsEmptyState,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodyMedium.copyWith(
          color: tokens.colors.text.mediumEmphasis,
        ),
      ),
    );
  }
}

/// The People list's create action as the mobile navigation launcher shows
/// it.
///
/// The launcher docks it beside Navigate while the People tab is on screen,
/// which is why the list floats no button of its own there. Worded, like the
/// task list's: the plus alone would not say that this one adds a person.
MobileNavDockAction peopleTabDockAction(BuildContext context) =>
    MobileNavDockAction.worded(
      label: context.messages.relationshipCreateTitle,
      icon: LottiIcons.add,
      onPressed: () => showRelationshipCreateModal(context: context),
    );
