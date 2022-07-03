import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/services/nav_service.dart';

class NavObserver extends AutoRouterObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    debugPrint(
      'New route pushed: ${route.settings} previous: ${previousRoute?.settings}',
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    debugPrint('Route popped: ${route.settings}');
  }

  @override
  void didChangeTabRoute(TabPageRoute route, TabPageRoute previousRoute) {
    debugPrint('didChangeTabRoute ${route.path} ${route.index}');
    persistNamedRoute('/${route.path}');
  }
}
