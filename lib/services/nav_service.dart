import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/cupertino.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/utils/consts.dart';

const String lastRouteKey = 'NAV_LAST_ROUTE';

class NavService {
  NavService({
    JournalDb? journalDb,
    SettingsDb? settingsDb,
  }) {
    _journalDb = journalDb ?? getIt<JournalDb>();
    _settingsDb = settingsDb ?? getIt<SettingsDb>();

    // TODO: fix and bring back
    // restoreRoute();

    _journalDb.watchActiveConfigFlagNames().forEach((configFlags) {
      _isHabitsPageEnabled = configFlags.contains(enableHabitsPageFlag);
      _isDashboardsPageEnabled = configFlags.contains(enableDashboardsPageFlag);
      _isCalendarPageEnabled = configFlags.contains(enableCalendarPageFlag);
    });
  }

  late final JournalDb _journalDb;
  late final SettingsDb _settingsDb;

  bool _isHabitsPageEnabled = false;
  bool _isDashboardsPageEnabled = false;
  bool _isCalendarPageEnabled = false;

  String currentPath = '/habits';
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
  final BeamerDelegate tasksDelegate = tasksBeamerDelegate;
  final BeamerDelegate calendarDelegate = calendarBeamerDelegate;
  final BeamerDelegate settingsDelegate = settingsBeamerDelegate;

  Future<void> restoreRoute() async {
    final path = await getSavedRoute();
    debugPrint('restoreRoute $path');
    if (path != null) {
      beamToNamed(path);
    }
  }

  void emitState() {
    indexStreamController.add(index);
  }

  void setPath(String path) {
    currentPath = path;

    if (path.startsWith('/tasks')) {
      setIndex(tasksIndex);
    }
    if (path.startsWith('/calendar')) {
      setIndex(calendarIndex);
    }
    if (path.startsWith('/habits')) {
      setIndex(habitsIndex);
    }
    if (path.startsWith('/dashboards')) {
      setIndex(dashboardsIndex);
    }
    if (path.startsWith('/journal')) {
      setIndex(journalIndex);
    }

    if (path.startsWith('/settings')) {
      setIndex(settingsIndex);
    }

    emitState();
  }

  List<BeamerDelegate> get beamerDelegates => <BeamerDelegate>[
        tasksDelegate,
        if (_isCalendarPageEnabled) calendarDelegate,
        if (_isHabitsPageEnabled) habitsDelegate,
        if (_isDashboardsPageEnabled) dashboardsDelegate,
        journalDelegate,
        settingsDelegate,
      ];

  BeamerDelegate delegateByIndex(int index) {
    return beamerDelegates[index];
  }

  int get calendarIndex => beamerDelegates.indexOf(calendarDelegate);
  int get habitsIndex => beamerDelegates.indexOf(habitsDelegate);
  int get dashboardsIndex => beamerDelegates.indexOf(dashboardsDelegate);
  int get journalIndex => beamerDelegates.indexOf(journalDelegate);
  int get settingsIndex => beamerDelegates.indexOf(settingsDelegate);

  void setTabRoot(int newIndex) {
    if (index == tasksIndex) {
      beamToNamed('/tasks');
    }
    if (index == calendarIndex) {
      beamToNamed('/calendar');
    }
    if (index == habitsIndex) {
      beamToNamed('/habits');
    }
    if (index == dashboardsIndex) {
      beamToNamed('/dashboards');
    }
    if (index == journalIndex) {
      beamToNamed('/journal');
    }
    if (index == settingsIndex) {
      beamToNamed('/settings');
    }
  }

  void setIndex(int newIndex) {
    index = newIndex;
    delegateByIndex(index).update(rebuild: false);
    emitState();
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

  void beamToNamed(String path, {Object? data}) {
    setPath(path);
    persistNamedRoute(path);
    delegateByIndex(index).beamToNamed(path, data: data);
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
}

Future<String?> getIdFromSavedRoute() async {
  final regExp = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );
  final route = await getIt<NavService>().getSavedRoute();
  return regExp.firstMatch('$route')?.group(0);
}

void beamToNamed(String path, {Object? data}) {
  getIt<NavService>().beamToNamed(path, data: data);
}
