import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/sync/secure_storage.dart';

const String lastRouteKey = 'LAST_ROUTE_KEY';

class NavService {
  NavService() {
    restoreRoute();
  }

  String? currentRoute;
  TabsRouter? tabsRouter;
  List<String> routesByIndex = [];

  Future<void> restoreRoute() async {
    final route = await getSavedRoute();
    currentRoute = route;

    if (route != null) {
      Timer(const Duration(milliseconds: 1), () {
        getIt<AppRouter>().pushNamed(route);
        debugPrint('restoreRoute: $route');
      });
    }
  }

  void bottomNavRouteTap(int index) {
    final route = routesByIndex[index];
    debugPrint('bottomNavRouteTap: currentRoute $currentRoute route $route');
    if ('$currentRoute'.startsWith(route) && route != currentRoute) {
      tabsRouter?.setActiveIndex(index);
      getIt<AppRouter>().pop();
    }
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
  getIt<NavService>().currentRoute = route;
}

void pushNamedRoute(String route) {
  debugPrint('pushNamedRoute: $route');
  persistNamedRoute(route);
  getIt<AppRouter>().pushNamed(route);
}
