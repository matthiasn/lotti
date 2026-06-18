import 'package:flutter/widgets.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// The navigator a full-screen settings editor (or chat) should be pushed
/// onto so its sticky bottom action bar — or chat input — clears the mobile
/// bottom navigation bar.
///
/// The mobile shell paints the bottom nav as a floating overlay on top of each
/// tab's page stack (see `beamer_app.dart`, `_buildMobileLayout`). A page
/// pushed onto the nested tab navigator therefore has its bottom bar hidden
/// behind that pill — the form mounts but its Save/Apply action can't be
/// reached. Pushing onto the root navigator lifts the page above the whole
/// shell, including the nav, so the bottom action always clears the edge.
///
/// This is the push-time companion to `settingsRouteHidesBottomNav` in
/// `beamer_app.dart`: pages that are their own beamer routes slide the nav
/// away by route; pages that are *pushed* on top of another settings route
/// keep that route's URL, so they can't be matched by route and escape the
/// nav this way instead.
///
/// On desktop there is no bottom nav (a sidebar drives navigation) and these
/// pages are meant to overlay only their panel, so the nested navigator is
/// returned. Desktop mode is read from the globally-computed
/// [NavService.isDesktopMode] (set by the shell from `isDesktopLayout`) rather
/// than the local `MediaQuery`, so a panel that constrains its width can't be
/// mistaken for a phone. The `isRegistered` guard keeps single-surface widget
/// tests — where no `NavService` is bound — defaulting to the mobile (root)
/// navigator.
NavigatorState bottomNavSafeNavigatorOf(BuildContext context) {
  final isDesktop =
      getIt.isRegistered<NavService>() && getIt<NavService>().isDesktopMode;
  return Navigator.of(context, rootNavigator: !isDesktop);
}
