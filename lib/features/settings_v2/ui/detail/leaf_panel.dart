import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/settings_v2/domain/settings_node.dart';
import 'package:lotti/features/settings_v2/state/settings_tree_controller.dart';
import 'package:lotti/features/settings_v2/ui/detail/default_panel.dart';
import 'package:lotti/features/settings_v2/ui/detail/panel_registry.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// Detail-pane wrapper for a selected leaf.
///
/// Responsibilities:
/// - Render a compact local header: small breadcrumb trail line, then
///   a Heading 3 title for the selected leaf.
/// - Resolve the panel body by looking the leaf's `panel` id up via
///   [panelSpecFor]; falls back to [DefaultPanel] when the id isn't
///   (yet) registered.
/// - Keep previously-visited leaf bodies mounted via an
///   [IndexedStack] so switching between siblings preserves their
///   internal state (scroll position, filter, in-flight loaders).
///   Without this, the `AnimatedSwitcher` above `SettingsDetailPane`
///   would tear down each body on every leaf change.
///
/// The body fills the full detail-pane width — no center-and-cap
/// treatment. The pane is already bounded by the tree-nav column on
/// the left and the user-resizable divider, so further constraining
/// here made panels read as floating cards rather than page
/// surfaces. Panels that want their own max-width (e.g. long-form
/// reading) can wrap themselves.
///
/// The crumb trail reads from [ancestors], which is the root → self
/// chain produced by `SettingsTreeIndex.ancestors(id)`. The root
/// crumb is prefixed with a locale-aware "Settings" label so the
/// user sees the same breadcrumb shape as the Figma reference
/// regardless of what the first tree node's title happens to be.
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
  /// child index.
  final List<String> _visitedIds = <String>[];
  final Map<String, Widget> _bodies = <String, Widget>{};
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
    final leaf = widget.ancestors.last;
    final oldLeaf = oldWidget.ancestors.isEmpty
        ? null
        : oldWidget.ancestors.last;
    if (leaf.id != oldLeaf?.id) {
      _currentIndex = _ensureCached(leaf);
      return;
    }
    // Same id, but the leaf payload itself changed (e.g. `panel`
    // moved from null to a registered id, or the title/badge was
    // edited in-place). Rebuild the cached body so the rendered
    // panel reflects the latest node — without this, a leaf that
    // started life as `DefaultPanel(node: leaf)` would stay on the
    // placeholder forever even after its `panel` got wired up.
    if (oldLeaf != null && leaf != oldLeaf) {
      _bodies[leaf.id] = _buildBody(leaf);
    }
  }

  /// Inserts [leaf] into the cache on first visit and returns its
  /// IndexedStack child index. Idempotent — repeated visits are
  /// cheap lookups. Called only from [initState] and
  /// [didUpdateWidget] so [build] stays a pure function of state.
  int _ensureCached(SettingsNode leaf) {
    final existing = _visitedIds.indexOf(leaf.id);
    if (existing != -1) return existing;
    _visitedIds.add(leaf.id);
    _bodies[leaf.id] = _buildBody(leaf);
    return _visitedIds.length - 1;
  }

  Widget _buildBody(SettingsNode leaf) {
    final spec = panelSpecFor(leaf.panel);
    if (spec == null) return DefaultPanel(node: leaf);
    final body = Builder(builder: spec.build);
    return spec.scrollable ? SingleChildScrollView(child: body) : body;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final leaf = widget.ancestors.last;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: tokens.spacing.step6,
        vertical: tokens.spacing.step5,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _LocalCrumbs(ancestors: widget.ancestors, tokens: tokens),
          SizedBox(height: tokens.spacing.step3),
          Text(
            leaf.title,
            style: tokens.typography.styles.heading.heading3.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              sizing: StackFit.expand,
              children: [
                for (final id in _visitedIds)
                  KeyedSubtree(
                    key: ValueKey('leaf-body:$id'),
                    child: _bodies[id]!,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalCrumbs extends ConsumerWidget {
  const _LocalCrumbs({required this.ancestors, required this.tokens});

  final List<SettingsNode> ancestors;
  final DsTokens tokens;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textMid = tokens.colors.text.mediumEmphasis;
    final textLo = tokens.colors.text.lowEmphasis;
    final accent = tokens.colors.interactive.enabled;
    final rootLabel = context.messages.settingsV2DetailRootCrumb;
    final captionStyle = tokens.typography.styles.others.caption.copyWith(
      color: textMid,
    );
    final leafStyle = captionStyle.copyWith(
      color: tokens.colors.text.highEmphasis,
    );
    final separatorStyle = captionStyle.copyWith(color: textLo);
    // Every node in the local crumb trail is a non-terminal hint
    // (medium emphasis). The leaf segment renders at highEmphasis
    // so users can orient themselves to "where am I" even when the
    // leaf title scrolls off-screen below.
    final titles = <String>[rootLabel, ...ancestors.map((n) => n.title)];

    // Clicking a crumb truncates the tree path to that depth:
    // - index 0 ("Settings") → []
    // - index 1 → first ancestor only
    // - last index → already the current leaf, no-op
    // Disable the current (last) segment and the root when no
    // truncation would actually change state.
    void onTap(int index) {
      // `titles[0]` is the synthetic root label; every subsequent
      // title maps 1:1 to an `ancestors[i-1]`, so truncating to
      // depth == index drops everything after `ancestors[i-1]`.
      ref.read(settingsTreePathProvider.notifier).truncateTo(index);
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (var i = 0; i < titles.length; i++) ...[
          if (i > 0)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step2),
              child: Text('›', style: separatorStyle),
            ),
          if (i < titles.length - 1)
            _CrumbLink(
              label: titles[i],
              onTap: () => onTap(i),
              style: captionStyle,
              hoverColor: accent,
            )
          else
            Semantics(
              header: true,
              child: Text(titles[i], style: leafStyle),
            ),
        ],
      ],
    );
  }
}

/// Tappable breadcrumb segment. Clickable surface with a focusable
/// [InkWell]; hover + focus paint the label in the interactive
/// accent so the affordance is visible without adding an
/// underscore decoration.
class _CrumbLink extends StatefulWidget {
  const _CrumbLink({
    required this.label,
    required this.onTap,
    required this.style,
    required this.hoverColor,
  });

  final String label;
  final VoidCallback onTap;
  final TextStyle style;
  final Color hoverColor;

  @override
  State<_CrumbLink> createState() => _CrumbLinkState();
}

class _CrumbLinkState extends State<_CrumbLink> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final active = _hovered || _focused;
    final style = active
        ? widget.style.copyWith(color: widget.hoverColor)
        : widget.style;
    return Semantics(
      button: true,
      label: widget.label,
      child: InkWell(
        onTap: widget.onTap,
        onHover: (v) => setState(() => _hovered = v),
        onFocusChange: (v) => setState(() => _focused = v),
        borderRadius: BorderRadius.circular(tokens.radii.xs),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: tokens.spacing.step2,
            vertical: tokens.spacing.step1,
          ),
          child: Text(widget.label, style: style),
        ),
      ),
    );
  }
}
