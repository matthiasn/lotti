import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/sync/secure_storage.dart';

const String lastRouteKey = 'LAST_ROUTE_KEY';

class NavService {
  NavService() {
    restoreRoute();
  }

  void restoreRoute() async {
    String? route = await getSavedRoute();
    if (route != null) {
      Timer(const Duration(milliseconds: 100), () {
        getIt<AppRouter>().pushNamed(route);
        debugPrint('restoreRoute: $route');
      });
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
}

void pushNamedRoute(String route) {
  debugPrint('pushNamedRoute: $route');
  persistNamedRoute(route);
  getIt<AppRouter>().pushNamed(route);
}
