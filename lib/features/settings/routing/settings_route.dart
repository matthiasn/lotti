import 'package:flutter/widgets.dart';
import 'package:lotti/utils/settings_urls.dart';

/// Builds a settings page or panel body for a resolved URL.
typedef SettingsRouteBuilder =
    Widget Function(BuildContext context, SettingsRouteMatch match);

/// Everything one settings tree node needs to be reachable, declared once.
///
/// An entry is keyed by its tree node id in `settingsRoutes`. From the same
/// entry the mobile page stack, each page's pop target, the desktop detail
/// panel, the deep-link patterns and the bottom-nav rule are derived — so
/// adding a settings page is the tree node, its label and this one entry.
@immutable
class SettingsRoute {
  const SettingsRoute({
    this.url,
    this.page,
    this.panel,
    this.scrollable = false,
    this.subRoutes = const [],
    this.keepsBottomNav = false,
  });

  /// Canonical URL. Null for nodes that are not navigable on their own: the
  /// explainer tile shown in place of Sync in demo worlds.
  ///
  /// A node's URL does not have to nest under its parent's: leaves that
  /// changed branch keep the URL they shipped with, so a deep link never
  /// breaks because the menu was regrouped.
  final String? url;

  /// The mobile page this node contributes to the drill-down stack. Null when
  /// the node adds no page of its own — the Agents and AI tabs, which their
  /// section's page already shows.
  final SettingsRouteBuilder? page;

  /// The headerless desktop body shown in the detail pane beside the tree.
  /// The breadcrumb above the pane names it, so the body carries no title.
  /// Null when the node has no desktop panel: a branch without a landing
  /// panel shows the "pick a section" hint instead, and a leaf without one is
  /// inert in the tree.
  final SettingsRouteBuilder? panel;

  /// Whether the desktop host wraps [panel] in a `SingleChildScrollView`.
  /// Flat `Column` bodies need it; a body with its own `ListView`,
  /// `CustomScrollView` or `Scaffold` must leave it `false`, or the inner
  /// viewport receives unbounded height and fails at layout.
  final bool scrollable;

  /// Detail surfaces reached below [url] — editors, create flows, reviews.
  /// Each one is the same widget on both platforms: a page stacked above
  /// this node's page on mobile, and the content of this node's panel slot
  /// on desktop.
  final List<SettingsSubRoute> subRoutes;

  /// Whether the mobile bottom navigation stays visible while this node's
  /// page is on top. Menus and browse lists keep it; terminal destinations
  /// hand the whole bottom edge to the page.
  final bool keepsBottomNav;
}

/// A URL below a [SettingsRoute] that opens a detail surface.
@immutable
class SettingsSubRoute {
  const SettingsSubRoute(
    this.pattern, {
    required this.build,
    this.panel,
    this.replacesParent = false,
    this.keepsBottomNav = false,
  });

  /// The full URL pattern, for example `/settings/categories/:categoryId`.
  /// Written out in full rather than relative to the parent so every
  /// deep-linkable settings URL appears verbatim in the registry — the
  /// manual's route inventory is checked against these literals.
  ///
  /// A `:name` segment captures a path parameter. It never captures the
  /// literal `create`, which is reserved for create flows: a stray
  /// `…/create` under a route that has none falls back to the parent
  /// instead of opening an editor for an entity called "create".
  final String pattern;

  /// The detail surface, used on both platforms.
  final SettingsRouteBuilder build;

  /// Desktop override for [build], for the rare sub-route whose mobile page
  /// would carry a header the desktop breadcrumb already supplies.
  final SettingsRouteBuilder? panel;

  /// When true the mobile page takes the place of its parent's page in the
  /// stack instead of stacking above it. For a filtered variant of a list,
  /// so leaving it returns to wherever the list itself returns.
  final bool replacesParent;

  /// See [SettingsRoute.keepsBottomNav].
  final bool keepsBottomNav;
}

/// One page of the resolved mobile stack.
@immutable
class SettingsStackEntry {
  const SettingsStackEntry({
    required this.key,
    required this.url,
    required this.popUrl,
    required this.build,
    required this.keepsBottomNav,
  });

  /// Stable page key. A page keeps its key at every URL that shows it, which
  /// is what lets a back gesture uncover it instead of swapping it out.
  final String key;

  /// The URL this page stands for.
  final String url;

  /// Where a back gesture on this page goes: the URL of the page beneath it.
  ///
  /// Always explicit. Beamer's default pop strips one URL segment, which is
  /// only right when a page's URL nests directly under the one below — and
  /// most settings URLs do not (flat definition URLs under a hub at
  /// `/settings/definitions`, a three-segment Sync leaf, two-segment detail
  /// routes). Each of those once sent the back gesture to a URL that rebuilt
  /// the page being left.
  final String popUrl;

