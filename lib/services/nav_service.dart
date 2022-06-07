import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/sync/secure_storage.dart';

const String lastRouteKey = 'LAST_ROUTE_KEY';

class NavService {
  String? currentRoute;
  TabsRouter? tabsRouter;
  List<String> routesByIndex = [];

  NavService() {
    restoreRoute();
  }

  void restoreRoute() async {
    String? route = await getSavedRoute();
    currentRoute = route;

    if (route != null) {
      Timer(const Duration(milliseconds: 100), () {
        getIt<AppRouter>().pushNamed(route);
        debugPrint('restoreRoute: $route');
      });
    }
  }

  void bottomNavRouteTap(int index) {
    String route = routesByIndex[index];
    debugPrint('bottomNavRouteTap: currentRoute $currentRoute route $route');
    if ('$currentRoute'.startsWith(route) && route != currentRoute) {
      tabsRouter?.setActiveIndex(index);
      getIt<AppRouter>().pop();
    }
  }
}

Future<String?> getSavedRoute() async {
  return await SecureStorage.readValue(lastRouteKey);
}

Future<String?> getIdFromSavedRoute() async {
  RegExp regExp = RegExp(
    r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
    multiLine: false,
  );
  String? route = await getSavedRoute();
  return regExp.firstMatch('$route')?.group(0);
}

void persistNamedRoute(String route) {
  debugPrint('persistNamedRoute: $route');
  SecureStorage.writeValue(lastRouteKey, route);
  NavService navService = getIt<NavService>();
  navService.currentRoute = route;
}

void pushNamedRoute(String route) {
  debugPrint('pushNamedRoute: $route');
  persistNamedRoute(route);
  getIt<AppRouter>().pushNamed(route);
}
