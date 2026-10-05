part of 'beamer_app.dart';

/// The desktop and mobile shells of [AppScreen]: the sidebar layout, the
/// mobile dock and drawer, and the per-destination dock actions.
extension _AppScreenLayout on _AppScreenState {
  bool _isTaskDetailRoute(int activeTabIndex) => isTaskDetailRoute(
    navService.tasksDelegate.currentBeamLocation,
    activeTabIndex,
  );

  /// Whether the active tab is the journal and it is showing an entry's page.
  /// Opening an entry moves only the journal delegate, not the tab index, so
  /// the journal location alone would also match while another tab is up.
  bool _isLogbookEntryDetailRoute(_AppNavigationDestinationKind activeKind) =>
      activeKind == _AppNavigationDestinationKind.journal &&
      isLogbookEntryDetailRoute(navService.journalDelegate.currentBeamLocation);

  /// Whether the active tab is Events and it is showing an event's page.
  /// Same shape as [_isLogbookEntryDetailRoute]: opening an event moves only
  /// the events delegate, so its location alone would also match while
  /// another tab is up.
  bool _isEventDetailRoute(_AppNavigationDestinationKind activeKind) =>
      activeKind == _AppNavigationDestinationKind.events &&
      isEventDetailRoute(navService.eventsDelegate.currentBeamLocation);

