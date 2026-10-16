import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_floating_action_button.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_icon_action.dart';
import 'package:lotti/features/design_system/components/empty_states/design_system_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/desktop_detail_empty_state.dart';
import 'package:lotti/features/design_system/components/navigation/resizable_divider.dart';
import 'package:lotti/features/design_system/state/pane_width_controller.dart';
import 'package:lotti/features/design_system/theme/breakpoints.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/design_system/theme/typography_helpers.dart';
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
import 'package:lotti/features/relationships/ui/widgets/post_interaction_prompt.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_chat_sheet.dart';
import 'package:lotti/features/relationships/ui/widgets/relationship_form_modal.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/providers/service_providers.dart';
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

    final navService = ref.read(navServiceProvider);
    return ColoredBox(
      color: tokens.colors.background.level01,
      child: ListenableBuilder(
        listenable: navService.desktopSelectedRelationshipId,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final selectedId = navService.desktopSelectedRelationshipId.value;
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

/// The desktop detail pane: the person's page, or one of their check-ins.
///
/// The person's agent conversation never takes a column here: it opens in the
/// shared side sheet over the page (see [showRelationshipChatSheet]). A
/// `/people/<id>/chat` address — a deep link, a restored route — still lands
/// in it: the pane hands the address back to the person and opens the sheet,
/// so the URL never claims a chat the screen is not showing.
class _PersonDetailPane extends StatefulWidget {
  const _PersonDetailPane({required this.relationshipId});

  final String relationshipId;

  @override
  State<_PersonDetailPane> createState() => _PersonDetailPaneState();
}

class _PersonDetailPaneState extends State<_PersonDetailPane> {
  final NavService _navService = getIt<NavService>();

  @override
  void initState() {
    super.initState();
    _navService.desktopRelationshipChatOpen.addListener(_onChatAddress);
    // An address that already asks for the chat when the pane appears.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChatAddress());
  }

  @override
  void dispose() {
    _navService.desktopRelationshipChatOpen.removeListener(_onChatAddress);
    super.dispose();
  }

  void _onChatAddress() {
    if (!mounted || !_navService.desktopRelationshipChatOpen.value) return;
    final relationshipId = widget.relationshipId;
    beamToNamed('/people/$relationshipId');
    showRelationshipChatSheet(context, relationshipId: relationshipId);
  }

  @override
  Widget build(BuildContext context) {
    final relationshipId = widget.relationshipId;
    return ValueListenableBuilder<String?>(
      valueListenable: _navService.desktopRelationshipCheckInId,
      builder: (context, checkInId, _) => checkInId != null
          ? Scaffold(
              key: ValueKey('people-check-in-$checkInId'),
              body: CheckInDetailView(
                relationshipId: relationshipId,
                checkInId: checkInId,
                onBack: () => beamToNamed('/people/$relationshipId'),
              ),
            )
          : RelationshipDetailsPage(
              key: ValueKey(relationshipId),
              relationshipId: relationshipId,
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
                onPressed: () => unawaited(createPersonAndOpen(context)),
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
                [] => const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyState(),
                ),
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
class _PeopleList extends ConsumerWidget {
  const _PeopleList({
    required this.items,
    required this.selectedRelationshipId,
  });

  final List<RelationshipListItem> items;
  final String? selectedRelationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.designTokens;
    final sections = peopleListSections(items);
    final children = <Widget>[
      PeopleSummaryCard(
        summary: peopleSummaryOf(items),
        onOpenNextDue: (id) => beamToNamed('/people/$id'),
      ),
      for (final section in sections) ...[
        Padding(
          // No horizontal inset of its own: the band heading hangs on the
          // page's content rail with the title above it, and the row's
          // internal step4 is the row card's inset, not a second gutter.
          // The break *above* a band has to beat the gaps inside it, or
          // three bands read as one list with captions in it.
          padding: EdgeInsets.fromLTRB(
            0,
            tokens.spacing.sectionGap,
            0,
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
            // Straight to speaking a check-in, without opening the page.
            onLongPress: () => openCheckInForPerson(
              context: context,
              ref: ref,
              relationshipId: item.relationship.id,
              startSpeaking: true,
            ),
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
      // The organising label of the list must not share a tier with the
      // row metadata it organises: `calmEyebrowStyle` is the design
      // system's structural voice for exactly this.
      style: calmEyebrowStyle(tokens),
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
            style: calmPageTitleStyle(tokens),
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
            // The design system's icon action: a full-size touch target
            // and a spoken label around the glyph, which a bare padded
            // InkWell gave neither of.
            DesignSystemIconAction(
              icon: LottiIcons.contactImport,
              tooltip: messages.relationshipImportAction,
              onPressed: () => _openContactImport(context),
            ),
        ],
      ),
    );
  }
}

/// Opens contact import above the shell, so the tab's own navigator — and
/// the bottom navigation with it — is not what the import page sits on.
void _openContactImport(BuildContext context) {
  bottomNavSafeNavigatorOf(context).push(
    MaterialPageRoute<int>(builder: (_) => const ContactImportPage()),
  );
}

/// The empty list's message, in the design system's one empty-state
/// grammar — the same glyph and ramp the desktop idle pane next to it uses,
/// so the two ways of showing nothing stop being two different designs.
///
/// It carries no add button of its own: adding a person is the page's
/// bottom action, which is already on screen. What it does carry is the one
/// sentence that says what the tab is for — a first-time reader otherwise
/// meets a title and nothing else — and, where the device has an address
/// book, the import door in words: in the header it is a glyph whose only
/// name is a tooltip, which a phone never shows. It fills the sliver's
/// remaining extent so the message sits in the space it has rather than
/// clinging to the top of a screen of void.
class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = context.messages;
    return DesignSystemEmptyState(
      icon: LottiIcons.people,
      title: messages.relationshipsEmptyState,
      hint: messages.relationshipsEmptyHint,
      action: ref.read(contactsServiceProvider).isSupported
          ? DesignSystemButton(
              key: const ValueKey('people-empty-import'),
              label: messages.relationshipImportAction,
              variant: DesignSystemButtonVariant.secondary,
              leadingIcon: LottiIcons.contactImport,
              onPressed: () => _openContactImport(context),
            )
          : null,
    );
  }
}

/// Opens the add-person sheet and lands on the person it created.
///
/// Creating a person used to drop the user back on the list to find the row
/// they had just made — the task list has always opened the new task instead
/// (`_defaultCreateTaskPressed`), and a person is no different: the page they
/// arrive on is where the check-in they came to log is logged.
///
/// A dismissed sheet resolves to null and goes nowhere.
Future<void> createPersonAndOpen(BuildContext context) async {
  final created = await showRelationshipCreateModal(context: context);
  if (created == null) return;
  beamToNamed('/people/${created.id}');
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
      onPressed: () => unawaited(createPersonAndOpen(context)),
    );
