import 'dart:async';
import 'dart:convert';

import 'package:beamer/beamer.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';
import 'package:rxdart/rxdart.dart';

/// Legacy settings key: a single route string, the active tab's path.
/// Still READ once at restore as a migration fallback for [navStateKey]'s
/// `active` field, never written any more.
const String lastRouteKey = 'NAV_LAST_ROUTE';

/// Settings key holding the whole navigation state as JSON — the active tab
/// and every tab's own route. See [NavStateSnapshot].
const String navStateKey = 'NAV_STATE';

/// The persisted navigation state: which tab was active and where each tab
/// stood within its own Beamer stack.
///
/// The active tab is stored as its ROOT PATH rather than as an index, because
/// indices shift whenever a feature flag toggles a tab in or out — a stored
/// `3` means a different tab after the flag streams emit, a stored `/goals`
/// does not.
@immutable
class NavStateSnapshot {
  const NavStateSnapshot({required this.activeRootPath, required this.routes});

  /// Parses [json], returning null for anything malformed or of an unknown
  /// version. A corrupt row must degrade to "no saved state" (land on Tasks),
  /// never throw during bootstrap.
  static NavStateSnapshot? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['v'] != _version) return null;
      final active = decoded['active'];
      if (active is! String || active.isEmpty) return null;
      final rawRoutes = decoded['routes'];
      final routes = <String, String>{};
      if (rawRoutes is Map) {
        for (final entry in rawRoutes.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is String && value.isNotEmpty) {
            routes[key] = value;
          }
        }
      }
      return NavStateSnapshot(activeRootPath: active, routes: routes);
    } on FormatException {
      return null;
    }
  }

  static const int _version = 1;

  /// Root path of the tab that was active, e.g. `/tasks`.
  final String activeRootPath;

  /// Root path -> the route that tab stood at, e.g. `/tasks` -> `/tasks/<id>`.
  final Map<String, String> routes;

  String encode() => jsonEncode({
    'v': _version,
    'active': activeRootPath,
    'routes': routes,
  });

  /// The active tab's own route — what a caller asking "where is the user?"
  /// wants, falling back to the tab root when that tab has no deeper route.
  String get activeRoute => routes[activeRootPath] ?? activeRootPath;
}

/// Lightweight snapshot of the current settings route for the desktop
/// split-pane view.
typedef DesktopSettingsRoute = ({
  String path,
  Map<String, String> pathParameters,
  Map<String, String> queryParameters,
});

class NavService {
  NavService({
    JournalDb? journalDb,
    SettingsDb? settingsDb,
  }) {
    _journalDb = journalDb ?? getIt<JournalDb>();
    _settingsDb = settingsDb ?? getIt<SettingsDb>();
    resetTabsToRoots();

    _navigationFlagsSub =
        Rx.combineLatest7<
              bool,
              bool,
              bool,
              bool,
              bool,
              bool,
              bool,
              ({
                bool habits,
                bool dashboards,
                bool dailyOs,
                bool projects,
                bool events,
                bool unifiedGoals,
                bool relationships,
              })
            >(
              _journalDb.watchConfigFlag(enableHabitsPageFlag),
              _journalDb.watchConfigFlag(enableDashboardsPageFlag),
              _journalDb.watchConfigFlag(enableDailyOsPageFlag),
              _journalDb.watchConfigFlag(enableProjectsFlag),
              _journalDb.watchConfigFlag(enableEventsFlag),
              _journalDb.watchConfigFlag(enableUnifiedGoalsFlag),
              _journalDb.watchConfigFlag(enableRelationshipsFlag),
              (
                habits,
                dashboards,
                dailyOs,
                projects,
                events,
                unifiedGoals,
                relationships,
              ) => (
                habits: habits,
                dashboards: dashboards,
                dailyOs: dailyOs,
                projects: projects,
                events: events,
                unifiedGoals: unifiedGoals,
                relationships: relationships,
              ),
            )
            .listen(_handleNavigationFlagsUpdated);
  }

  late final JournalDb _journalDb;
  late final SettingsDb _settingsDb;
  late final StreamSubscription<
    ({
      bool habits,
      bool dashboards,
      bool dailyOs,
      bool projects,
      bool events,
      bool unifiedGoals,
      bool relationships,
    })
  >
  _navigationFlagsSub;

  bool _isDesktopMode = false;

