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

  /// Transparent background with a 1px dashed `decorative.level02` border and
  /// italic `text.lowEmphasis` label. Used for empty / placeholder states.
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
    this.leading,
    this.trailing,
    this.color,
    this.labelColor,
    this.bordered = false,
    this.onTap,
    this.onLongPress,
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
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  static const double height = 28;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    final hPadding = tokens.spacing.step3;
    final gap = tokens.spacing.step2;

    final labelStyle = tokens.typography.styles.others.caption.copyWith(
      color: labelColor ?? _labelColor(tokens),
      fontStyle: variant == DsPillVariant.muted
          ? FontStyle.italic
          : FontStyle.normal,
      height: 1,
    );

    final children = <Widget>[
      if (leading != null) ...[
        leading!,
        SizedBox(width: gap),
      ],
      if (label != null)
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

    final content = SizedBox(
      height: height,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: hPadding),
        child: Row(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );

    final shaped = switch (variant) {
      DsPillVariant.filled => DecoratedBox(
        decoration: BoxDecoration(
          color: tokens.colors.surface.enabled,
          borderRadius: radius,
          border: bordered
              ? Border.all(color: tokens.colors.decorative.level02)
              : null,
        ),
        child: content,
      ),
      DsPillVariant.tinted => DecoratedBox(
        decoration: BoxDecoration(
          color: color!.withValues(alpha: 0.18),
          borderRadius: radius,
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
        color: tokens.colors.decorative.level02,
        radius: tokens.radii.badgesPills,
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

  Color _labelColor(DsTokens tokens) {
    return switch (variant) {
      DsPillVariant.filled => tokens.colors.text.highEmphasis,
      DsPillVariant.tinted => color!,
      DsPillVariant.outline => color!,
      // Medium (not low) emphasis: a placeholder/empty pill must stay legible
      // for low-vision users — the dashed border + italic already mark it as
      // unset, so it reads as secondary without becoming invisible grey.
      DsPillVariant.muted => tokens.colors.text.mediumEmphasis,
    };
  }
}

/// Trailing `+` / "Add label" affordance — same height/shape as [DsPill] but
/// rendered with the muted (dashed) treatment. When [label] is null, only the
/// leading plus icon is shown.
class DsGhostChip extends StatelessWidget {
  const DsGhostChip({this.label, this.onTap, super.key});

  final String? label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DsPill(
      variant: DsPillVariant.muted,
      label: label,
      leading: Icon(
        Icons.add_rounded,
        size: 12,
        color: tokens.colors.text.lowEmphasis,
      ),
      // Adds the standard leading/trailing gap on the right so the label
      // doesn't sit flush against the dashed border.
      trailing: label == null ? null : const SizedBox.shrink(),
      onTap: onTap,
    );
  }
}
