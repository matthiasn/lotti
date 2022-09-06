import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:lotti/beamer/beamer_delegates.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/secure_storage.dart';

const String lastRouteKey = 'LAST_ROUTE_KEY';

class NavService {
  NavService() {
    // TODO: fix and bring back
    // restoreRoute();
  }

  String currentPath = '/dashboards';
  final indexStreamController = StreamController<int>.broadcast();

  int index = 0;
  final BeamerDelegate dashboardsDelegate = dashboardsBeamerDelegate;
  final BeamerDelegate journalDelegate = journalBeamerDelegate;
  final BeamerDelegate tasksDelegate = tasksBeamerDelegate;
  final BeamerDelegate settingsDelegate = settingsBeamerDelegate;

  Future<void> restoreRoute() async {
    final path = await getSavedRoute();
    if (path != null) {
      beamToNamed(path);
    }
  }

  void emitState() {
    indexStreamController.add(index);
  }

  void setPath(String path) {
    currentPath = path;

    if (path.startsWith('/dashboards')) {
      setIndex(0);
    }
    if (path.startsWith('/journal')) {
      setIndex(1);
    }
    if (path.startsWith('/tasks')) {
      setIndex(2);
    }
    if (path.startsWith('/settings')) {
      setIndex(3);
    }

    emitState();
  }

  BeamerDelegate delegateByIndex(int index) {
    final beamerDelegates = <BeamerDelegate>[
      dashboardsDelegate,
      journalDelegate,
      tasksBeamerDelegate,
      settingsBeamerDelegate,
    ];

    return beamerDelegates[index];
  }

  void setTabRoot(int newIndex) {
    if (index == 0) {
      beamToNamed('/dashboards');
    }
    if (index == 1) {
      beamToNamed('/journal');
    }
    if (index == 2) {
      beamToNamed('/tasks');
    }
    if (index == 3) {
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

  void beamToNamed(String path) {
    setPath(path);
    persistNamedRoute(path);
    delegateByIndex(index).beamToNamed(path);
  }
}

Future<String?> getSavedRoute() async {
  return await getIt<SecureStorage>().readValue(lastRouteKey);
}

Future<String?> getIdFromSavedRoute() async {
  final regExp = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );
  final route = await getSavedRoute();
  return regExp.firstMatch('$route')?.group(0);
}

void persistNamedRoute(String route) {
  getIt<SecureStorage>().writeValue(lastRouteKey, route);
  getIt<NavService>().currentPath = route;
}

void beamToNamed(String path) {
  getIt<NavService>().beamToNamed(path);
}