  /// Whether the app is currently in desktop layout mode (sidebar visible).
  /// Set by `AppScreen` based on the current window width.
  bool get isDesktopMode => _isDesktopMode;

  /// Crossing the desktop/mobile breakpoint changes what every route MEANS:
  /// the locations branch on this flag to decide whether a detail is a pushed
  /// page (mobile) or a right-hand pane (desktop). The shell keeps its nav
  /// subtree alive across the breakpoint (see the `GlobalKey` in `AppScreen`),
  /// so nothing rebuilds the delegates by accident any more — the change has
  /// to be announced, or a task opened on desktop would resize down to a
  /// detail-less list.
  ///
  /// Deferred to after the frame because `AppScreen.build` assigns this
  /// DURING build, and `update(rebuild: true)` notifies listeners.
  set isDesktopMode(bool value) {
    if (_isDesktopMode == value) return;
    _isDesktopMode = value;
    _rebuildAllDelegatesAfterFrame();
  }

  void _rebuildAllDelegatesAfterFrame() {
    if (_layoutRebuildScheduled) return;
    _layoutRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _layoutRebuildScheduled = false;
      if (_disposed) return;
      for (final spec in _tabSpecs) {
        // `takePriority: false`: re-rendering every tab for the new form
        // factor must not reshuffle which delegate is the active one.
        spec.delegate.update(takePriority: false);
      }
    });
  }

  bool _layoutRebuildScheduled = false;
  bool _disposed = false;

  /// Suppresses persistence while [restoreNavigationState] is reading, so the
  /// config-flag streams landing mid-restore cannot overwrite the saved row
  /// with the not-yet-restored default.
  bool _restoreInFlight = false;

  /// The active tab's root path pending restore, held until the config-flag
  /// streams have emitted at least once.
  ///
  /// At construction every flag reads `false`, so a saved tab behind a flag
  /// (`/goals`, `/projects`, …) is not yet in [_enabledTabSpecs] and
  /// `_normalizePath` would drop it to Tasks. Consumed by the first
  /// [_handleNavigationFlagsUpdated].
  String? _pendingActiveRootPath;

  /// Whether the config-flag streams have emitted at least once, i.e. whether
  /// [_enabledTabSpecs] reflects reality yet.
  bool _flagsReceived = false;

  /// Per-tab routes, keyed by tab root path. The persisted half of the
  /// nine independent Beamer stacks.
  final Map<String, String> _routesByTab = <String, String>{};

  /// Desktop split-pane task detail stack.
  ///
  /// Index 0 is the task selected from the list pane (the "base"). Tapping
  /// a linked task from within a task's details pushes onto the stack so
  /// the detail pane shows it without covering the list pane. Popping
  /// returns to the previous task. URL-driven changes (Beamer location)
  /// reset the stack to a single entry.
  final ValueNotifier<List<String>> desktopTaskDetailStack =
      ValueNotifier<List<String>>(const <String>[]);

  /// Convenience notifier mirroring `desktopTaskDetailStack.last` (or
  /// `null` when the stack is empty). Kept as a separate notifier so
  /// existing listeners (selected-row highlighting, etc.) keep working.
  final ValueNotifier<String?> desktopSelectedTaskId = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> desktopSelectedProjectId =
      ValueNotifier<String?>(null);
  final ValueNotifier<String?> desktopSelectedDashboardId =
      ValueNotifier<String?>(null);

  /// Desktop split-pane logbook selection — the entry whose details fill the
  /// right pane, or `null` for the empty state.
  ///
  /// Written exclusively by `JournalLocation` from the URL, so the route stays
  /// the single source of truth. Unlike tasks there is no stack: logbook
  /// entries do not open other entries in place, so a single slot is enough.
  final ValueNotifier<String?> desktopSelectedEntryId = ValueNotifier<String?>(
    null,
  );

  /// Whether the full-screen Time Analysis surface is active. Written
  /// exclusively by `CalendarLocation` from the URL (`/calendar/time`) —
  /// the URL is the single source of truth; the Daily OS sidebar
  /// sub-entry only reads it for its highlight.
  final ValueNotifier<bool> desktopShowTimeAnalysis = ValueNotifier<bool>(
    false,
  );

  /// Whether the AI Impact dashboard (`/dashboards/impact`) is showing.
  /// Written by route locations from the URL so the Insights sidebar
  /// sub-entry only reads it for its highlight.
  final ValueNotifier<bool> desktopShowAiImpact = ValueNotifier<bool>(
    false,
  );

  /// Tracks the current settings sub-route on desktop so the right pane
  /// can render the matching content page.
  final ValueNotifier<DesktopSettingsRoute?> desktopSelectedSettingsRoute =
      ValueNotifier<DesktopSettingsRoute?>(null);

  bool _isHabitsPageEnabled = false;
  bool _isUnifiedGoalsPageEnabled = false;
  bool _isDashboardsPageEnabled = false;
  bool _isDailyOsPageEnabled = false;
  bool _isProjectsPageEnabled = false;
  bool _isEventsPageEnabled = false;
  bool _isRelationshipsPageEnabled = false;

  String currentPath = '/tasks';
  final indexStreamController = StreamController<int>.broadcast();

  final tasksIndex = 0;

  int index = 0;

  final BeamerDelegate habitsDelegate = habitsBeamerDelegate;
  final BeamerDelegate dashboardsDelegate = dashboardsBeamerDelegate;
  final BeamerDelegate journalDelegate = journalBeamerDelegate;
  final BeamerDelegate eventsDelegate = eventsBeamerDelegate;
  final BeamerDelegate projectsDelegate = projectsBeamerDelegate;
  final BeamerDelegate tasksDelegate = tasksBeamerDelegate;
  final BeamerDelegate calendarDelegate = calendarBeamerDelegate;
  final BeamerDelegate settingsDelegate = settingsBeamerDelegate;
  final BeamerDelegate goalsDelegate = goalsBeamerDelegate;
  final BeamerDelegate relationshipsDelegate = relationshipsBeamerDelegate;

  /// Sends every tab back to its root path and selects Tasks.
  ///
  /// The per-tab [BeamerDelegate]s are top-level finals, so they OUTLIVE
  /// `getIt.reset()` — a profile switch replaces this service, the databases
  /// and the whole widget tree, but not them. Without this, a tab kept the
  /// route it held in the previous world: exit the demo after opening a
  /// logbook entry and the Logbook tab still pointed at that demo entry's id,
  /// which does not exist in the real journal. It also left the app on
  /// whichever tab the previous world ended on, rather than the Tasks landing
  /// this app defaults to.
  ///
  /// Called from the constructor, so it runs once per service generation —
  /// which is exactly once per world, on cold start and on every switch.
  void resetTabsToRoots() {
    for (final spec in _tabSpecs) {
      // Unconditionally, including disabled tabs: a flag can be turned back
      // on later, and a stale route must not be waiting behind it.
      spec.delegate.beamToReplacementNamed(spec.rootPath);
    }
    _routesByTab.clear();
    _pendingActiveRootPath = null;
    currentPath = _enabledTabSpecs.first.rootPath;
    index = 0;
  }

  /// Restores the tab routes and the active tab persisted by the previous
  /// session, so the app comes back on exactly the screen it was left on.
  ///
  /// Awaited from `registerSingletons` BEFORE `runApp`, so the restored state
  /// is in place for the very first frame rather than flashing Tasks first.
  ///
  /// The active tab cannot be applied here: the config-flag streams have not
  /// emitted yet, so a flag-gated tab is not in [_enabledTabSpecs] and would
  /// be normalised away. It is parked in [_pendingActiveRootPath] and applied
  /// by the first [_handleNavigationFlagsUpdated]. The per-tab routes ARE
  /// applied immediately: the delegates exist regardless of their flags.
  ///
  /// Nothing saved, or a corrupt row, leaves the constructor's
  /// [resetTabsToRoots] result standing — Tasks, all tabs at their roots.
  Future<void> restoreNavigationState() async {
    // Set BEFORE the first await: the flag streams emit on a later microtask,
    // and their `_setIndexInternal` would otherwise write `{active: /tasks}`
    // over the very row this method is still reading.
    _restoreInFlight = true;
    try {
      await _restoreNavigationState();
    } finally {
      _restoreInFlight = false;
    }
    unawaited(_persistState());
  }

  Future<void> _restoreNavigationState() async {
    final snapshot =
        NavStateSnapshot.decode(await _settingsDb.itemByKey(navStateKey)) ??
        await _legacySnapshot();
    if (snapshot == null) return;

    for (final spec in _tabSpecs) {
      final route = snapshot.routes[spec.rootPath];
      if (route == null || route == spec.rootPath) continue;
      if (!_matchesRootPath(route, spec.rootPath)) continue;
      _routesByTab[spec.rootPath] = route;
      spec.delegate.beamToReplacementNamed(route);
    }

    _pendingActiveRootPath = snapshot.activeRootPath;
    currentPath = snapshot.activeRoute;
    // The flag streams may already have emitted while this method awaited the
    // settings reads, in which case nothing is coming to consume the pending
    // tab and it has to be applied here instead.
    if (_flagsReceived) {
      _consumePendingActiveTab();
    }
  }

  /// Selects the tab parked by [restoreNavigationState], if any and if its
  /// flag allows it. Returns true when it took over selection, so the caller
  /// skips its own normalisation.
  bool _consumePendingActiveTab() {
    final pendingActiveRootPath = _pendingActiveRootPath;
    if (pendingActiveRootPath == null) return false;
    _pendingActiveRootPath = null;

    final restored = _specForPath(pendingActiveRootPath);
    if (restored == null) {
      // The saved tab's flag is off — leave the path for the caller to
      // normalise, which lands on Tasks exactly as an install with nothing
      // saved does.
      currentPath = pendingActiveRootPath;
      return false;
    }
    currentPath = _routesByTab[restored.rootPath] ?? restored.rootPath;
    _setIndexInternal(
      beamerDelegates.indexOf(restored.delegate),
      syncPath: false,
    );
    return true;
  }

  /// Reads the pre-JSON `NAV_LAST_ROUTE` row, so an install upgrading into
  /// this version still comes back on its last tab instead of on Tasks.
  Future<NavStateSnapshot?> _legacySnapshot() async {
    final route = await _settingsDb.itemByKey(lastRouteKey);
    if (route == null || route.isEmpty) return null;
    final spec = _specForAnyPath(route);
    if (spec == null) return null;
    return NavStateSnapshot(
      activeRootPath: spec.rootPath,
      routes: {spec.rootPath: route},
    );
  }

  bool get isHabitsPageEnabled => _isHabitsPageEnabled;
  bool get isUnifiedGoalsPageEnabled => _isUnifiedGoalsPageEnabled;
  bool get isDashboardsPageEnabled => _isDashboardsPageEnabled;
  bool get isDailyOsPageEnabled => _isDailyOsPageEnabled;
  bool get isProjectsPageEnabled => _isProjectsPageEnabled;
  bool get isEventsPageEnabled => _isEventsPageEnabled;
  bool get isRelationshipsPageEnabled => _isRelationshipsPageEnabled;

  List<BeamerDelegate>? _cachedBeamerDelegates;

  Iterable<({bool enabled, String rootPath, BeamerDelegate delegate})>
  get _tabSpecs sync* {
    // Tab order is shared with the app shell's destination list (see
    // `_buildNavigationDestinations` in `beamer_app.dart`): Tasks and
    // Daily OS lead as the most important pages, then Projects, then the
    // rest, with Settings last.
    yield (enabled: true, rootPath: '/tasks', delegate: tasksDelegate);
    yield (
      enabled: _isDailyOsPageEnabled,
      rootPath: '/calendar',
      delegate: calendarDelegate,
    );
    yield (
      enabled: _isProjectsPageEnabled,
      rootPath: '/projects',
      delegate: projectsDelegate,
    );
    // The unified Goals tab occupies the Habits slot (the design handover's
    // cutover position); both can be on at once during the flagged rollout.
    // It hosts the goal agent detail/chat/wizard pages under `/goals/...`.
    yield (
      enabled: _isUnifiedGoalsPageEnabled,
      rootPath: '/goals',
      delegate: goalsDelegate,
    );
    yield (
      enabled: _isHabitsPageEnabled,
      rootPath: '/habits',
      delegate: habitsDelegate,
    );
    yield (
      enabled: _isDashboardsPageEnabled,
      rootPath: '/dashboards',
      delegate: dashboardsDelegate,
    );
    yield (
      enabled: _isRelationshipsPageEnabled,
      rootPath: '/people',
      delegate: relationshipsDelegate,
    );
    yield (enabled: true, rootPath: '/journal', delegate: journalDelegate);
    yield (
      enabled: _isEventsPageEnabled,
      rootPath: '/events',
      delegate: eventsDelegate,
    );
    yield (enabled: true, rootPath: '/settings', delegate: settingsDelegate);
  }

  Iterable<({bool enabled, String rootPath, BeamerDelegate delegate})>
  get _enabledTabSpecs => _tabSpecs.where((spec) => spec.enabled);

  bool _matchesRootPath(String path, String rootPath) {
    return path == rootPath || path.startsWith('$rootPath/');
  }

  ({bool enabled, String rootPath, BeamerDelegate delegate})? _specForPath(
    String path,
  ) {
    for (final spec in _enabledTabSpecs) {
      if (_matchesRootPath(path, spec.rootPath)) {
        return spec;
      }
    }
    return null;
  }

  /// Like [_specForPath] but over every tab, enabled or not.
  ///
  /// Route persistence and restore both run while the config flags still read
  /// `false` (at construction) or may have moved since a route was saved. A
  /// disabled tab still owns its route — it just cannot be the active one.
  ({bool enabled, String rootPath, BeamerDelegate delegate})? _specForAnyPath(
    String path,
  ) {
    for (final spec in _tabSpecs) {
      if (_matchesRootPath(path, spec.rootPath)) {
        return spec;
      }
    }
    return null;
  }

  String _normalizePath(String path) {
    return _specForPath(path) == null ? _enabledTabSpecs.first.rootPath : path;
  }

  /// The root path of the tab at [index], or Tasks when the index is stale.
  String get _activeRootPath {
    final delegates = beamerDelegates;
    if (index < 0 || index >= delegates.length) {
      return _enabledTabSpecs.first.rootPath;
    }
    final active = delegates[index];
    for (final spec in _enabledTabSpecs) {
      if (identical(spec.delegate, active)) return spec.rootPath;
    }
    return _enabledTabSpecs.first.rootPath;
  }

  /// [syncPath] is false for callers that have ALREADY set [currentPath] to
  /// the route they are about to beam to: the target delegate still holds its
  /// previous route at that point, so deriving the path from it would clobber
  /// the newer value with the older one.
  void _setIndexInternal(
    int newIndex, {
    bool emit = true,
    bool syncPath = true,
  }) {
    index = newIndex;
    if (syncPath) {
      final rootPath = _activeRootPath;
      currentPath = _routesByTab[rootPath] ?? rootPath;
    }
    delegateByIndex(index).update(rebuild: false);
    unawaited(_persistState());
    if (emit) {
      emitState();
    }
  }

  /// Writes the active tab and every tab's route to [navStateKey].
  ///
  /// Fire-and-forget from the navigation call sites; failures are non-fatal
  /// (the next navigation writes again, and a missing row just means the next
  /// cold start lands on Tasks).
  Future<void> _persistState() async {
    if (_disposed || _restoreInFlight) return;
    await _settingsDb.saveSettingsItem(
      navStateKey,
      NavStateSnapshot(
        activeRootPath: _activeRootPath,
        routes: Map<String, String>.of(_routesByTab),
      ).encode(),
    );
  }

  void _handleNavigationFlagsUpdated(
    ({
      bool habits,
      bool dashboards,
      bool dailyOs,
      bool projects,
      bool events,
      bool unifiedGoals,
      bool relationships,
    })
    flags,
  ) {
    _isHabitsPageEnabled = flags.habits;
    _isUnifiedGoalsPageEnabled = flags.unifiedGoals;
    _isDashboardsPageEnabled = flags.dashboards;
    _isDailyOsPageEnabled = flags.dailyOs;
    _isProjectsPageEnabled = flags.projects;
    _isEventsPageEnabled = flags.events;
    _isRelationshipsPageEnabled = flags.relationships;
    _cachedBeamerDelegates = null;
    _flagsReceived = true;

    // First emission after a restore: the flags are finally known, so a saved
    // flag-gated tab can be selected. Consumed once — later flag changes must
    // move the user off a tab that just disappeared, not back onto the tab
    // they were on at boot.
    if (_consumePendingActiveTab()) return;

    final previousPath = currentPath;
    final normalizedPath = _normalizePath(previousPath);
    final matchingSpec = _specForPath(normalizedPath);
    if (matchingSpec == null) {
      currentPath = _enabledTabSpecs.first.rootPath;
      _setIndexInternal(0);
      return;
    }

    currentPath = normalizedPath;
    final newIndex = beamerDelegates.indexOf(matchingSpec.delegate);
    _setIndexInternal(newIndex, emit: false);

    if (normalizedPath != previousPath) {
      delegateByIndex(index).beamToNamed(normalizedPath);
      unawaited(persistNamedRoute(normalizedPath));
    }

    emitState();
  }

  void emitState() {
    indexStreamController.add(index);
  }

  void setPath(String path) {
    final normalizedPath = _normalizePath(path);
    final matchingSpec = _specForPath(normalizedPath);
    if (matchingSpec == null) {
      currentPath = _enabledTabSpecs.first.rootPath;
      _setIndexInternal(0);
      return;
    }

    currentPath = normalizedPath;
    _routesByTab[matchingSpec.rootPath] = normalizedPath;
    _setIndexInternal(
      beamerDelegates.indexOf(matchingSpec.delegate),
      syncPath: false,
    );
  }

  List<BeamerDelegate> get beamerDelegates => _cachedBeamerDelegates ??=
      _enabledTabSpecs.map((spec) => spec.delegate).toList(growable: false);

  BeamerDelegate delegateByIndex(int index) {
    return beamerDelegates[index];
  }

  int get calendarIndex => beamerDelegates.indexOf(calendarDelegate);
  int get habitsIndex => beamerDelegates.indexOf(habitsDelegate);
  int get goalsIndex => beamerDelegates.indexOf(goalsDelegate);
  int get dashboardsIndex => beamerDelegates.indexOf(dashboardsDelegate);
  int get projectsIndex => beamerDelegates.indexOf(projectsDelegate);
  int get journalIndex => beamerDelegates.indexOf(journalDelegate);
  int get eventsIndex => beamerDelegates.indexOf(eventsDelegate);
  int get settingsIndex => beamerDelegates.indexOf(settingsDelegate);

  void setTabRoot(int newIndex) {
    final delegate = delegateByIndex(newIndex);
    for (final spec in _enabledTabSpecs) {
      if (spec.delegate == delegate) {
        beamToNamed(spec.rootPath);
        break;
      }
    }
  }

  void setIndex(int newIndex) {
    _setIndexInternal(newIndex);
  }

  void tapIndex(int newIndex) {
    if (index != newIndex) {
      setIndex(newIndex);
    } else {
      setTabRoot(newIndex);
    }
  }

  Stream<int> getIndexStream() {
    return indexStreamController.stream;
  }

  /// Reset the desktop task detail stack to either `[taskId]` or empty.
  /// Called from `TasksLocation` when the URL changes so the stack stays
  /// in sync with the route.
  ///
  /// Idempotent across Beamer rebuilds: if the stack is already anchored
  /// at the given `taskId` (i.e. `stack.first == taskId`), the stack is
  /// left untouched so a `pushDesktopTaskDetail`-built linked-task stack
  /// is preserved when `buildPages` re-runs for the same URL (theme
  /// changes, provider rebuilds, etc.).
  void resetDesktopTaskDetail(String? taskId) {
    final current = desktopTaskDetailStack.value;
    if (taskId == null) {
      if (current.isNotEmpty) {
        desktopTaskDetailStack.value = const <String>[];
      }
      if (desktopSelectedTaskId.value != null) {
        desktopSelectedTaskId.value = null;
      }
      return;
    }

    if (current.isNotEmpty && current.first == taskId) {
      // Stack is already anchored at this base task — preserve any
      // linked-task pushes layered on top of it.
      if (desktopSelectedTaskId.value != current.last) {
        desktopSelectedTaskId.value = current.last;
      }
      return;
    }

    desktopTaskDetailStack.value = <String>[taskId];
    if (desktopSelectedTaskId.value != taskId) {
      desktopSelectedTaskId.value = taskId;
    }
  }

  /// Push a linked task onto the desktop detail stack so the right pane
  /// shows it without covering the task list pane.
  void pushDesktopTaskDetail(String taskId) {
    final current = desktopTaskDetailStack.value;
    if (current.isNotEmpty && current.last == taskId) return;
    desktopTaskDetailStack.value = <String>[
      ...current,
      taskId,
    ];
    desktopSelectedTaskId.value = taskId;
  }

  /// Pop the top of the desktop detail stack. No-op when the stack has
  /// at most one entry — the base task always stays visible because the
  /// list pane is still on screen.
  void popDesktopTaskDetail() {
    final stack = desktopTaskDetailStack.value;
    if (stack.length <= 1) return;
    final next = stack.sublist(0, stack.length - 1);
    desktopTaskDetailStack.value = next;
    desktopSelectedTaskId.value = next.last;
  }

  /// User-initiated navigation: beams to [path] AND brings its tab to the
  /// front. For navigation originating in a tab that is not the active one,
  /// use [beamWithinTab] instead.
  void beamToNamed(String path, {Object? data}) {
    final normalizedPath = _normalizePath(path);
    setPath(normalizedPath);
    delegateByIndex(index).beamToNamed(normalizedPath, data: data);
  }

  /// Beams [path] inside the tab that OWNS it, without making that tab
  /// active.
  ///
  /// Every tab is mounted at once inside the shell's `IndexedStack`, so a
  /// background tab builds — and can navigate — while the user is somewhere
  /// else entirely. The logbook's newest-entry auto-selection is the case
  /// that matters: routing it through [beamToNamed] made merely crossing the
  /// desktop breakpoint yank the user onto the Logbook tab.
  ///
  /// The route is still recorded and persisted, so returning to that tab —
  /// or restarting the app — lands on it.
  void beamWithinTab(String path, {Object? data}) {
    final spec = _specForAnyPath(path);
    if (spec == null) return;
    _routesByTab[spec.rootPath] = path;
    if (spec.rootPath == _activeRootPath) {
      currentPath = path;
    }
    spec.delegate.beamToNamed(path, data: data);
    unawaited(_persistState());
  }

  /// The route the given tab currently stands at, or its root when it has
  /// never been navigated deeper.
  String routeForTab(String rootPath) => _routesByTab[rootPath] ?? rootPath;

  /// Records [route] as its tab's current position and persists the state.
  ///
  /// For callers that beam a delegate themselves (the agent helpers) and need
  /// the service's view of where that tab stands to keep up.
  Future<void> persistNamedRoute(String route) async {
    final spec = _specForAnyPath(route);
    if (spec != null) {
      _routesByTab[spec.rootPath] = route;
    }
    currentPath = route;
    await _persistState();
  }

  /// The active tab's route as persisted by the previous session.
  Future<String?> getSavedRoute() async {
    final snapshot =
        NavStateSnapshot.decode(await _settingsDb.itemByKey(navStateKey)) ??
        await _legacySnapshot();
    return snapshot?.activeRoute;
  }

  void beamBack({Object? data}) {
    delegateByIndex(index).beamBack(data: data);
  }

  Future<void> dispose() async {
    _disposed = true;
    desktopTaskDetailStack.dispose();
    desktopSelectedTaskId.dispose();
    desktopSelectedProjectId.dispose();
    desktopSelectedDashboardId.dispose();
    desktopSelectedEntryId.dispose();
    desktopShowTimeAnalysis.dispose();
    desktopShowAiImpact.dispose();
    desktopSelectedSettingsRoute.dispose();
    await _navigationFlagsSub.cancel();
    await indexStreamController.close();
  }
}