  final SettingsRouteBuilder build;
  final bool keepsBottomNav;
}

/// A settings URL resolved against the registry.
@immutable
class SettingsRouteMatch {
  const SettingsRouteMatch({
    required this.nodePath,
    required this.stack,
    required this.subRoute,
    required this.pathParameters,
    required this.queryParameters,
  });

  /// Tree path of the deepest node the URL belongs to, root → node. Empty for
  /// the Settings root and for URLs no node claims.
  final List<String> nodePath;

  /// The mobile page stack, root first.
  final List<SettingsStackEntry> stack;

  /// The deepest sub-route the URL opened, or null when it shows the node
  /// itself.
  final SettingsSubRoute? subRoute;

  /// Parameters captured by the matched sub-routes.
  final Map<String, String> pathParameters;

  final Map<String, String> queryParameters;

  /// Whether the mobile bottom navigation stays visible.
  bool get keepsBottomNav => stack.last.keepsBottomNav;
}

/// Resolves settings URLs against a registry of [SettingsRoute]s.
///
/// Pure: it builds no widgets, so the whole URL → stack mapping can be tested
/// without pumping a page.
class SettingsRouteTable {
  SettingsRouteTable({
    required this.routes,
    required this.root,
    this.aliases = const {},
  }) : assert(root.page != null, 'The root route must build the landing'),
       _byUrlLongestFirst = [
         for (final MapEntry(:key, :value) in routes.entries)
           if (value.url != null) (id: key, url: value.url!),
       ]..sort((a, b) => b.url.length.compareTo(a.url.length)),
       nodeUrls = {
         for (final MapEntry(:key, :value) in routes.entries)
           if (value.url != null) key: value.url!,
       };

  /// Node id → route.
  final Map<String, SettingsRoute> routes;

  /// The Settings landing: its [SettingsRoute.page] is the bottom of every
  /// mobile stack, and its sub-routes are detail pages that belong to no tree
  /// node (a project opened from a category).
  final SettingsRoute root;

  /// Retired URLs that still resolve, mapped to their canonical URL.
  final Map<String, String> aliases;

  /// Node id → canonical URL, for every node that has one.
  final Map<String, String> nodeUrls;

  final List<({String id, String url})> _byUrlLongestFirst;

  /// Every URL pattern the registry answers on, root first.
  List<String> get patterns => [
    settingsRootUrl,
    ...root.subRoutes.map((s) => s.pattern),
    for (final route in routes.values) ...[
      ?route.url,
      ...route.subRoutes.map((s) => s.pattern),
    ],
    ...aliases.keys,
  ];

  /// The canonical URL for a tree path: the deepest node's URL. Falls back to
  /// the Settings root for an empty path or a node without a URL.
  String urlForPath(List<String> path) {
    if (path.isEmpty) return settingsRootUrl;
    return nodeUrls[path.last] ?? settingsRootUrl;
  }

  /// The tree path a URL belongs to. A greedy longest-prefix walk over node
  /// URLs rather than a parse of the URL's shape: a node's URL need not mirror
  /// its place in the tree, and trailing segments past the node (a detail id,
  /// `/create`) are panel-local and leave the tree path unchanged.
  List<String> pathForUrl(String url) {
    final path = _canonical(url);
    if (path == settingsRootUrl || !path.startsWith('$settingsRootUrl/')) {
      return const [];
    }
    for (final (:id, url: nodeUrl) in _byUrlLongestFirst) {
      if (path == nodeUrl || path.startsWith('$nodeUrl/')) {
        return _idToPath(id);
      }
    }
    return const [];
  }

