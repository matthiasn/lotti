part of 'beamer_app.dart';

/// True when the tasks tab is active and the tasks beamer location points
/// at a `/tasks/<uuid>` task detail. Used by both shells: the mobile shell
/// hides the bottom nav pill so the page-owned `TaskActionBar` can dock
/// flush against the home indicator. Pure function of router state, no
/// widget-lifecycle race.
bool isTaskDetailRoute(BeamLocation<dynamic>? location, int activeTabIndex) {
  // Tasks is always the first destination; if any other tab is active
  // the tasks delegate's current path is irrelevant.
  if (activeTabIndex != 0) return false;
  if (location is! TasksLocation) return false;
  return isUuid(location.state.pathParameters['taskId']);
}

/// Whether the journal tab is showing one entry's detail page rather than
/// the logbook feed.
///
/// Like a task's page, an entry's page docks its own sticky action bar
/// (`EntryActionBar`: add a linked task, record, and the Add sheet) at the
/// bottom edge, so the mobile shell unmounts the launcher there — menu
/// button, docked create action and activity island alike — exactly as it
/// does for [isTaskDetailRoute].
bool isLogbookEntryDetailRoute(BeamLocation<dynamic>? location) {
  if (location is! JournalLocation) return false;
  return isUuid(location.state.pathParameters['entryId']);
}

/// Whether the events tab is showing one event's page rather than the
/// overview.
///
/// The overview's "new event" action docks on the mobile navigation
/// launcher, which stays up on an event's page — where a plus would read as
/// adding to *that* event, so the overview's action must leave the rail.
bool isEventDetailRoute(BeamLocation<dynamic>? location) {
  if (location is! EventsLocation) return false;
  return location.state.pathParameters['eventId'] != null;
}

/// Layout allowance for the docked day-view column on the desktop shell:
/// whether it may show at all, and the widest it may be. Pure function of
/// geometry and route state so the policy is testable on its own.
///
/// Below [kDayViewPanelMinWindowWidth] the column — rail included — never
/// shows. Above it the column is always reachable: the rail is a fixed
/// [TapTargets.minimum]-wide strip that costs the content region nothing
/// worth protecting, and the expanded panel is opt-in, so the user's choice
/// to bring it up wins over the split heuristic below. While a task detail
/// is open ([taskDetailOpen]) the content region hosts the tasks list +
/// detail split, which prefers a desktop-wide region ([kDesktopBreakpoint])
/// of its own — the column is clamped narrower to protect that region, but
/// never below [minDayViewPanelWidth]: on a window where even the minimum
/// column eats into the split, the split gives way rather than the column
/// vanishing with its toggle. Without an open detail the split shows only
/// the browse list and its empty-state pane, which tolerate a narrower
/// region, so the window gate alone applies.
({bool show, double maxWidth}) dayViewColumnAllowance({
  required bool taskDetailOpen,
  required double windowWidth,
  required double sidebarWidth,
}) {
  if (windowWidth < kDayViewPanelMinWindowWidth) {
    return (show: false, maxWidth: 0);
  }
  var maxWidth = maxDayViewPanelWidth;
  if (taskDetailOpen) {
    maxWidth = math.max(
      minDayViewPanelWidth,
      math.min(maxWidth, windowWidth - sidebarWidth - kDesktopBreakpoint),
    );
  }
  return (show: true, maxWidth: maxWidth);
}

/// True when the settings beamer location points at a *detail* surface — a
/// terminal page you navigate to, rather than a menu you navigate from — so
/// the mobile shell slides the bottom nav out of the way and the page owns
/// the whole bottom edge. Pure function of router state.
///
/// Read from the settings route registry: the page on top of the URL's
/// mobile stack decides, through its `keepsBottomNav`. Menus (the root, the
/// branch hubs), the browse lists that drill into their own editors, and
/// Sections keep the bar; everything terminal — leaves, editors, the AI and
/// Agents sections — hides it. A URL no node claims shows the root, and
/// keeps it.
///
/// Editor surfaces that are *pushed* on top of another settings route rather
/// than being routes themselves (the AI provider connect form, the evolution
/// chat) keep the URL of the page they were pushed from, so they can't be
/// matched here — they escape the nav by pushing onto the root navigator via
/// `bottomNavSafeNavigatorOf` instead.
bool settingsRouteHidesBottomNav(BeamLocation<dynamic>? location) {
  if (location is! SettingsLocation) return false;
  final uri = location.state.uri;
  if (uri.pathSegments.firstOrNull != 'settings') return false;
  return !settingsRoutes.resolve(uri).keepsBottomNav;
}

