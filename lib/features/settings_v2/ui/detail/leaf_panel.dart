import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/ui/detail/default_panel.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';

/// Detail-pane wrapper for a selected leaf.
///
/// Responsibilities:
/// - Resolve the panel body by looking the leaf's `panel` id up via
///   [panelSpecFor]; falls back to [DefaultPanel] when the id isn't
///   (yet) registered.
/// - Keep previously-visited leaf bodies mounted via an
///   [IndexedStack] so switching between siblings preserves their
///   internal state (scroll position, filter, in-flight loaders).
///   Without this, the `AnimatedSwitcher` above `SettingsDetailPane`
///   would tear down each body on every leaf change.
///
/// There is no in-pane breadcrumb or page title — the page-level breadcrumb
/// in `SettingsV2Page._SettingsV2Header` is the sole source of "where am I"
/// context. Padding is split by panel kind: `scrollable: true` (Column-based)
/// panels are wrapped in a `SingleChildScrollView` with a consistent `step6`
/// gutter here, so their headings and cards don't bleed against the
/// detail-pane edges. `scrollable: false` list / scaffold panels fill the full
/// width and own their (often responsive) padding, so they are left untouched.
/// See `docs/design/settings/settings_v2_implementation_plan.md` and the
/// related screenshot review for context.
///
/// Ancestor information is still passed in (rather than just the leaf
/// itself) so callers stay consistent with `SettingsTreeIndex.ancestors`
/// and so future adornments — e.g. a per-leaf affordance keyed off
/// the parent branch — can be added without changing the prop shape.
class LeafPanel extends StatefulWidget {
  const LeafPanel({required this.ancestors, super.key});

  /// Root → self ancestor chain (inclusive), as emitted by
  /// `SettingsTreeIndex.ancestors`. Must be non-empty; the last
  /// element is the leaf to render.
  final List<SettingsNode> ancestors;

  @override
  State<LeafPanel> createState() => _LeafPanelState();
}

class _LeafPanelState extends State<LeafPanel> {
  /// Insertion-ordered cache of leaf ids whose body widget has been
  /// built at least once. The matching entry in [_bodies] is the
  /// built widget; the position in this list is the IndexedStack
  /// child index. [_cachedLeaves] holds the [SettingsNode] each cached
  /// body was built from so a stale entry can be detected the next
  /// time the leaf is visited.
  final List<String> _visitedIds = <String>[];
  final Map<String, Widget> _bodies = <String, Widget>{};
  final Map<String, SettingsNode> _cachedLeaves = <String, SettingsNode>{};
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    assert(
      widget.ancestors.isNotEmpty,
      'LeafPanel needs a non-empty ancestor chain',
    );
    _currentIndex = _ensureCached(widget.ancestors.last);
  }

  @override
  void didUpdateWidget(LeafPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      widget.ancestors.isNotEmpty,
      'LeafPanel needs a non-empty ancestor chain',
    );
    _currentIndex = _ensureCached(widget.ancestors.last);
  }

  /// Inserts [leaf] into the cache on first visit and returns its
  /// IndexedStack child index. Idempotent for repeat visits with the
  /// same payload, but rebuilds the cached body when the incoming
  /// [leaf] differs from the [SettingsNode] the slot was originally
  /// built from — covers both the in-place edit case (leaf updates
  /// while it's selected) and the off-screen edit case (a leaf
  /// changes while a sibling is selected, then the user returns).
  /// Called only from [initState] and [didUpdateWidget] so [build]
  /// stays a pure function of state.
  int _ensureCached(SettingsNode leaf) {
    final existing = _visitedIds.indexOf(leaf.id);
    if (existing != -1) {
      if (_cachedLeaves[leaf.id] != leaf) {
        _cachedLeaves[leaf.id] = leaf;
        _bodies[leaf.id] = _buildBody(leaf);
      }
      return existing;
    }
    _visitedIds.add(leaf.id);
    _cachedLeaves[leaf.id] = leaf;
    _bodies[leaf.id] = _buildBody(leaf);
    return _visitedIds.length - 1;
  }

  Widget _buildBody(SettingsNode leaf) {
    final spec = panelSpecFor(leaf.panel);
    if (spec == null) return DefaultPanel(node: leaf);
    final body = Builder(builder: spec.build);
    if (!spec.scrollable) return body;
    // Column-based panels get a consistent gutter so their headings and cards
    // don't bleed against the detail-pane edges (the divider on the left, the
    // pane edge on the right) or sit flush under the breadcrumb. The
    // `scrollable: false` list / scaffold panels are left untouched — they own
    // their own (often full-width, responsive) padding.
    return Builder(
      builder: (context) {
        final gutter = context.designTokens.spacing.step6;
        return SingleChildScrollView(
          padding: EdgeInsets.all(gutter),
          child: body,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: _currentIndex,
      sizing: StackFit.expand,
      children: [
        for (final id in _visitedIds)
          KeyedSubtree(
            key: ValueKey('leaf-body:$id'),
            child: _bodies[id]!,
          ),
      ],
    );
  }
}
