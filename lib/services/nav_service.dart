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
    String? route = await SecureStorage.readValue(lastRouteKey);
    if (route != null) {
      Timer(const Duration(milliseconds: 100), () {
        getIt<AppRouter>().pushNamed(route);
        debugPrint('restoreRoute: $route');
      });
    }
  }
}

void pushNamedRoute(String route) {
  debugPrint('pushNamedRoute: $route');
  SecureStorage.writeValue(lastRouteKey, route);
  getIt<AppRouter>().pushNamed(route);
}
