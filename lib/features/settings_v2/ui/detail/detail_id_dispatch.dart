import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/nav_service.dart';

/// Generic list ↔ detail/create dispatcher for V2 panel bodies.
///
/// Listens to [NavService.desktopSelectedSettingsRoute] directly via
/// a [ValueListenableBuilder] (no Riverpod adapter — the underlying
/// `ValueNotifier` already emits on every Beamer-driven route change,
/// and stock Flutter rebuild semantics avoid any "did the provider
/// observe the update" doubt). Chooses between three builders:
///
/// - **create** — when the URL ends with `/create`. Receives the full
///   route so create flows can read query parameters
///   (e.g. labels prefilling the new label's name).
/// - **detail** — when [idParamKey] is present in `pathParameters` and
///   not the literal `'create'` (which Beamer hands back as a path
///   parameter on the matching route definition).
/// - **list** — fallback for the bare branch URL.
///
/// The dispatcher is intentionally local to the registry: keeping it
/// here means the categories / labels / dashboards features stay
/// agnostic of V2 routing, and the registry stays the single place
/// to wire a new list-detail pair. The optional [listenable] hook
/// lets tests drive the dispatch with their own ValueNotifier without
/// having to register a `NavService` in `get_it`.
class DetailIdDispatch extends StatelessWidget {
  const DetailIdDispatch({
    required this.idParamKey,
    required this.list,
    required this.create,
    required this.detail,
    this.listenable,
    super.key,
  });

  /// Key under which the entity id is exposed in the route's
  /// `pathParameters` (e.g. `categoryId`, `habitId`). The same key is
  /// declared on the matching pattern in `settings_location.dart`.
  final String idParamKey;

  /// Builds the list body for the bare branch URL (no id, no
  /// `/create` suffix).
  final Widget Function(BuildContext context) list;

  /// Builds the create body when the URL ends with `/create`. Gets the
  /// full route so it can read query parameters (e.g. a prefilled
  /// label name).
  final Widget Function(BuildContext context, DesktopSettingsRoute? route)
  create;

  /// Builds the detail body when [idParamKey] resolves to a non-empty
  /// id (and not the literal `create`). Receives that id.
  final Widget Function(BuildContext context, String id) detail;

  /// Test-only override for the route source. Production callers leave
  /// this `null` so the dispatcher reads from `getIt<NavService>()`.
  @visibleForTesting
  final ValueListenable<DesktopSettingsRoute?>? listenable;

  @override
  Widget build(BuildContext context) {
    final source =
        listenable ?? getIt<NavService>().desktopSelectedSettingsRoute;
    return ValueListenableBuilder<DesktopSettingsRoute?>(
      valueListenable: source,
      builder: (context, route, _) {
        final params = route?.pathParameters ?? const <String, String>{};
        final path = route?.path ?? '';

        final Widget child;
        final String modeKey;
        if (path.endsWith('/create')) {
          child = create(context, route);
          modeKey = 'create';
        } else {
          final id = params[idParamKey];
          if (id != null && id.isNotEmpty && id != 'create') {
            child = detail(context, id);
            // Key includes the id so swapping between two detail rows
            // (e.g. tapping a different category) cross-fades instead
            // of reusing the previous detail's element.
            modeKey = 'detail:$id';
          } else {
            child = list(context);
            modeKey = 'list';
          }
        }

        return AnimatedSwitcher(
          duration: kSettingsPanelSwapDuration,
          // Default layout uses `StackFit.loose`, which collapses
          // Scaffold-based children to their minimum size and hides
          // their FloatingActionButton — the "+" in the agents tab is
          // the canonical case, but this is a property of every
          // dispatcher consumer (categories, labels, dashboards,
          // measurables, agents). Force `StackFit.expand` so children
          // fill the panel slot — Scaffolds get bounded constraints
          // and lay out their FAB the same way they would unwrapped.
          // The previous children list still cross-fades correctly
          // because `AnimatedSwitcher` paints them above us during
          // the swap.
          layoutBuilder: (currentChild, previousChildren) => Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              ...previousChildren,
              ?currentChild,
            ],
          ),
          transitionBuilder: (current, animation) =>
              FadeTransition(opacity: animation, child: current),
          child: KeyedSubtree(key: ValueKey(modeKey), child: child),
        );
      },
    );
  }
}
