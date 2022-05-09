import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/services/nav_service.dart';

class NavObserver extends AutoRouterObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    super.didPush(route, previousRoute);
    debugPrint('New route pushed: ${route.settings}');
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    super.didPop(route, previousRoute);
    debugPrint('Route popped: ${route.settings}');
  }

  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) {
    persistNamedRoute('/${route.path}');
  }
}
