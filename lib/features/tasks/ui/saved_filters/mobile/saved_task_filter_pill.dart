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
/// category. Mirrors the desktop `SavedTaskFilterRow` dot resolution.
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
/// [label], and a stable-width trailing count slot. When [selected] and
/// [onOpenSheet] is set, a trailing chevron cues "tap to open the
/// saved-filters sheet" so a selected-looking chip that navigates isn't a
/// surprise. There is deliberately **no in-pill selection check** — the active
/// state is already encoded by the teal border + tinted fill + bold name (and
/// the category dot), so a redundant check would only steal width from the
/// name. The width it frees goes to the name, and a name that still overflows
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
    this.onOpenSheet,
    super.key,
  });

  /// Display name (ellipsizes when the pill is width-bounded).
  final String label;

  /// Primary tap action for the whole ≥48dp region. For an inactive pill this
  /// applies the filter; for the active pill it opens the sheet (paired with
  /// the chevron cue).
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

  /// When set and [selected], renders the chevron affordance. The chevron is
  /// purely a visual cue — activation routes through [onTap] over the whole
  /// region so the target stays ≥48dp.
  final VoidCallback? onOpenSheet;

  /// Largest value rendered verbatim; anything above shows `999+`. Shared with
  /// the sheet's count column so the two surfaces cap identically.
  static const int countCap = 999;

  @visibleForTesting
  static Key chevronKey(String label) =>
      Key('saved-filter-pill-chevron-$label');

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // 48dp from named steps (40 + 8) — the platform minimum tap target, never
    // a mutation of DsPill.height.
    final minTarget = tokens.spacing.step8 + tokens.spacing.step3;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);

    final leading = _buildLeading(tokens);
    final trailing = _buildTrailing(tokens);

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
      ),
    );
  }

  Widget? _buildTrailing(DsTokens tokens) {
    final showChevron = selected && onOpenSheet != null;
    if (!showCount && !showChevron) return null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showCount)
          _CountSlot(
            tokens: tokens,
            count: count,
            loading: countLoading,
          ),
        if (showChevron) ...[
          SizedBox(width: tokens.spacing.step2),
          Icon(
            Icons.expand_more_rounded,
            key: chevronKey(label),
            size: tokens.spacing.step4,
            // High-emphasis on-surface: this disclosure affordance must stay
            // legible over the mint `surface.selected` fill in light theme
            // (teal-on-mint was low contrast). The count, by contrast, is a
            // secondary datum and stays medium-emphasis.
            color: tokens.colors.text.highEmphasis,
          ),
        ],
      ],
    );
  }
}

/// Trailing count column: a `step7` min-width reserves the same column start
/// for 1- vs 3-digit values (so the name-truncation point doesn't jump), but
/// the slot is free to GROW so the digits are NEVER width-clipped — at large
/// text the name (DsPill's `Flexible` label) ellipsizes while the full count
/// (e.g. `214`) still renders. Tabular figures keep the column aligned.
///
/// The count is a *secondary* datum, so it reads `text.mediumEmphasis` in every
/// state — selected or not — exactly matching the sheet's `_SheetCount`. The
/// active state is conveyed by the pill's border / fill / bold name, never by
/// re-colouring the number (teal-on-mint was also a light-theme contrast trap).
/// A dimmed `0` and a cold-start `–` drop to low-emphasis.
class _CountSlot extends StatelessWidget {
  const _CountSlot({
    required this.tokens,
    required this.count,
    required this.loading,
  });

  final DsTokens tokens;
  final int? count;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final String text;
    final Color color;
    if (loading || count == null) {
      text = '–';
      color = tokens.colors.text.lowEmphasis;
    } else if (count == 0) {
      text = '0';
      color = tokens.colors.text.lowEmphasis;
    } else {
      text = count! > SavedTaskFilterPill.countCap
          ? '${SavedTaskFilterPill.countCap}+'
          : '$count';
      color = tokens.colors.text.mediumEmphasis;
    }

    return ConstrainedBox(
      // step7 (32) keeps a stable column start for `999+` in tabular caption,
      // but only as a MIN — the slot grows so a large-text value never clips.
      constraints: BoxConstraints(minWidth: tokens.spacing.step7),
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
        // …while the status segment is pinned and stays readable.
        Text(
          tail,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ],
    );
  }
}
