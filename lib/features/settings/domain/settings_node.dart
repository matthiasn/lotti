import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An immediate action a Settings tree row performs instead of opening a
/// settings page: the Manual leaves the app for the browser, What's New opens
/// its release-notes modal over whatever is on screen.
enum SettingsNodeAction { openManual, openWhatsNew }

/// One node in the Settings tree. Branch nodes carry [children]; action
/// leaves carry [action]. What a navigable node shows — its URL, its mobile
/// page, its desktop panel — is declared on its entry in `settingsRoutes`,
/// keyed by [id].
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
    this.action,
    this.sectionBreakBefore = false,
  });

  /// Stable slash-delimited path id (e.g. `sync`, `sync/backfill`).
  final String id;

  /// Glyph rendered in the icon tile.
  final IconData icon;

  /// Row title (Subtitle 2).
  final String title;

  /// Row description (Caption).
  final String desc;

  /// Ordered list of children. `null` marks this node as a leaf;
  /// an empty list marks a branch that happens to have no visible
  /// children in the current flag configuration (e.g. Agents with
  /// every sub-flag off — still addressable, but the left column
  /// will render it as a leaf).
  final List<SettingsNode>? children;

  /// Immediate behavior for a non-navigational leaf, such as opening an
  /// external support resource. Action leaves have no route.
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
          other.action == action &&
          other.sectionBreakBefore == sectionBreakBefore &&
          listEquals(other.children, children);

  @override
  int get hashCode => Object.hash(
    id,
    icon,
    title,
    desc,
    action,
    sectionBreakBefore,
    children == null ? null : Object.hashAll(children!),
  );
}