/// True when the projects beamer location points at a project detail
/// (`/projects/<id>`) — a terminal page owning the whole bottom edge, so the
/// mobile shell slides the bottom nav out of the way exactly like the settings
/// detail surfaces in [settingsRouteHidesBottomNav]. Pure function of router
/// state.
///
/// The `/projects` list root keeps the bar, and so does the reserved
/// `/projects/create` slug: it is a stale deep link from the retired
/// full-screen create route that [ProjectsLocation] renders as the list.
bool projectsRouteHidesBottomNav(BeamLocation<dynamic>? location) {
  if (location is! ProjectsLocation) return false;
  final segments = location.state.uri.pathSegments;
  if (segments.length < 2 || segments.first != 'projects') return false;
  return segments[1] != 'create';
}

/// True when the GOALS beamer location points at a goal's own pages —
/// the detail page, its chat, its edit wizard (`/goals/details/{id}/...`)
/// or the create wizard (`/goals/create`).
///
/// Every one of them is a terminal page that owns its bottom edge: the detail
/// page's day-assessment sheet docks its `Record for <day>` CTA there, and
/// both wizards pin their Continue band there. With the bar in place the
/// blurred pill sits on top of that CTA. They slide the bar away for the same
/// reason as [projectsRouteHidesBottomNav]. Pure function of router state.
///
/// The `/goals` list root keeps the bar — it is a tab you navigate *from*.
///
/// The shapes are matched exactly, not by prefix: [GoalsLocation.buildPages]
/// renders the plain list for anything malformed (`/goals/details` with no
/// id, an unknown trailing segment), and that list must keep its tab bar.
bool goalsRouteHidesBottomNav(BeamLocation<dynamic>? location) {
  if (location is! GoalsLocation) return false;
  final segments = location.state.uri.pathSegments;
  if (segments.isEmpty || segments.first != 'goals') return false;
  return switch (segments.length) {
    2 => segments[1] == 'create',
    3 => segments[1] == 'details' && segments[2].isNotEmpty,
    4 =>
      segments[1] == 'details' &&
          segments[2].isNotEmpty &&
          (segments[3] == 'chat' || segments[3] == 'edit'),
    _ => false,
  };
}

/// True when the Habits beamer location points at the create or edit route.
///
/// The list root keeps the bar because it is the tab surface. The editor owns
/// the bottom edge with its pinned primary action, so the floating navigation
/// pill slides away instead of covering Save or Continue.
bool habitsRouteHidesBottomNav(BeamLocation<dynamic>? location) {
  if (location is! HabitsLocation) return false;
  final segments = location.state.uri.pathSegments;
  if (segments.isEmpty || segments.first != 'habits') return false;
  return switch (segments.length) {
    2 => segments[1] == 'create',
    3 => segments[1] == 'edit' && segments[2].isNotEmpty,
    _ => false,
  };
}

/// True when the PEOPLE beamer location points at one person's own pages —
/// their detail page (`/people/<id>`), their agent chat
/// (`/people/<id>/chat`) or one of their check-ins
/// (`/people/<id>/check-ins/<checkInId>`).
///
/// Both are terminal pages you navigate *to*, so they slide the bar away for
/// the same reason as [goalsRouteHidesBottomNav]. The chat is the pointed
/// case: `AgentChatView` docks its message composer on the bottom edge, and
/// the blurred nav pill would sit on top of the field the page exists for —
/// as it would on a check-in's add bar.
/// Pure function of router state.
///
/// The `/people` list root keeps the bar — it is a tab you navigate *from*,
/// and it is the only way back to the other tabs from here.
///
/// Shapes are matched exactly rather than by prefix, matching
/// [goalsRouteHidesBottomNav]: [RelationshipsLocation] renders the list for
/// anything malformed, and that list must keep its tab bar. An empty id is
/// malformed — `/people//chat` must not pass as a chat route, nor
/// `/people/<id>/check-ins/` as a check-in.
bool peopleRouteHidesBottomNav(BeamLocation<dynamic>? location) {
  if (location is! RelationshipsLocation) return false;
  final segments = location.state.uri.pathSegments;
  if (segments.isEmpty || segments.first != 'people') return false;
  return switch (segments.length) {
    2 => segments[1].isNotEmpty,
    3 => segments[1].isNotEmpty && segments[2] == 'chat',
    4 =>
      segments[1].isNotEmpty &&
          segments[2] == 'check-ins' &&
          segments[3].isNotEmpty,
    _ => false,
  };
}

/// Clamps a raw navigation index into `[0, itemCount - 1]` so a stale index
/// from the nav stream cannot go out of bounds when feature flags shrink the
/// destinations list.
int clampNavigationIndex({required int rawIndex, required int itemCount}) {
  if (rawIndex < 0) return 0;
  return rawIndex > itemCount - 1 ? itemCount - 1 : rawIndex;
}
