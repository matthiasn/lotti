import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/dev_logger.dart';
import 'package:lotti/utils/consts.dart';
import 'package:rxdart/rxdart.dart';

const String lastRouteKey = 'NAV_LAST_ROUTE';

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

    // TODO: fix and bring back
    // restoreRoute();

    _navigationFlagsSub =
        Rx.combineLatest4<
              bool,
              bool,
              bool,
              bool,
              ({bool habits, bool dashboards, bool dailyOs, bool projects})
            >(
              _journalDb.watchConfigFlag(enableHabitsPageFlag),
              _journalDb.watchConfigFlag(enableDashboardsPageFlag),
              _journalDb.watchConfigFlag(enableDailyOsPageFlag),
              _journalDb.watchConfigFlag(enableProjectsFlag),
              (habits, dashboards, dailyOs, projects) => (
                habits: habits,
                dashboards: dashboards,
                dailyOs: dailyOs,
                projects: projects,
              ),
            )
            .listen(_handleNavigationFlagsUpdated);
  }

  late final JournalDb _journalDb;
  late final SettingsDb _settingsDb;
  late final StreamSubscription<
    ({bool habits, bool dashboards, bool dailyOs, bool projects})
  >
  _navigationFlagsSub;

  /// Whether the app is currently in desktop layout mode (sidebar visible).
  /// Set by `AppScreen` based on the current window width.
  bool isDesktopMode = false;

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

  /// Tracks the current settings sub-route on desktop so the right pane
  /// can render the matching content page.
  final ValueNotifier<DesktopSettingsRoute?> desktopSelectedSettingsRoute =
      ValueNotifier<DesktopSettingsRoute?>(null);

  bool _isHabitsPageEnabled = false;
  bool _isDashboardsPageEnabled = false;
  bool _isDailyOsPageEnabled = false;
  bool _isProjectsPageEnabled = false;

  String currentPath = '/tasks';
  final indexStreamController = StreamController<int>.broadcast();

  final tasksIndex = 0;
  // final calendarIndex = 1;
  // final habitsIndex = 2;
  // final dashboardsIndex = 3;
  // final journalIndex = 4;
  // final settingsIndex = 5;

  int index = 0;

  final BeamerDelegate habitsDelegate = habitsBeamerDelegate;
  final BeamerDelegate dashboardsDelegate = dashboardsBeamerDelegate;
  final BeamerDelegate journalDelegate = journalBeamerDelegate;
  final BeamerDelegate projectsDelegate = projectsBeamerDelegate;
  final BeamerDelegate tasksDelegate = tasksBeamerDelegate;
  final BeamerDelegate calendarDelegate = calendarBeamerDelegate;
  final BeamerDelegate settingsDelegate = settingsBeamerDelegate;

  bool get isHabitsPageEnabled => _isHabitsPageEnabled;
  bool get isDashboardsPageEnabled => _isDashboardsPageEnabled;
  bool get isDailyOsPageEnabled => _isDailyOsPageEnabled;
  bool get isProjectsPageEnabled => _isProjectsPageEnabled;

  List<BeamerDelegate>? _cachedBeamerDelegates;

  Iterable<({bool enabled, String rootPath, BeamerDelegate delegate})>
  get _tabSpecs sync* {
    yield (enabled: true, rootPath: '/tasks', delegate: tasksDelegate);
    yield (
      enabled: _isProjectsPageEnabled,
      rootPath: '/projects',
      delegate: projectsDelegate,
    );
    yield (
      enabled: _isDailyOsPageEnabled,
      rootPath: '/calendar',
      delegate: calendarDelegate,
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
    yield (enabled: true, rootPath: '/journal', delegate: journalDelegate);
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

  String _normalizePath(String path) {
    return _specForPath(path) == null ? _enabledTabSpecs.first.rootPath : path;
  }

  void _setIndexInternal(int newIndex, {bool emit = true}) {
    index = newIndex;
    delegateByIndex(index).update(rebuild: false);
    if (emit) {
      emitState();
    }
  }

  void _handleNavigationFlagsUpdated(
    ({bool habits, bool dashboards, bool dailyOs, bool projects}) flags,
  ) {
    _isHabitsPageEnabled = flags.habits;
    _isDashboardsPageEnabled = flags.dashboards;
    _isDailyOsPageEnabled = flags.dailyOs;
    _isProjectsPageEnabled = flags.projects;
    _cachedBeamerDelegates = null;

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

  Future<void> restoreRoute() async {
    final path = await getSavedRoute();
    DevLogger.log(name: 'NavService', message: 'restoreRoute $path');
    if (path != null) {
      beamToNamed(path);
    }
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
    _setIndexInternal(beamerDelegates.indexOf(matchingSpec.delegate));
  }

  List<BeamerDelegate> get beamerDelegates => _cachedBeamerDelegates ??=
      _enabledTabSpecs.map((spec) => spec.delegate).toList(growable: false);

  BeamerDelegate delegateByIndex(int index) {
    return beamerDelegates[index];
  }

  int get calendarIndex => beamerDelegates.indexOf(calendarDelegate);
  int get habitsIndex => beamerDelegates.indexOf(habitsDelegate);
  int get dashboardsIndex => beamerDelegates.indexOf(dashboardsDelegate);
  int get projectsIndex => beamerDelegates.indexOf(projectsDelegate);
  int get journalIndex => beamerDelegates.indexOf(journalDelegate);
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
    desktopTaskDetailStack.value = <String>[
      ...desktopTaskDetailStack.value,
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

  void beamToNamed(String path, {Object? data}) {
    final normalizedPath = _normalizePath(path);
    setPath(normalizedPath);
    unawaited(persistNamedRoute(normalizedPath));
    delegateByIndex(index).beamToNamed(normalizedPath, data: data);
  }

  Future<void> persistNamedRoute(String route) async {
    await _settingsDb.saveSettingsItem(lastRouteKey, route);
    currentPath = route;
  }

  Future<String?> getSavedRoute() async {
    return _settingsDb.itemByKey(lastRouteKey);
  }

  void beamBack({Object? data}) {
    delegateByIndex(index).beamBack(data: data);
  }

  Future<void> dispose() async {
    desktopTaskDetailStack.dispose();
    desktopSelectedTaskId.dispose();
    desktopSelectedProjectId.dispose();
    desktopSelectedDashboardId.dispose();
    desktopSelectedSettingsRoute.dispose();
    await _navigationFlagsSub.cancel();
    await indexStreamController.close();
  }
}

Future<String?> getIdFromSavedRoute() async {
  final regExp = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );
  final route = await getIt<NavService>().getSavedRoute();
  return regExp.firstMatch('$route')?.group(0);
}

// Global override for testing
void Function(String)? beamToNamedOverride;

void beamToNamed(String path, {Object? data}) {
  if (beamToNamedOverride != null) {
    beamToNamedOverride!(path);
    return;
  }
  getIt<NavService>().beamToNamed(path, data: data);
}