  /// Resolves [uri] to its mobile page stack, matched sub-route and captured
  /// parameters.
  SettingsRouteMatch resolve(Uri uri) {
    final path = _canonical(uri.path);
    final nodePath = pathForUrl(path);
    final query = uri.queryParameters;
    final stack = <SettingsStackEntry>[
      SettingsStackEntry(
        key: 'settings',
        url: settingsRootUrl,
        popUrl: settingsRootUrl,
        build: root.page!,
        keepsBottomNav: root.keepsBottomNav,
      ),
    ];

    // Every node on the path whose page shows. A node without a page (an
    // Agents tab) still moves the pop target, so leaving a page above it
    // lands on its URL rather than its parent's.
    var below = settingsRootUrl;
    for (final id in nodePath) {
      final route = routes[id]!;
      final page = route.page;
      final url = route.url ?? below;
      if (page != null) {
        stack.add(
          SettingsStackEntry(
            key: 'settings-$id',
            url: url,
            popUrl: below,
            build: page,
            keepsBottomNav: route.keepsBottomNav,
          ),
        );
      }
      below = url;
    }

    final owner = nodePath.isEmpty ? root : routes[nodePath.last]!;
    final ownerKey = nodePath.isEmpty
        ? 'settings'
        : 'settings-${nodePath.last}';
    final base = _segments(below);
    final rest = _segments(path).skip(base.length).toList();

    // The deepest sub-route the URL reaches: the longest prefix of the
    // remaining segments that names one. An unknown trailing segment past a
    // detail therefore still shows that detail.
    ({SettingsSubRoute sub, int end})? deepest;
    for (var end = rest.length; end > 0 && deepest == null; end--) {
      final sub = _bestMatch(owner.subRoutes, [...base, ...rest.take(end)]);
      if (sub != null) deepest = (sub: sub, end: end);
    }

    final params = <String, String>{};
    if (deepest != null) {
      // The deepest sub-route stacks above the sub-routes its pattern
      // extends — `…/:templateId/review` above `…/:templateId` — so a back
      // gesture walks back down that chain. A sub-route that merely shares a
      // URL prefix (`…/search/<term>` beside `…/:itemId`) is not a parent.
      final chain = [
        for (final sub in owner.subRoutes)
          if (deepest.sub.pattern.startsWith('${sub.pattern}/')) sub,
        deepest.sub,
      ]..sort((x, y) => x.pattern.length.compareTo(y.pattern.length));
      final queryKey = query.isEmpty
          ? ''
          : '?${Uri(queryParameters: query).query}';
      var popTo = below;
      for (final sub in chain) {
        final end = _segments(sub.pattern).length - base.length;
        final segments = rest.take(end).toList();
        params.addAll(_match(_segments(sub.pattern), [...base, ...segments])!);
        final url = '$below/${segments.join('/')}';
        var popUrl = popTo;
        if (sub.replacesParent && stack.length > 1) {
          popUrl = stack.removeLast().popUrl;
        }
        popTo = url;
        stack.add(
          SettingsStackEntry(
            key: '$ownerKey:${segments.join('/')}$queryKey',
            url: url,
            popUrl: popUrl,
            build: sub.build,
            keepsBottomNav: sub.keepsBottomNav,
          ),
        );
      }
    }

    return SettingsRouteMatch(
      nodePath: nodePath,
      stack: stack,
      subRoute: deepest?.sub,
      pathParameters: params,
      queryParameters: query,
    );
  }

  String _canonical(String url) {
    var path = Uri.tryParse(url)?.path ?? url;
    if (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    return aliases[path] ?? path;
  }
}

List<String> _segments(String path) =>
    path.split('/').where((s) => s.isNotEmpty).toList();

/// The sub-route whose pattern fits [segments] exactly. When several do,
/// the one with the most literal segments wins, so `…/create` and
/// `…/search/<term>` are never read as an id.
SettingsSubRoute? _bestMatch(
  List<SettingsSubRoute> candidates,
  List<String> segments,
) {
  SettingsSubRoute? best;
  var bestLiterals = -1;
  for (final sub in candidates) {
    final pattern = _segments(sub.pattern);
    if (_match(pattern, segments) == null) continue;
    final literals = pattern.where((p) => !p.startsWith(':')).length;
    if (literals > bestLiterals) {
      best = sub;
      bestLiterals = literals;
    }
  }
  return best;
}

/// Captured parameters when [segments] fit [pattern] exactly, else null.
Map<String, String>? _match(List<String> pattern, List<String> segments) {
  if (pattern.length != segments.length) return null;
  final captured = <String, String>{};
  for (var i = 0; i < pattern.length; i++) {
    final want = pattern[i];
    final got = segments[i];
    if (want.startsWith(':')) {
      if (got == 'create') return null;
      captured[want.substring(1)] = got;
    } else if (want != got) {
      return null;
    }
  }
  return captured;
}

/// `sync/backfill` → `['sync', 'sync/backfill']`: every ancestor id of a
/// node, root first. Node ids are slash-delimited tree paths, which is why an
/// id must stay one segment per tree level — `sync/matrix-maintenance`, not
/// `sync/matrix/maintenance`, which would name a `sync/matrix` parent that
/// does not exist.
List<String> _idToPath(String id) {
  final segments = id.split('/');
  return [
    for (var i = 1; i <= segments.length; i++) segments.sublist(0, i).join('/'),
  ];
}
