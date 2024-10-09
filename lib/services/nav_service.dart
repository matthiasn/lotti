import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/cupertino.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/get_it.dart';

const String lastRouteKey = 'NAV_LAST_ROUTE';

const tasksIndex = 0;
const calendarIndex = 1;
const habitsIndex = 2;
const dashboardsIndex = 3;
const journalIndex = 4;
const settingsIndex = 5;

class NavService {
  NavService() {
    // TODO: fix and bring back
    // restoreRoute();
  }

  String currentPath = '/habits';
  final indexStreamController = StreamController<int>.broadcast();

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

  BeamerDelegate delegateByIndex(int index) {
    final beamerDelegates = <BeamerDelegate>[
      tasksDelegate,
      calendarDelegate,
      habitsDelegate,
      dashboardsDelegate,
      journalDelegate,
      settingsDelegate,
    ];

    return beamerDelegates[index];
  }

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

  bool isTasksTabActive() {
    return index == 3;
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

  void beamBack({Object? data}) {
    delegateByIndex(index).beamBack(data: data);
  }
}

Future<String?> getSavedRoute() async {
  return getIt<SettingsDb>().itemByKey(lastRouteKey);
}

Future<String?> getIdFromSavedRoute() async {
  final regExp = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );
  final route = await getSavedRoute();
  return regExp.firstMatch('$route')?.group(0);
}

Future<void> persistNamedRoute(String route) async {
  await getIt<SettingsDb>().saveSettingsItem(lastRouteKey, route);
  getIt<NavService>().currentPath = route;
}

void beamToNamed(String path, {Object? data}) {
  debugPrint('beamToNamed $path');
  getIt<NavService>().beamToNamed(path, data: data);
}
