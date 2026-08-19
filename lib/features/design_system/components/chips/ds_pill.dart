import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/ds_dashed_border.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Visual variant for [DsPill]. Drives background, border, and label color.
enum DsPillVariant {
  /// Solid surface fill, high-emphasis label, optional 8px leading dot.
  filled,

  /// `pillColor` at 18% alpha background, `pillColor` label.
  tinted,

  /// Transparent background, 50%-alpha `pillColor` border, `pillColor` label.
  outline,

  /// Transparent background with a 1px dashed `decorative.level03` border
  /// and a `text.mediumEmphasis` label. Used for empty / placeholder states.
  muted,
}

/// 28px pill chip used across the task detail header and elsewhere in the
/// design system. Variants share anatomy (height, radius, padding, gap) and
/// only differ in fill / border / label color so the same primitive can carry
/// every metadata pill in the header.
class DsPill extends StatelessWidget {
  const DsPill({
    required this.variant,
    this.label,
    this.labelWidget,
    this.leading,
    this.trailing,
    this.color,
    this.labelColor,
    this.bordered = false,
    this.borderColor,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.cornerRadius,
    super.key,
  }) : assert(
         variant != DsPillVariant.tinted || color != null,
         'tinted variant requires `color`',
       ),
       assert(
         variant != DsPillVariant.outline || color != null,
         'outline variant requires `color`',
       );

  final DsPillVariant variant;
  final String? label;

  /// Optional custom label widget rendered in place of the [label] string.
  /// When non-null it takes precedence over [label] and the caller owns its
  /// styling (the canonical [label] styling is NOT applied). Like the string
  /// label it is wrapped in a [Flexible] so it ellipsizes instead of
  /// overflowing the row — used by the mobile saved-filter pill to keep the
  /// trailing status segment of a long name visible while the leading category
  /// prefix truncates first.
  final Widget? labelWidget;
  final Widget? leading;
  final Widget? trailing;

  /// Pill accent color. Required for `tinted` and `outline`; ignored for
  /// `filled` / `muted` (they pull from tokens).
  final Color? color;

  /// Optional override for the label text color. Defaults to the variant's
  /// canonical color when null (high-emphasis on filled, the accent on
  /// tinted/outline, low-emphasis on muted).
  final Color? labelColor;

  /// When true, draws a quiet 1px `decorative.level02` border around the
  /// `filled` variant. Opt-in (default false) so existing filled pills are
  /// unchanged; the task header enables it so low-vision users get a clear
  /// chip boundary against the near-same-tone surface. No-op for the other
  /// variants, which already carry their own border / tint.
  final bool bordered;

  /// Optional color for the bordered [DsPillVariant.filled] shell. Defaults
  /// to `decorative.level02`; ignored when [bordered] is false and for other
  /// variants. Selection still takes precedence with its interactive border.
  final Color? borderColor;