/// The linked-entity id a global create command should attach to for
/// [route], or null for an unlinked start.
///
/// Goals routes carry an agent id, so no journal parent exists there. People
/// routes carry a relationship id, but global create commands write a plain
/// `BasicLink` while relationships use `RelationshipLink`. Both surfaces
/// therefore start global creation unlinked.
@visibleForTesting
String? creationContextIdForRoute(String? route) {
  if (route == null) return null;
  if (route.startsWith('/goals') || route.startsWith('/people')) return null;
  final regExp = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );
  return regExp.firstMatch(route)?.group(0);
}

Future<String?> getIdFromSavedRoute() async {
  // The ACTIVE tab's live location, not the persisted route: tab taps change
  // only the index, so the persisted route can still point at an entity on a
  // tab the user already left — and a global create command would silently
  // link the new entry to it. The persisted route stays as the fallback for
  // the window before the delegate list is available.
  final navService = getIt<NavService>();
  final delegates = navService.beamerDelegates;
  String? route;
  if (navService.index >= 0 && navService.index < delegates.length) {
    route = delegates[navService.index].configuration.uri.path;
  }
  route ??= await navService.getSavedRoute();
  return creationContextIdForRoute(route);
}

// Global override for testing
// Assigned throughout widget tests outside DCM's `lib`-only usage graph.
// ignore: unused-code
void Function(String)? beamToNamedOverride;

void beamToNamed(String path, {Object? data}) {
  if (beamToNamedOverride != null) {
    beamToNamedOverride!(path);
    return;
  }
  getIt<NavService>().beamToNamed(path, data: data);
}
