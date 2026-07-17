import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/chips/ds_pill.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/tasks/state/saved_filters/saved_task_filter.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:lotti/utils/color.dart';

/// Resolves the leading-dot colour for a saved filter: the colour of its first
/// selected category that still resolves to a non-empty hex (deleted or
/// colourless categories are skipped), or null when the filter selects no
/// category. Shared by the desktop and mobile task-pane rail.
Color? savedFilterCategoryColor(SavedTaskFilter filter) {
  final cache = getIt<EntitiesCacheService>();
  for (final id in filter.filter.selectedCategoryIds) {
    final hex = cache.getCategoryById(id)?.color;
    if (hex != null && hex.isNotEmpty) return colorFromCssHex(hex);
  }
  return null;
}

/// First resolvable category name for a saved filter, surfaced in the pill's
/// accessibility label so category information is never colour-only. Null when
/// the filter selects no (resolvable) category.
String? savedFilterCategoryName(SavedTaskFilter filter) {
  final cache = getIt<EntitiesCacheService>();
  for (final id in filter.filter.selectedCategoryIds) {
    final name = cache.getCategoryById(id)?.name;
    if (name != null && name.isNotEmpty) return name;
  }
  return null;
}

/// A single tappable saved-filter pill in the mobile rail.
///
/// Anatomy (left → right): an optional [categoryColor] dot, an ellipsizing
/// [label], and a stable-width trailing count slot. There is exactly **one**
/// disclosure chevron in the rail and it lives on the "Saved" button alone —
/// the pill carries no chevron of its own, so every pill reads as a single
/// predictable tap target rather than a chip with an ambiguous caret. There is
/// also deliberately **no in-pill selection check** — the active state is
/// already encoded by the teal border + tinted fill + bold name (and the
/// category dot), so a redundant check would only steal width from the name.
/// The width it frees goes to the name, and a name that still overflows
/// truncates its leading category prefix *before* its trailing status segment
/// (see [_PillLabel]).
///
/// The whole pill is wrapped in a ≥48dp tap target (the wrapper owns the tap +
/// ripple; [DsPill.onTap] is intentionally unused) and presented to assistive
/// tech as a single selectable button via [semanticsLabel]. The 28dp
/// [DsPill.height] is never mutated — the target comes from the padded wrapper.
class SavedTaskFilterPill extends StatelessWidget {
  const SavedTaskFilterPill({
    required this.label,
    required this.onTap,
    required this.semanticsLabel,
    this.selected = false,
    this.categoryColor,
    this.count,
    this.countLoading = false,
    this.showCount = true,
    super.key,
  });

  /// Display name (ellipsizes when the pill is width-bounded).
  final String label;

  /// Primary tap action for the whole ≥48dp region. For an inactive pill this
  /// applies/switches the filter; for the active pill (and the "Custom" pill)
  /// it opens the saved-filters sheet — the whole pill body is the single tap
  /// target, with no separate caret hit-zone.
  final VoidCallback onTap;

  /// Full, single-node label for assistive tech, e.g.
  /// "{category}, {name}, {count} tasks". Composed by the caller so the dot's
  /// colour information is carried as the category name in text.
  final String semanticsLabel;

  /// Whether this pill reads as the active selection (teal border + tinted
  /// fill + bold name).
  final bool selected;

  /// Resolved category colour for the leading dot, or null when the filter
  /// selects no (resolvable) category.
  final Color? categoryColor;

  /// Live match count. Ignored when [showCount] is false. Capped at `999+`;
  /// a zero reads dimmed.
  final int? count;

  /// When true the count slot shows a placeholder `–` (cold start) and the
  /// semantics label omits the count clause entirely.
  final bool countLoading;

  /// Whether to render the trailing count slot at all. "Custom" hides it.
  final bool showCount;

  /// Largest value rendered verbatim; anything above shows `999+`. Shared with
  /// the sheet's count column so the two surfaces cap identically.
  static const int countCap = 999;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // 48dp from named steps (40 + 8) — the platform minimum tap target, never
    // a mutation of DsPill.height.
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);

    final leading = _buildLeading(tokens);
    final trailing = _buildTrailing();

    final pill = DsPill(
      variant: DsPillVariant.filled,
      bordered: true,
      selected: selected,
      labelWidget: _PillLabel(label: label, selected: selected, tokens: tokens),
      leading: leading,
      trailing: trailing,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: minTarget,
                minHeight: minTarget,
              ),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: pill,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildLeading(DsTokens tokens) {
    // Only the category dot leads the pill — no redundant selection check (the
    // teal border + tinted fill + bold name already mark the active pill, and
    // dropping the check returns that width to the name).
    if (categoryColor == null) return null;
    return Container(
      width: tokens.spacing.step3,
      height: tokens.spacing.step3,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: categoryColor,
        // A thin background-toned ring so a teal category colour never melts
        // into the teal selection accent (the selected pill's mint fill +
        // `interactive.enabled` border). The moat keeps the dot a distinct disc
        // regardless of the category colour.
        border: Border.all(color: tokens.colors.background.level01),
      ),
    );
  }

  Widget? _buildTrailing() {
    if (!showCount) return null;
    // Loading folds into the `null` placeholder so the one shared renderer
    // (`SavedFilterCountText`) owns the dash; the pill never styles the count
    // itself, keeping the rail and sheet numerals byte-identical. `selected`
    // lifts the count to high emphasis so it stays legible on the mint fill.
    return SavedFilterCountText(
      count: countLoading ? null : count,
      selected: selected,
    );
  }
}