  Widget _buildDesktopLayout({
    required BuildContext context,
    required int index,
    required List<_AppNavigationDestination> destinations,
    required List<Widget> beamerChildren,
  }) {
    final sidebar = _SidebarDestinations(destinations, index);
    final mainDestinations = sidebar.main;
    final settingsDestination = sidebar.settings;
    final settingsIndex = sidebar.settingsIndex;
    final isSettingsActive = sidebar.isSettingsActive;
    final mainActiveIndex = sidebar.mainActiveIndex;

    final paneWidths = ref.watch(paneWidthControllerProvider);
    // Scales the flat default proportionally on large windows so the
    // sidebar doesn't stay pinned to a laptop-tuned width while the detail
    // pane grows unbounded — see scaledPaneWidth's doc comment. A no-op once
    // the user has dragged the sidebar to any other width.
    final resolvedSidebar = resolvedPaneWidth(
      storedWidth: paneWidths.sidebarWidth,
      flatDefault: defaultSidebarWidth,
      minValue: minSidebarWidth,
      maxValue: maxSidebarWidth,
      screenWidth: MediaQuery.sizeOf(context).width,
      onDelta: ref
          .read(paneWidthControllerProvider.notifier)
          .updateSidebarWidth,
    );
    final sidebarWidth = resolvedSidebar.width;
    final isCollapsed = paneWidths.sidebarCollapsed;
    // Lockdown: the rail keeps only the destinations whose content is
    // category-scoped by the journal page controller, and drops every slot
    // that could name something outside the locked category — saved filters,
    // the activity disclosure, Settings, the contact band.
    final lockdown = ref.watch(lockdownControllerProvider);
    final visibleMain = lockdown.isActive
        ? mainDestinations
              .where((dest) => _lockdownVisibleKinds.contains(dest.kind))
              .toList(growable: false)
        : mainDestinations;
    final visibleActiveIndex = isSettingsActive
        ? 0
        : math.max(0, visibleMain.indexOf(mainDestinations[mainActiveIndex]));
    final logoMenuItems = LockdownLogoMenu.items(
      context,
      ref,
      lockdown: lockdown,
      categories: ref.watch(lockdownCategoryOptionsProvider),
    );

    // The docked day-view column keeps the current day visible beside the
    // tasks list — the surface where time is planned and tracked — and only
    // there. It shares the Daily OS feature flag (no Daily OS, no day view)
    // and its geometry policy lives in [dayViewColumnAllowance]: a window
    // gate, plus a clamp (never a yield) that keeps an open task detail's
    // split as wide as the column's minimum allows.
    final windowWidth = MediaQuery.sizeOf(context).width;
    final dayViewAllowance = dayViewColumnAllowance(
      taskDetailOpen: _isTaskDetailRoute(index),
      windowWidth: windowWidth,
      sidebarWidth: isCollapsed ? kCollapsedSidebarWidth : sidebarWidth,
    );
    // The day view stays up under lockdown: the panel itself redacts blocks
    // outside the locked category (see `DayViewSidePanel`).
    final showDayViewColumn =
        destinations[index].kind == _AppNavigationDestinationKind.tasks &&
        navService.isDailyOsPageEnabled &&
        dayViewAllowance.show;
    final resolvedDayView = resolvedPaneWidth(
      storedWidth: paneWidths.dayViewPanelWidth,
      flatDefault: defaultDayViewPanelWidth,
      minValue: minDayViewPanelWidth,
      maxValue: maxDayViewPanelWidth,
      screenWidth: windowWidth,
      onDelta: ref
          .read(paneWidthControllerProvider.notifier)
          .updateDayViewPanelWidth,
    );
    // The displayed width honors the allowance clamp; drags are rebased
    // against it (same trick as resolvedPaneWidth's scaling) so the divider
    // never desyncs from the pointer while the stored width exceeds the
    // clamp.
    final dayViewWidth = math.min(
      resolvedDayView.width,
      dayViewAllowance.maxWidth,
    );
    void dayViewDrag(double delta) => ref
        .read(paneWidthControllerProvider.notifier)
        .updateDayViewPanelWidth(
          (dayViewWidth - delta) - paneWidths.dayViewPanelWidth,
        );
    final dayViewPanelHidden = paneWidths.dayViewPanelHidden;
    void toggleDayViewPanel() => ref
        .read(paneWidthControllerProvider.notifier)
        .toggleDayViewPanelHidden();
    return Scaffold(
      // Scaffold fills behind the outer ResizableDivider's 3 px reserved
      // SizedBox; without an explicit colour Flutter would paint the theme
      // default (canvas / near-black) there, which shows through as a darker
      // strip around the sidebar-↔-list divider. Using the list-pane token
      // (background.level01 = #181818) keeps the divider flanked by the
      // same surface on both visible edges, matching the right-side divider.
      backgroundColor: context.designTokens.colors.background.level01,
      body: Row(
        children: [
          KeyboardFocusRegion(
            debugLabel: 'app-navigation',
            child: DesktopNavigationSidebar(
              destinations: [
                for (final dest in visibleMain)
                  dest.toDesktopSidebarDestination(
                    includeExpandedChild: !lockdown.isActive,
                  ),
              ],
              activeIndex: visibleActiveIndex,
              // `destinations` (Settings included) is index-aligned with the
              // content stack, so a sidebar tap maps back through identity.
              onDestinationSelected: (visibleIdx) => navService.tapIndex(
                destinations.indexOf(visibleMain[visibleIdx]),
              ),
              settingsDestination: lockdown.isActive
                  ? null
                  : settingsDestination?.toDesktopSidebarDestination(),
              onSettingsSelected: settingsIndex >= 0 && !lockdown.isActive
                  ? () => navService.tapIndex(settingsIndex)
                  : null,
              isSettingsActive: isSettingsActive && !lockdown.isActive,
              width: sidebarWidth,
              collapsed: isCollapsed,
              onToggleCollapsed: () => ref
                  .read(paneWidthControllerProvider.notifier)
                  .toggleSidebarCollapsed(),
              aboveSettings: lockdown.isActive
                  ? null
                  : const _SidebarAboveSettings(),
              footerBand: lockdown.isActive ? null : const ContactSupportRow(),
              logoMenuItems: logoMenuItems,
              logoMenuHeader: LockdownLogoMenu.header(context, lockdown),
              logoMenuSemanticsLabel:
                  context.messages.lockdownMenuSemanticsLabel,
            ),
          ),
          ResizableDivider(
            enabled: !isCollapsed,
            currentValue: sidebarWidth,
            minValue: minSidebarWidth,
            maxValue: maxSidebarWidth,
            onDrag: resolvedSidebar.onDrag,
          ),
          Expanded(
            child: KeyboardFocusRegion(
              debugLabel: 'app-content',
              child: Stack(
                children: [
                  const IncomingVerificationWrapper(),
                  _buildContentStack(
                    index: index,
                    beamerChildren: beamerChildren,
                  ),
                ],
              ),
            ),
          ),
          if (showDayViewColumn)
            ValueListenableBuilder<List<String>>(
              valueListenable: navService.desktopTaskDetailStack,
              builder: (context, stack, child) => Consumer(
                builder: (context, ref, _) {
                  final queryOpen =
                      stack.isNotEmpty &&
                      ref.watch(
                        queryPaneOpenProvider(
                          QueryScope(kind: QueryScopeKind.task, id: stack.last),
                        ),
                      );
                  // Chat temporarily owns the companion space. Keep the day
                  // view mounted and its persisted visibility untouched.
                  return Offstage(
                    offstage: queryOpen,
                    child: TickerMode(
                      enabled: !queryOpen,
                      child: ExcludeFocus(excluding: queryOpen, child: child!),
                    ),
                  );
                },
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (dayViewPanelHidden)
                    DayViewSidePanelRail(onToggleHidden: toggleDayViewPanel)
                  else ...[
                    ResizableDivider(
                      currentValue: dayViewWidth,
                      minValue: minDayViewPanelWidth,
                      maxValue: dayViewAllowance.maxWidth,
                      // The divider sits on the panel's LEADING edge, so a
                      // rightward drag (positive delta) shrinks the panel —
                      // [dayViewDrag] inverts the delta before handing it to the
                      // width controller.
                      onDrag: dayViewDrag,
                    ),
                    SizedBox(
                      width: dayViewWidth,
                      child: DayViewSidePanel(
                        onToggleHidden: toggleDayViewPanel,
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout({
    required BuildContext context,
    required int index,
    required List<_AppNavigationDestination> destinations,
    required List<Widget> beamerChildren,
  }) {
    // Visibility is a pure function of the active beamer route. Routes
    // that take over the bottom edge with their own sticky surface
    // (`/tasks/<uuid>` with TaskActionBar, `/journal/<uuid>` and
    // `/events/<uuid>` with EntryActionBar) suppress the nav pill — including
    // the activity island that floats above it — so the page-owned bar can
    // dock flush against the home indicator. The enclosing ListenableBuilder
    // ensures we rebuild on every route change.
    final showBottomNav =
        !_isTaskDetailRoute(index) &&
        !_isLogbookEntryDetailRoute(destinations[index].kind) &&
        !_isEventDetailRoute(destinations[index].kind);

    // Settings *detail* routes — terminal pages you navigate to rather than
    // menus you navigate from (the whole AI & Agents sections, every Sync and
    // Advanced leaf, the top-level leaves like flags/theming, and the entity
    // editors — but not the menu hubs or browse lists) — slide the bar away
    // instead of removing it: nothing replaces the bar there, so an instant
    // unmount would read as a jumpy glitch rather than a handoff to a
    // page-owned surface. Project details (`/projects/<id>`) are the same
    // kind of terminal page and share the motion, as do a goal's own pages,
    // a habit editor and a person's. See [settingsRouteHidesBottomNav],
    // [projectsRouteHidesBottomNav], [goalsRouteHidesBottomNav] and
    // [habitsRouteHidesBottomNav] and [peopleRouteHidesBottomNav].
    final slideNavAway =
        (destinations[index].kind == _AppNavigationDestinationKind.settings &&
            settingsRouteHidesBottomNav(
              navService.settingsDelegate.currentBeamLocation,
            )) ||
        (destinations[index].kind == _AppNavigationDestinationKind.projects &&
            projectsRouteHidesBottomNav(
              navService.projectsDelegate.currentBeamLocation,
            )) ||
        (destinations[index].kind == _AppNavigationDestinationKind.goals &&
            goalsRouteHidesBottomNav(
              navService.goalsDelegate.currentBeamLocation,
            )) ||
        (destinations[index].kind == _AppNavigationDestinationKind.habits &&
            habitsRouteHidesBottomNav(
              navService.habitsDelegate.currentBeamLocation,
            )) ||
        (destinations[index].kind == _AppNavigationDestinationKind.people &&
            peopleRouteHidesBottomNav(
              navService.relationshipsDelegate.currentBeamLocation,
            ));

    final launcherHeight = MobileNavigationLauncher.barHeight(context);

    // The launcher's row: the menu button that slides the sidebar in and,
    // on the list tabs that hand one over, the active page's create action.
    // Built lazily: on routes that suppress the bar entirely it is never
    // constructed.
    Widget buildLauncher() => MobileNavigationLauncher(
      onOpenMenu: _mobileDrawer.open,
      pageAction: _launcherDockAction(context, destinations[index].kind),
    );

    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final body = Stack(
      children: [
        const IncomingVerificationWrapper(),
        // The scope keeps `occupiedHeight` (and every page padding by it)
        // in sync with the activity island floating above the bar, so the
        // island never covers scroll content or floating actions.
        _MobileNavOverlayHeightScope(
          navBarVisible: showBottomNav,
          // A slid-away bar reserves nothing: the goal agent pages, project
          // details and settings details dock their own pinned surfaces at
          // the bottom edge and must not pad around a bar that is gone.
          barDocked: showBottomNav && !slideNavAway,
          child: _buildContentStack(
            index: index,
            beamerChildren: beamerChildren,
          ),
        ),
        if (showBottomNav) ...[
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _SlideAwayBottomNav(
              hidden: slideNavAway,
              child: buildLauncher(),
            ),
          ),
          // The activity island (running timer / recording) floats above
          // the bar but is deliberately not part of the slide-away
          // subtree: a running timer or recording must stay visible inside
          // settings definition surfaces. When the bar slides away the
          // island animates down to the bottom safe-area edge in the same
          // motion, keeping its gap above whichever edge it lands on.
          AnimatedPositioned(
            duration: reduceMotion
                ? Duration.zero
                : _SlideAwayBottomNav.slideDuration,
            curve: _SlideAwayBottomNav.slideCurve,
            left: 0,
            right: 0,
            bottom:
                (slideNavAway
                    ? MediaQuery.paddingOf(context).bottom
                    : launcherHeight) +
                MobileActivityIsland.gapAboveBar(context),
            // The recording half is omitted on Flatpak builds (MediaKit
            // compatibility issues).
            child: MobileActivityIsland(omitAudio: _isRunningInFlatpak()),
          ),
        ],
      ],
    );
    // The whole mobile shell — page, launcher and activity island — is what
    // the drawer pushes aside, so nothing of it floats over the panel.
    return MobileNavigationDrawerHost(
      controller: _mobileDrawer,
      drawerBuilder: (context) => _buildMobileDrawer(
        context,
        index: index,
        destinations: destinations,
      ),
      child: Scaffold(extendBody: true, body: body),
    );
  }

  /// The mobile sidebar navigation's panel: the desktop rail's own sidebar,
  /// never collapsed and without its toggle, with the app-wide Recents list
  /// beneath the destinations and the activity summary — recording, timer
  /// and agent wakes — above Settings, as on desktop.
  ///
  /// Of the under-row subtrees the desktop rail shows, the saved filters
  /// come along beneath an active Tasks row, so the phone reaches every
  /// saved filter from the same place the desktop does. The month calendar
  /// and the impact entry are left out: they are desktop surfaces that do
  /// not size for touch.
  ///
  /// Every choice closes the drawer: a destination or a recent search
  /// closes it before navigating, a saved filter once applied, and the
  /// activity rows that navigate on their own close it through
  /// [_closeMobileDrawerOnRouteChange]. Destination indices are resolved at
  /// tap time, so a flag change while the drawer is open cannot route a tap
  /// through a stale index.
  Widget _buildMobileDrawer(
    BuildContext context, {
    required int index,
    required List<_AppNavigationDestination> destinations,
  }) {
    final sidebar = _SidebarDestinations(destinations, index);

    void select(_AppNavigationDestinationKind kind) {
      _mobileDrawer.close();
      final tapIndex = _currentDestinationIndex(kind);
      if (tapIndex != null) navService.tapIndex(tapIndex);
    }

    return DesktopNavigationSidebar(
      destinations: [
        for (final destination in sidebar.main)
          destination.toDesktopSidebarDestination(
            includeExpandedChild:
                destination.kind == _AppNavigationDestinationKind.tasks,
            expandedChild: () =>
                SidebarSavedTaskFilters(onApplied: _mobileDrawer.close),
          ),
      ],
      activeIndex: sidebar.mainActiveIndex,
      onDestinationSelected: (i) => select(sidebar.main[i].kind),
      settingsDestination: sidebar.settings?.toDesktopSidebarDestination(),
      onSettingsSelected: () => select(_AppNavigationDestinationKind.settings),
      isSettingsActive: sidebar.isSettingsActive,
      width: MobileNavigationDrawerHost.drawerWidth(context),
      showToggle: false,
      // Tighter than the desktop rail: each row is a full touch target
      // already, and the Recents list below wants to be seen without a
      // scroll on a phone with every section switched on.
      destinationGap: context.designTokens.spacing.step1,
      belowDestinations: RecentSearchesSection(
        surfaces: {
          for (final destination in destinations)
            ?_recentSearchSurfaceFor(
              destination.kind,
            ): RecentSearchSurfacePresentation(
              label: destination.label,
              icon: destination.iconBuilder(active: false),
            ),
        },
        onSelected: (search) {
          _mobileDrawer.close();
          openRecentSearch(ref, search, navService: navService);
        },
      ),
      aboveSettings: const _SidebarAboveSettings(),
      footerBand: const ContactSupportRow(),
    );
  }

  /// The active page's primary action, docked on the mobile navigation
  /// launcher's row instead of floating in the page's own corner.
  ///
  /// Exactly the destinations whose list page floats a create button on
  /// desktop: leaving it in the corner would stack two floating controls
  /// above the launcher, neither of them looking placed. Daily OS,
  /// Dashboards and Settings float nothing, so they leave the menu button
  /// alone on the row — which is what makes a docked action read as
  /// belonging to the page rather than to the shell. The action sits in the
  /// trailing corner, opposite the menu button.
  ///
  /// The page decides the chip's wording, not this switch: the task and
  /// people lists word their actions, the lists whose own heading says what
  /// gets added keep the bare glyph (see [MobileNavDockAction]).
  ///
  /// Not route-sensitive: no tab's detail page keeps the launcher while
  /// owning a different action. The projects, goals, habits and people tabs
  /// slide the whole launcher away on their detail routes, and an entry's or
  /// an event's page unmounts it for its own action bar, so a stale action is
  /// never on screen.
  MobileNavDockAction? _launcherDockAction(
    BuildContext context,
    _AppNavigationDestinationKind kind,
  ) => switch (kind) {
    _AppNavigationDestinationKind.tasks => tasksTabDockAction(context, ref),
    _AppNavigationDestinationKind.journal => logbookDockAction(context, ref),
    _AppNavigationDestinationKind.goals => unifiedGoalsDockAction(context, ref),
    _AppNavigationDestinationKind.habits => habitsTabDockAction(context, ref),
    _AppNavigationDestinationKind.projects => projectsTabDockAction(
      context,
      ref,
    ),
    _AppNavigationDestinationKind.people => peopleTabDockAction(context),
    _AppNavigationDestinationKind.events => eventsTabDockAction(context),
    _AppNavigationDestinationKind.dailyOs ||
    _AppNavigationDestinationKind.dashboards ||
    _AppNavigationDestinationKind.settings => null,
  };

  List<_AppNavigationDestination> _buildNavigationDestinations({
    required BuildContext context,
    required bool isProjectsPageEnabled,
    required bool isDailyOsPageEnabled,
    required bool isUnifiedGoalsPageEnabled,
    required bool isHabitsPageEnabled,
    required bool isDashboardsPageEnabled,
    required bool isEventsPageEnabled,
    required bool isRelationshipsPageEnabled,
  }) {
    final allDestinations = <_AppNavigationDestination>[
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.tasks,
        label: context.messages.navTabTitleTasks,
        iconBuilder: ({required active}) => const Icon(LottiIcons.list),
        expandedChildBuilder: () => const SidebarSavedTaskFilters(),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.dailyOs,
        label: context.messages.navTabTitleCalendar,
        iconBuilder: ({required active}) => const Icon(LottiIcons.today),
        // Month calendar (design handoff sidebar spec) renders beneath
        // the row only while Daily OS is the active tab — same slot the
        // Tasks destination uses for its saved-filters tree. The Time
        // Analysis sub-entry sits under the calendar and opens the
        // full-screen analytics surface at /calendar/time.
        expandedChildBuilder: () => const DailyOsSidebarSection(),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.projects,
        label: context.messages.navTabTitleProjects,
        iconBuilder: ({required active}) =>
            Icon(active ? LottiIconsFilled.folder : LottiIcons.folder),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.goals,
        label: context.messages.navTabTitleGoals,
        iconBuilder: ({required active}) => const Icon(
          LottiIcons.focus,
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.habits,
        label: context.messages.navTabTitleHabits,
        iconBuilder: ({required active}) => const Icon(
          LottiIcons.checkAll,
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.dashboards,
        label: context.messages.navTabTitleInsights,
        iconBuilder: ({required active}) => const Icon(
          LottiIcons.chart,
        ),
        expandedChildBuilder: () => const ImpactSidebarEntry(),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.people,
        label: context.messages.navTabTitlePeople,
        iconBuilder: ({required active}) => const Icon(LottiIcons.people),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.journal,
        label: context.messages.navTabTitleJournal,
        iconBuilder: ({required active}) => const Icon(
          LottiIcons.book,
        ),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.events,
        label: context.messages.navTabTitleEvents,
        iconBuilder: ({required active}) => const Icon(LottiIcons.calendar),
      ),
      _AppNavigationDestination(
        kind: _AppNavigationDestinationKind.settings,
        label: context.messages.navTabTitleSettings,
        iconBuilder: ({required active}) => const Icon(LottiIcons.settings),
        trailingBuilder: ({required active}) => const SyncQueueCounts(),
      ),
    ];

    final enabledKinds = _enabledDestinationKinds(
      isProjectsPageEnabled: isProjectsPageEnabled,
      isDailyOsPageEnabled: isDailyOsPageEnabled,
      isUnifiedGoalsPageEnabled: isUnifiedGoalsPageEnabled,
      isHabitsPageEnabled: isHabitsPageEnabled,
      isDashboardsPageEnabled: isDashboardsPageEnabled,
      isEventsPageEnabled: isEventsPageEnabled,
      isRelationshipsPageEnabled: isRelationshipsPageEnabled,
    );
    final result = allDestinations
        .where((destination) => enabledKinds.contains(destination.kind))
        .toList(growable: false);
    // The mobile drawer resolves tap indices from _enabledDestinationKinds
    // while this list (ordered by `allDestinations`) drives the
    // IndexedStack — a reorder of one without the other silently
    // misroutes taps, so pin their agreement.
    assert(
      listEquals(
        result.map((destination) => destination.kind).toList(),
        enabledKinds,
      ),
      'allDestinations order must match _enabledDestinationKinds',
    );
    return result;
  }

  /// Destination index of [kind] as enabled *right now*, read directly
  /// from the NavService flag getters — the same ordering
  /// [_buildNavigationDestinations] uses via [_enabledDestinationKinds].
  /// Resolved at tap time by the mobile drawer so a flag change while the
  /// drawer is open cannot route a tap through a stale index. Null when
  /// [kind] got disabled in the meantime.
  int? _currentDestinationIndex(_AppNavigationDestinationKind kind) {
    final index = _enabledDestinationKinds(
      isProjectsPageEnabled: navService.isProjectsPageEnabled,
      isDailyOsPageEnabled: navService.isDailyOsPageEnabled,
      isUnifiedGoalsPageEnabled: navService.isUnifiedGoalsPageEnabled,
      isHabitsPageEnabled: navService.isHabitsPageEnabled,
      isDashboardsPageEnabled: navService.isDashboardsPageEnabled,
      isEventsPageEnabled: navService.isEventsPageEnabled,
      isRelationshipsPageEnabled: navService.isRelationshipsPageEnabled,
    ).indexOf(kind);
    return index == -1 ? null : index;
  }
}

/// The search surface a destination owns, or null for one with no content
/// search. Only enabled destinations reach the Recents section through
/// this, which is what hides a search remembered on a switched-off section.
RecentSearchSurface? _recentSearchSurfaceFor(
  _AppNavigationDestinationKind kind,
) => switch (kind) {
  _AppNavigationDestinationKind.tasks => RecentSearchSurface.tasks,
  _AppNavigationDestinationKind.journal => RecentSearchSurface.logbook,
  _AppNavigationDestinationKind.projects => RecentSearchSurface.projects,
  _AppNavigationDestinationKind.habits => RecentSearchSurface.habits,
  _ => null,
};

/// The banner surface a destination maps onto, or null where no dock
/// mounts — Settings and the Logbook are deliberately excluded, and goal
/// detail shows its own goal's banner uncycled instead. Per-kind
/// visibility on a surface is the dock's own filter (ADR 0059 Decision 6):
/// goal nudges keep the main working tabs from the design handover
/// (Tasks, DailyOS, Habits); relationship nudges add the People pages.
NudgeBannerSurface? _nudgeBannerSurfaceFor(
  _AppNavigationDestinationKind kind,
) => switch (kind) {
  _AppNavigationDestinationKind.tasks => NudgeBannerSurface.tasks,
  _AppNavigationDestinationKind.dailyOs => NudgeBannerSurface.dailyOs,
  _AppNavigationDestinationKind.habits => NudgeBannerSurface.habits,
  _AppNavigationDestinationKind.people => NudgeBannerSurface.people,
  _ => null,
};
