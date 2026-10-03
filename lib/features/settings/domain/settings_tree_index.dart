import 'package:flutter/foundation.dart';
import 'package:lotti/features/settings/domain/settings_node.dart';

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
  /// the last occurrence wins. Either way the collision is first printed
  /// via [debugPrint], so the regression is still visible in logs.
  factory SettingsTreeIndex.build(List<SettingsNode> tree) {
    final byId = <String, SettingsNode>{};
    final ancestors = <String, List<String>>{};
    void walk(List<SettingsNode> nodes, List<String> parents) {
      for (final node in nodes) {
        if (byId.containsKey(node.id)) {
          final message =
              'Duplicate SettingsNode id "${node.id}" at depth '
              '${parents.length}. Node ids must be unique across the tree.';
          debugPrint(message);
          assert(false, message);
        }
        final trail = List<String>.unmodifiable([...parents, node.id]);
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

  /// Flat id → unmodifiable list of ancestor ids (inclusive of the
  /// node itself), ordered root → self. Equivalent to the tree path
  /// that, when opened, ends on this node. Pre-wrapped as unmodifiable
  /// at build time so callers don't allocate a fresh view on every
  /// read.
  final Map<String, List<String>> _ancestors;

  /// Returns the node for [id], or `null` when it isn't present in
  /// the current (flag-gated) tree.
  SettingsNode? findById(String id) => _byId[id];

  /// Root → node ancestor chain (inclusive) for [id]. Returns `null`
  /// when the node isn't in the current tree. Use this for
  /// breadcrumbs and to seed the tree path from a deep link.
  ///
  /// The returned list is the pre-wrapped unmodifiable view stored on
  /// this index — safe to retain without copying.
  List<String>? ancestors(String id) => _ancestors[id];
}
