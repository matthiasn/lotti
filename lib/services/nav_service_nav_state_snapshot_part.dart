part of 'nav_service.dart';

/// Legacy settings key: a single route string, the active tab's path.
/// Still READ once at restore as a migration fallback for [navStateKey]'s
/// `active` field, never written any more.
const String lastRouteKey = 'NAV_LAST_ROUTE';

/// Settings key holding the whole navigation state as JSON — the active tab
/// and every tab's own route. See [NavStateSnapshot].
const String navStateKey = 'NAV_STATE';

/// The persisted navigation state: which tab was active and where each tab
/// stood within its own Beamer stack.
///
/// The active tab is stored as its ROOT PATH rather than as an index, because
/// indices shift whenever a feature flag toggles a tab in or out — a stored
/// `3` means a different tab after the flag streams emit, a stored `/goals`
/// does not.
@immutable
class NavStateSnapshot {
  const NavStateSnapshot({required this.activeRootPath, required this.routes});

  /// Parses [json], returning null for anything malformed or of an unknown
  /// version. A corrupt row must degrade to "no saved state" (land on Tasks),
  /// never throw during bootstrap.
  static NavStateSnapshot? decode(String? json) {
    if (json == null || json.isEmpty) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['v'] != _version) return null;
      final active = decoded['active'];
      if (active is! String || active.isEmpty) return null;
      final rawRoutes = decoded['routes'];
      final routes = <String, String>{};
      if (rawRoutes is Map) {
        for (final entry in rawRoutes.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is String && value.isNotEmpty) {
            routes[key] = value;
          }
        }
      }
      return NavStateSnapshot(activeRootPath: active, routes: routes);
    } on FormatException {
      return null;
    }
  }

  static const int _version = 1;

  /// Root path of the tab that was active, e.g. `/tasks`.
  final String activeRootPath;

  /// Root path -> the route that tab stood at, e.g. `/tasks` -> `/tasks/<id>`.
  final Map<String, String> routes;

  String encode() => jsonEncode({
    'v': _version,
    'active': activeRootPath,
    'routes': routes,
  });

  /// The active tab's own route — what a caller asking "where is the user?"
  /// wants, falling back to the tab root when that tab has no deeper route.
  String get activeRoute => routes[activeRootPath] ?? activeRootPath;
}

/// Lightweight snapshot of the current settings route for the desktop
/// split-pane view.
typedef DesktopSettingsRoute = ({
  String path,
  Map<String, String> pathParameters,
  Map<String, String> queryParameters,
});

/// The linked-entity id a global create command should attach to for
/// [route], or null for an unlinked start.
///
/// Goals routes carry an agent id, so no journal parent exists there. People
/// routes carry a relationship id, but global create commands write a plain
/// `BasicLink` while relationships use `RelationshipLink`. Both surfaces
/// therefore start global creation unlinked.
@visibleForTesting
String? creationContextIdForRoute(String? route) {
  if (route == null) return null;
  if (route.startsWith('/goals') || route.startsWith('/people')) return null;
  final regExp = RegExp(
    '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
    caseSensitive: false,
  );
  return regExp.firstMatch(route)?.group(0);
}

Future<String?> getIdFromSavedRoute() async {
  // The ACTIVE tab's live location, not the persisted route: tab taps change
  // only the index, so the persisted route can still point at an entity on a
  // tab the user already left — and a global create command would silently
  // link the new entry to it. The persisted route stays as the fallback for
  // the window before the delegate list is available.
  final navService = getIt<NavService>();
  final delegates = navService.beamerDelegates;
  String? route;
  if (navService.index >= 0 && navService.index < delegates.length) {
    route = delegates[navService.index].configuration.uri.path;
  }
  route ??= await navService.getSavedRoute();
  return creationContextIdForRoute(route);
}

// Global override for testing
// Assigned throughout widget tests outside DCM's `lib`-only usage graph.
// ignore: unused-code
void Function(String)? beamToNamedOverride;
void beamToNamed(String path, {Object? data}) {
  if (beamToNamedOverride != null) {
    beamToNamedOverride!(path);
    return;
  }
  getIt<NavService>().beamToNamed(path, data: data);
}
