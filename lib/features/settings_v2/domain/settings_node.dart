import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Visual tone of a [NodeBadge]. Each tone resolves to a background /
/// text pair in the design-system palette when the badge renders.
enum NodeTone { info, teal, error }

/// An immediate action a Settings tree row can perform without opening a
/// settings detail panel.
enum SettingsNodeAction { openManual }

/// Small pill rendered to the right of a tree-row title — used for the
/// "v2.4" (info), "Live" (teal) and "Retry" (error) cases seen in the
/// Figma reference.
@immutable
class NodeBadge {
  const NodeBadge({required this.label, required this.tone});

  final String label;
  final NodeTone tone;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeBadge && other.label == label && other.tone == tone;

  @override
  int get hashCode => Object.hash(label, tone);
}

/// One node in the Settings tree. Branch nodes carry [children]; internal
/// leaves carry [panel] (the id of the widget to render in the detail pane),
/// while immediate action leaves carry [action].
///
/// Every node has a stable [id] so [children] and ancestor lookups
/// can address nodes without relying on object identity (tree data
/// is rebuilt whenever the set of enabled feature flags changes, so
/// identity is not stable across rebuilds).
@immutable
class SettingsNode {
  const SettingsNode({
    required this.id,
    required this.icon,
    required this.title,
    required this.desc,
    this.children,
    this.panel,
    this.badge,
    this.action,
    this.sectionBreakBefore = false,
  });

  /// Stable slash-delimited path id (e.g. `sync`, `sync/backfill`).
  final String id;

  /// Glyph rendered in the icon tile.
  final IconData icon;

  /// Row title (Subtitle 2 per spec §3).
  final String title;

  /// Row description (Caption per spec §3).
  final String desc;

  /// Ordered list of children. `null` marks this node as a leaf;
  /// an empty list marks a branch that happens to have no visible
  /// children in the current flag configuration (e.g. Agents with
  /// every sub-flag off — still addressable, but the left column
  /// will render it as a leaf).
  final List<SettingsNode>? children;

  /// Registry id for the widget shown in the detail pane. Internal leaves
  /// should set this; action leaves and most branches leave it `null`.
  final String? panel;

  /// Optional trailing pill.
  final NodeBadge? badge;

  /// Immediate behavior for a non-navigational leaf, such as opening an
  /// external support resource. Action leaves intentionally have no panel.
  final SettingsNodeAction? action;

  /// Whether the containing settings level inserts a design-system section
  /// gap immediately before this node.
  final bool sectionBreakBefore;

  /// Branch convenience: a node is a branch iff it has a non-null
  /// [children] list. Emptiness does not downgrade it to a leaf —
  /// the tree shape is determined at definition time, not by the
  /// current flag set.
  bool get hasChildren => children != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingsNode &&
          other.id == id &&
          other.icon == icon &&
          other.title == title &&
          other.desc == desc &&
          other.panel == panel &&
          other.badge == badge &&
          other.action == action &&
          other.sectionBreakBefore == sectionBreakBefore &&
          listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(
    id,
    icon,
    title,
    desc,
    panel,
    badge,
    action,
    sectionBreakBefore,
    children == null ? null : Object.hashAll(children!),
  );
}
