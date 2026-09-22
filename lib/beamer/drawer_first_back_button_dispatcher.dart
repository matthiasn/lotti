import 'package:beamer/beamer.dart';
import 'package:flutter/foundation.dart';
import 'package:lotti/widgets/nav_bar/mobile_navigation_drawer.dart';

/// The app's root back-button dispatcher: Beamer's own, except that an open
/// mobile navigation drawer takes the press first and closes.
///
/// The drawer cannot catch back from inside the shell. Every tab's nested
/// `Beamer` registers a child dispatcher with this root and takes priority
/// over it, and none of them is ever deactivated, so a press goes to the tabs
/// before the root navigator — including the offstage ones. Any tab with a
/// page to pop or a location to beam back to would take it, changing the
/// page under a drawer that stays open. Checking here, ahead of the children,
/// is the one place that always hears the press first.
class DrawerFirstBackButtonDispatcher extends BeamerBackButtonDispatcher {
  DrawerFirstBackButtonDispatcher({
    required super.delegate,
    required this.drawer,
  });

  final MobileNavigationDrawerController drawer;

  @override
  Future<bool> invokeCallback(Future<bool> defaultValue) {
    if (drawer.isOpen) {
      drawer.close();
      return SynchronousFuture(true);
    }
    return super.invokeCallback(defaultValue);
  }
}
