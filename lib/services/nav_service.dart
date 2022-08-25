import 'dart:async';

import 'package:beamer/beamer.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/beamer/beamer_app.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/sync/secure_storage.dart';

const String lastRouteKey = 'LAST_ROUTE_KEY';

class NavService {
  NavService() {
    restoreRoute();
  }

  String currentPath = '/dashboards';
  final indexStreamController = StreamController<int>();

  Future<void> restoreRoute() async {
    final route = await getSavedRoute();

    if (route != null) {
      currentPath = route;
    }

    // if (route != null) {
    //   Timer(const Duration(milliseconds: 1), () {
    //     navigateNamedRoute(route);
    //     debugPrint('restoreRoute: $route');
    //   });
    // }
  }

  int index = 0;
  List<BeamerDelegate> beamerDelegates = [
    dashboardsDelegate,
    journalDelegate,
    tasksDelegate,
    settingsDelegate,
  ];

  void emitState() {}

  void setPath(String path) {
    debugPrint('setPath $path');
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

  void setIndex(int newIndex) {
    index = newIndex;
    beamerDelegates[index].update(rebuild: false);
    indexStreamController.add(index);
    emitState();
  }

  Stream<int> getIndexStream() {
    return indexStreamController.stream;
  }

  void beamToNamed(String path) {
    setPath(path);
    persistNamedRoute(path);
    beamerDelegates[index].beamToNamed(path);
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
  debugPrint('persistNamedRoute: $route');
  getIt<SecureStorage>().writeValue(lastRouteKey, route);
  getIt<NavService>().currentPath = route;
}

// TODO: remove
void navigateNamedRoute(String route) {
  debugPrint('navigateNamedRoute: $route');
  persistNamedRoute(route);
  // getIt<AppRouter>().navigateNamed(
  //   route,
  //   includePrefixMatches: true,
  //   onFailure: (_) => getIt<AppRouter>().navigateNamed('/'),
  // );
}

void beamToNamed(String path) {
  debugPrint('beamToNamed: $path');
  getIt<NavService>().beamToNamed(path);
}