/// The single count renderer shared by the rail pill and the sheet rows, so the
/// same number never changes type, weight, or sizing between the two surfaces.
/// One type token (`others.caption`), tabular figures, and a fixed weight.
///
/// The count's emphasis is gated on [selected] so it stays legible against the
/// selected pill's mint / `surface.selected` tint: a selected count reads
/// `text.highEmphasis`, an unselected one the *secondary* `text.mediumEmphasis`,
/// and a dimmed `0` or a cold-start / loading `–` (a null [count]) the
/// `text.lowEmphasis` placeholder tone. This mirrors how the name already gates
/// its weight on selection; the bold label stays visually primary, the count
/// reads as legible DATA in every state/theme. The active state itself is still
/// carried by the pill's border / fill / bold name and the sheet row's radio +
/// selected surface — emphasis only lifts the number enough to stay readable on
/// the mint fill (teal-on-mint was the original light-theme contrast trap).
///
/// [minWidth] reserves a stable column start (so the name-truncation point
/// doesn't jump between 1- and 3-digit values) but is only a MIN — the slot is
/// free to GROW, so at large text the name ellipsizes while the full count
/// (e.g. `214`) is NEVER width-clipped.
class SavedFilterCountText extends StatelessWidget {
  const SavedFilterCountText({
    required this.count,
    this.selected = false,
    this.minWidth,
    super.key,
  });

  /// Match count; `null` renders the loading / cold-start `–` placeholder.
  final int? count;

  /// Whether the count belongs to the active selection. When true a non-zero
  /// count lifts to `text.highEmphasis` so it stays legible on the mint fill;
  /// otherwise it reads `text.mediumEmphasis`.
  final bool selected;

  /// Reserved column min-width. Defaults to `step7` (the rail pill slot); the
  /// sheet passes `step8` for its slightly wider comparison column.
  final double? minWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final String text;
    final Color color;
    if (count == null) {
      text = '–';
      color = tokens.colors.text.lowEmphasis;
    } else if (count == 0) {
      text = '0';
      color = tokens.colors.text.lowEmphasis;
    } else {
      text = count! > SavedTaskFilterPill.countCap
          ? '${SavedTaskFilterPill.countCap}+'
          : '$count';
      color = selected
          ? tokens.colors.text.highEmphasis
          : tokens.colors.text.mediumEmphasis;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth ?? tokens.spacing.step7),
      child: Text(
        text,
        textAlign: TextAlign.end,
        maxLines: 1,
        style: tokens.typography.styles.others.caption.copyWith(
          color: color,
          height: 1,
          fontWeight: FontWeight.w600,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Renders the pill [label] so that, when the pill is width-bounded, a leading
/// "Category · …" prefix ellipsizes *before* the trailing status segment.
///
/// The category is already encoded by the leading dot, so the status (the text
/// after the last `·`) is the higher-value half to keep visible. When the name
/// carries a `·`, the prefix is laid out in a [Flexible] (so it truncates
/// first) and the `·`-led suffix is pinned beside it; otherwise the whole name
/// falls back to an ordinary trailing ellipsis. Styling mirrors `DsPill`'s
/// canonical filled label (caption, high-emphasis, bold when [selected]).
class _PillLabel extends StatelessWidget {
  const _PillLabel({
    required this.label,
    required this.selected,
    required this.tokens,
  });

  final String label;
  final bool selected;
  final DsTokens tokens;

  static const String _separator = '·';

  @override
  Widget build(BuildContext context) {
    final style = tokens.typography.styles.others.caption.copyWith(
      color: tokens.colors.text.highEmphasis,
      height: 1,
      fontWeight: selected ? FontWeight.w700 : null,
    );

    final idx = label.lastIndexOf(_separator);
    // No usable separator (or it sits at the very start/end) → ordinary
    // trailing ellipsis on the whole name.
    if (idx <= 0 || idx >= label.length - 1) {
      return Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }

    final head = label.substring(0, idx); // "Lotti " (keeps the spacing)
    final tail = label.substring(idx); // "· In Progress" (the status segment)
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The category prefix yields width first and ellipsizes…
        Flexible(
          child: Text(
            head,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        // …while the status segment is pinned and stays readable. `Flexible`
        // (loose fit) keeps its natural width whenever the head can absorb the
        // shrink, and only lets it ellipsize (rather than overflow) in the
        // pathological case where the status alone exceeds the pill.
        Flexible(
          child: Text(
            tail,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}