  /// Orthogonal selection state. Composes with [variant] (it is **not** a new
  /// variant): when true, the pill draws a 1px teal `interactive.enabled`
  /// border, a teal-tinted fill (`surface.selected` on the `filled` variant;
  /// the variant's own tint is kept on `tinted`), and a bold label — the
  /// multi-channel "active saved filter" treatment used by the mobile saved
  /// filter rail.
  ///
  /// Only `filled` and `tinted` react to selection; `outline` / `muted` ignore
  /// it. **Regression guarantee:** `selected: false` leaves every existing
  /// consumer byte-identical (no border, no fill change, no weight change), so
  /// the orthogonal flag is safe to add without touching current callers.
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Corner radius override. Defaults to the fully-rounded
  /// `radii.badgesPills`. Surfaces that separate affordances by shape —
  /// clickable elements fully rounded, informative chips at the small fixed
  /// radius — pass `tokens.radii.smallChips` for a non-tappable instance.
  final double? cornerRadius;

  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(
      cornerRadius ?? tokens.radii.badgesPills,
    );
    final hPadding = tokens.spacing.step3;
    final gap = tokens.spacing.step2;

    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: labelColor ?? _labelColor(context, tokens),
      // No italic on the muted variant. Its dashed border and low-emphasis
      // ink already say "unset" twice; the slant added a third signal that
      // reads as *disabled* rather than *empty* — and a 12pt italic caption
      // is a genuine legibility failure at large accessibility text sizes.
      // The pills a user most needs to fill in were the ones that looked
      // unavailable.
      // Bold only when selected so unselected pills keep the caption's own
      // weight (regression-safe: copyWith(null) is a no-op).
      fontWeight: selected ? FontWeight.w700 : null,
      height: 1,
    );

    // The teal selection border, shared by the variants that react to
    // selection. Built once so the decoration branches stay terse.
    final selectedBorder = Border.all(color: tokens.colors.interactive.enabled);

    final children = <Widget>[
      if (leading != null) ...[
        leading!,
        SizedBox(width: gap),
      ],
      if (labelWidget != null)
        // Caller-styled custom label; still Flexible so it ellipsizes rather
        // than overflowing a width-bounded pill.
        Flexible(child: labelWidget!)
      else if (label != null)
        // Flexible so a host-bounded pill (e.g. a max-width link badge)
        // ellipsizes the label instead of overflowing the row.
        Flexible(
          child: Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle,
          ),
        ),
      if (trailing != null) ...[
        SizedBox(width: gap),
        trailing!,
      ],
    ];

    // A floor, not a box: at 1.0x text scale the pill is its canonical 28px,
    // but a fixed height CLIPPED scaled-up captions — and the muted chips
    // this shell renders are the only route to category / due date / label /
    // estimate on a fresh task, exactly the users large text serves.
    final content = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: height),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: hPadding,
          vertical: tokens.spacing.step1,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

    final shaped = switch (variant) {
      DsPillVariant.filled => DecoratedBox(
        decoration: BoxDecoration(
          // Teal-tinted surface when selected; the quiet/plain surface
          // otherwise (unchanged for existing consumers).
          color: selected
              ? tokens.colors.surface.selected
              : tokens.colors.surface.enabled,
          borderRadius: radius,
          border: selected
              ? selectedBorder
              : (bordered
                    ? Border.all(
                        color: borderColor ?? tokens.colors.decorative.level02,
                      )
                    : null),
        ),
        child: content,
      ),
      DsPillVariant.tinted => DecoratedBox(
        decoration: BoxDecoration(
          color: color!.withValues(alpha: 0.18),
          borderRadius: radius,
          border: selected ? selectedBorder : null,
        ),
        child: content,
      ),
      DsPillVariant.outline => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: color!.withValues(alpha: 0.5)),
        ),
        child: content,
      ),
      DsPillVariant.muted => DsDashedBorder(
        // level03, both themes. At level02 (24% alpha) the dashed outline all
        // but vanished on either surface — low-vision review found the unset
        // chips "nearly invisible" in light theme first and then, next round,
        // called the dark ones a blocker outright: the only controls that set
        // a due date effectively did not exist. The dash pattern already
        // keeps the border reading as "unset" next to the solid chips, so the
        // stronger stroke costs nothing semantically.
        color: tokens.colors.decorative.level03,
        radius: cornerRadius ?? tokens.radii.badgesPills,
        child: content,
      ),
    };

    if (onTap == null && onLongPress == null) return shaped;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        onLongPress: onLongPress,
        child: shaped,
      ),
    );
  }

  Color _labelColor(BuildContext context, DsTokens tokens) {
    return switch (variant) {
      DsPillVariant.filled => tokens.colors.text.highEmphasis,
      DsPillVariant.tinted => color!,
      DsPillVariant.outline => color!,
      // The dashed border alone carries "unset" — the label must stay
      // legible. In light theme even mediumEmphasis grey flirted with the
      // disabled affordance on the white surface, so the label reads at
      // highEmphasis there; dark keeps medium, where high out-shouted the
      // set chips beside it.
      DsPillVariant.muted =>
        Theme.of(context).brightness == Brightness.light
            ? tokens.colors.text.highEmphasis
            : tokens.colors.text.mediumEmphasis,
    };
  }
}
