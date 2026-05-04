import 'package:flutter/widgets.dart';

/// Data-only value model for a row in any agent listing page (Instances,
/// Templates, Souls, Pending Wakes). Each tab adapts its domain entity
/// into one of these so a single shared scaffolding can render them.
///
/// The model never holds [Widget]s directly so VMs stay cheap to build,
/// stay `const`-friendly where possible, and stay decoupled from the
/// widget tree. The row widget composes `leading` and `trailing` from
/// the descriptors below.
@immutable
class AgentListRowData {
  const AgentListRowData({
    required this.id,
    required this.title,
    required this.searchKey,
    required this.sortAt,
    this.subtitle,
    this.leading,
    this.pills = const [],
    this.metaRight,
    this.trailing,
    this.onTap,
  });

  /// Stable id, used as a list key and for navigation.
  final String id;

  /// Primary text on the row.
  final String title;

  /// Optional secondary line shown after the title (compact: stacked).
  final String? subtitle;

  /// Optional 20–22 px leading element, see [AgentListLeading].
  final AgentListLeading? leading;

  /// Closed-set pills shown inline (type / status / kind…). Tabs cannot
  /// invent new tones — see [AgentListPillTone] — so the catalogue stays
  /// coherent across pages.
  final List<AgentListPill> pills;

  /// Optional small mono cell to the right of the pills (e.g. time,
  /// version). Plain string so the row controls the typography token.
  final String? metaRight;

  /// Optional builder for a custom trailing widget (e.g. delete button,
  /// running spinner). A builder rather than a [Widget] so it composes
  /// only when the row is materialized and stays cheap to construct.
  final Widget Function(BuildContext context)? trailing;

  /// Tapping the row.
  final VoidCallback? onTap;

  /// Used by Recent / Oldest sort axes. Whatever timestamp best
  /// represents "when this row was last touched" for the tab.
  final DateTime sortAt;

  /// Lower-cased blob the toolbar's search input runs `contains` against.
  final String searchKey;
}

/// Closed catalogue of pill tones — keeps every listing page coherent.
/// Custom colours can come in via [AgentListPill.customColor] only.
enum AgentListPillTone { neutral, interactive, warning, error, info, muted }

/// One pill rendered inline in [AgentListRowData.pills].
@immutable
class AgentListPill {
  const AgentListPill({
    required this.label,
    this.tone = AgentListPillTone.neutral,
    this.customColor,
  });

  final String label;
  final AgentListPillTone tone;

  /// When non-null overrides the tone's accent (used for unusual one-offs
  /// — try not to). The row still pulls the bg/fg shading rules from the
  /// design tokens; this only swaps the accent hue.
  final Color? customColor;
}

/// Sealed descriptor for a row's optional leading element. Concrete
/// variants stay narrow on purpose.
sealed class AgentListLeading {
  const AgentListLeading();
}

/// Hue-tinted initial-tile (currently used for soul avatars). The row
/// renders this through `SoulAvatar` so all listing pages share a single
/// avatar primitive.
class AgentListAvatarLeading extends AgentListLeading {
  const AgentListAvatarLeading({
    required this.label,
    required this.hue,
    this.size = 20,
  });
  final String label;
  final int hue;
  final double size;
}

/// Plain icon leading (e.g. Souls' psychology icon, Pending Wakes' alarm).
class AgentListIconLeading extends AgentListLeading {
  const AgentListIconLeading({
    required this.icon,
    this.color,
    this.size = 20,
  });
  final IconData icon;
  final Color? color;
  final double size;
}

/// One filter axis (Type, Status, Soul, Wake kind…). The page composes a
/// list of these and hands it to `AgentListingShell`; the toolbar shows
/// one section per axis in the Filters popover.
@immutable
class AgentListFilterAxis {
  const AgentListFilterAxis({
    required this.id,
    required this.sectionLabel,
    required this.options,
    this.chipTone = AgentListPillTone.neutral,
  });

  /// Stable id (e.g. `'type'`, `'status'`, `'soul'`). Used as the key for
  /// the page-level `AgentListFilterState.selectionsByAxis`.
  final String id;

  /// Localized header shown above the axis's section in the popover.
  final String sectionLabel;

  /// Available options for this axis with their full-dataset counts.
  final List<AgentListFilterOption> options;

  /// Tone used for this axis's chips in the active-filter row.
  final AgentListPillTone chipTone;
}

/// One row in an [AgentListFilterAxis]'s popover section.
@immutable
class AgentListFilterOption {
  const AgentListFilterOption({
    required this.id,
    required this.label,
    required this.count,
    this.swatchHue,
  });

  /// Stable id within its axis (e.g. `'taskAgent'`, `'active'`,
  /// `'soul-laura'`).
  final String id;

  /// Localized label shown in the popover row and as the chip text.
  final String label;

  /// Total instances of this option in the underlying dataset.
  final int count;

  /// Optional hue for a small color dot (used by soul rows).
  final int? swatchHue;
}

/// One group axis (Soul / Type / Status / When…). The page provides a
/// `buildGroups` function that turns the post-sort row list into a list
/// of [AgentListGroup]s.
@immutable
class AgentListGroupAxis {
  const AgentListGroupAxis({
    required this.id,
    required this.label,
    required this.buildGroups,
  });

  final String id;
  final String label;
  final List<AgentListGroup> Function(List<AgentListRowData> rows) buildGroups;
}

/// One sort axis (Recent / Oldest / Name…).
@immutable
class AgentListSortAxis {
  const AgentListSortAxis({
    required this.id,
    required this.label,
    required this.compare,
  });

  final String id;
  final String label;
  final Comparator<AgentListRowData> compare;
}

/// One group in the rendered list. `id` is used to key per-group
/// collapse state.
@immutable
class AgentListGroup {
  const AgentListGroup({
    required this.id,
    required this.label,
    required this.items,
    this.leading,
    this.activeCount,
  });

  /// Stable group id (e.g. `'soul:laura'`, `'kind:taskAgent'`).
  final String id;

  /// Header label.
  final String label;

  /// Optional leading element for the header (used by Soul to show the
  /// avatar; null for type / status / when groups).
  final AgentListLeading? leading;

  final List<AgentListRowData> items;

  /// When non-null the header shows "N active" in the interactive accent.
  /// Tabs decide what "active" means for them; null suppresses the cell.
  final int? activeCount;
}
