import 'package:lotti/features/settings_v2/domain/settings_node.dart';

/// Static URL mapping for the Settings tree. Split out from the
/// runtime tree so `pathToBeamUrl` / `beamUrlToPath` can be tested
/// independently of `buildSettingsTree` and the feature-flag set.
///
/// Keys are node ids; values are the canonical Beamer paths declared
/// in `lib/beamer/locations/settings_location.dart`. Every route that
/// `SettingsLocation.pathPatterns` exposes as a top-level navigable
/// settings destination must appear here.
///
/// `whats-new` is intentionally absent: it renders as an in-pane
/// panel and does not change the URL.
///
/// The `sync/matrix-maintenance` id intentionally uses a hyphen where
/// its URL uses a slash. The id must be a single tree segment —
/// `sync/matrix/maintenance` would imply a non-existent `sync/matrix`
/// branch via `_idToPath` — but the URL shape is fixed by the Beamer
/// patterns in `settings_location.dart`. Do not "normalize" the
/// hyphen to a slash.
const Map<String, String> settingsNodeUrls = {
  'ai': '/settings/ai',
  'ai/profiles': '/settings/ai/profiles',
  'agents': '/settings/agents',
  'agents/templates': '/settings/agents/templates',
  'agents/souls': '/settings/agents/souls',
  'agents/instances': '/settings/agents/instances',
  'habits': '/settings/habits',
  'categories': '/settings/categories',
  'labels': '/settings/labels',
  'sync': '/settings/sync',
  'sync/backfill': '/settings/sync/backfill',
  'sync/stats': '/settings/sync/stats',
  'sync/outbox': '/settings/sync/outbox',
  'sync/matrix-maintenance': '/settings/sync/matrix/maintenance',
  'dashboards': '/settings/dashboards',
  'measurables': '/settings/measurables',
  'theming': '/settings/theming',
  'flags': '/settings/flags',
  'advanced': '/settings/advanced',
  'advanced/logging': '/settings/advanced/logging_domains',
  'advanced/conflicts': '/settings/advanced/conflicts',
  'advanced/maintenance': '/settings/advanced/maintenance',
  'advanced/about': '/settings/advanced/about',
};

/// [settingsNodeUrls] entries sorted longest-URL-first, computed once
/// at program start so `beamUrlToPath` can resolve greedy longest-
/// prefix matches without re-sorting on every call.
final List<MapEntry<String, String>> _settingsNodeUrlsLongestFirst =
    settingsNodeUrls.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));

/// Root path when nothing is selected.
const String settingsRootUrl = '/settings';

/// Turns a tree path into a Beamer URL. The deepest node in the
/// path wins — any ancestors are implicit in the URL structure.
/// Returns [settingsRootUrl] for an empty path, for unknown ids
/// (e.g. the in-pane `whats-new` leaf), or when the last segment
/// has no URL registered.
String pathToBeamUrl(List<String> path) {
  if (path.isEmpty) return settingsRootUrl;
  return settingsNodeUrls[path.last] ?? settingsRootUrl;
}

/// Turns a Beamer URL into a tree path. Greedy longest-prefix match:
/// any trailing segments beyond the matched node id (e.g. the `:id`
/// of a category detail) are treated as panel-local and ignored,
/// leaving the tree state unchanged.
///
/// Returns `[]` for `/settings`, for URLs outside the settings
/// subtree, and for URLs whose first segment doesn't match any
/// registered node.
List<String> beamUrlToPath(String url) {
  final canonical = _canonicalize(url);
  if (canonical == settingsRootUrl) return const [];
  if (!canonical.startsWith('$settingsRootUrl/')) return const [];

  // Walk candidate urls longest-first so `/settings/advanced/maintenance`
  // wins over `/settings/advanced`, and `/settings/agents/templates`
  // wins over `/settings/agents`.
  for (final entry in _settingsNodeUrlsLongestFirst) {
    final nodeUrl = entry.value;
    if (canonical == nodeUrl || canonical.startsWith('$nodeUrl/')) {
      return _idToPath(entry.key);
    }
  }
  return const [];
}

String _canonicalize(String url) {
  if (url.length > 1 && url.endsWith('/')) {
    return url.substring(0, url.length - 1);
  }
  return url;
}

/// Converts a node id like `sync/backfill` into its ancestor chain
/// `['sync', 'sync/backfill']`. Ids use slash-delimited path
/// segments (see spec §3).
List<String> _idToPath(String id) {
  final segments = id.split('/');
  final result = <String>[];
  final buffer = StringBuffer();
  for (var i = 0; i < segments.length; i++) {
    if (i > 0) buffer.write('/');
    buffer.write(segments[i]);
    result.add(buffer.toString());
  }
  return result;
}

/// O(1) lookup over a (flag-gated) settings tree.
///
/// Pre-computed on tree change — the provider in the plan §1 rebuilds
/// this whenever the flag set changes. Absent nodes (e.g. `sync` when
/// Matrix is off) resolve to `null` so the UI can gracefully fall
/// back to the empty root.
class SettingsTreeIndex {
  /// Builds an index over the given `tree`. Duplicate ids at any
  /// depth are an authoring bug: tree data is static, so a collision
  /// means two nodes share a slot by mistake. In debug builds an
  /// assertion fires to surface this during development; in release
  /// the last occurrence wins (same as the pre-assert behavior).
  factory SettingsTreeIndex.build(List<SettingsNode> tree) {
    final byId = <String, SettingsNode>{};
    final ancestors = <String, List<String>>{};
    void walk(List<SettingsNode> nodes, List<String> parents) {
      for (final node in nodes) {
        assert(
          !byId.containsKey(node.id),
          'Duplicate SettingsNode id "${node.id}" at depth '
          '${parents.length}. Node ids must be unique across the tree.',
        );
        final trail = [...parents, node.id];
        byId[node.id] = node;
        ancestors[node.id] = trail;
        final children = node.children;
        if (children != null) {
          walk(children, trail);
        }
      }
    }

    walk(tree, const []);
    return SettingsTreeIndex._(byId, ancestors);
  }

  SettingsTreeIndex._(this._byId, this._ancestors);

  /// Flat id → node map across every depth of the source tree.
  final Map<String, SettingsNode> _byId;

  /// Flat id → list of ancestor ids (inclusive of the node itself),
  /// ordered root → self. Equivalent to the tree path that, when
  /// opened, ends on this node.
  final Map<String, List<String>> _ancestors;

  /// Returns the node for [id], or `null` when it isn't present in
  /// the current (flag-gated) tree.
  SettingsNode? findById(String id) => _byId[id];

  /// Root → node ancestor chain (inclusive) for [id]. Returns `null`
  /// when the node isn't in the current tree. Use this for
  /// breadcrumbs and to seed the tree path from a deep link.
  List<String>? ancestors(String id) {
    final list = _ancestors[id];
    return list == null ? null : List<String>.unmodifiable(list);
  }

  /// `true` if [path] is safe to install as tree state — i.e. every
  /// id resolves AND the ids form the canonical root → self chain
  /// of the last segment. A path like `['sync/backfill']` (missing
  /// the `sync` ancestor) or `['advanced', 'sync/backfill']` (wrong
  /// parent) is rejected, so callers can use this as a guard
  /// without worrying about dangling selections.
  bool isValidPath(List<String> path) {
    if (path.isEmpty) return true;
    final expected = _ancestors[path.last];
    if (expected == null || expected.length != path.length) return false;
    for (var i = 0; i < path.length; i++) {
      if (expected[i] != path[i]) return false;
    }
    return true;
  }
}
