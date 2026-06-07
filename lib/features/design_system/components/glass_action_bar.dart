import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Shared "glass chip" building blocks for sticky bottom action bars that
/// float over backdrop-blurred glass (see `DesignSystemGlassStrip`).
///
/// These were originally private to the task details action bar
/// (`task_action_bar.dart`). They live here so every sticky glass bar —
/// the task details bar and the day-planning modal bar — shares one
/// silhouette, one alpha tuning, and one hairline outline instead of
/// drifting per-feature.
///
/// No `surface.*`/`glass.*` design token covers "chip on glass over
/// arbitrary underlying content", so the alpha bumps below are
/// intentionally defined here once rather than fragmenting across widgets.

/// Alpha applied to the chip fill on top of `surface.focusPressed`. Sits
/// above any `surface.*` token so the chip silhouette stays opaque enough
/// to contrast the foreground against bright content (e.g. white chat
/// bubbles or embedded screenshots bleeding through the glass blur).
const double kDsGlassFillAlpha = 0.55;

/// Alpha for the hairline outline drawn over the chip fill. Painted via
/// `foregroundDecoration` so it doesn't widen the chip and trip
/// action-row layout thresholds.
const double kDsGlassBorderAlpha = 0.45;

/// Translucent fill used by glass chips when the caller supplies no solid
/// background colour.
Color dsGlassChipFill(DsTokens tokens) =>
    tokens.colors.surface.focusPressed.withValues(alpha: kDsGlassFillAlpha);

/// Hairline outline drawn over a translucent glass chip.
Border dsGlassChipBorder(DsTokens tokens) => Border.all(
  color: tokens.colors.decorative.level01.withValues(
    alpha: kDsGlassBorderAlpha,
  ),
);

/// Circular icon-only action button used on glass bars.
///
/// [backgroundColor] / [iconColor] are optional overrides; when null the
/// shared translucent glass-chip styling ([dsGlassChipFill] +
/// [dsGlassChipBorder]) is used so the silhouette and glyph stay visible
/// regardless of what's behind the bar. Callers that pass a solid
/// [backgroundColor] (e.g. an active/alert state) bring their own
/// contrast, so no hairline outline is drawn in that case.
class DsGlassRoundButton extends StatelessWidget {
  const DsGlassRoundButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.diameter = defaultDiameter,
    this.iconSize = defaultIconSize,
    super.key,
  });

  /// Default round-button diameter. Matches `tokens.spacing.step9` (48),
  /// the standard hit-target; the design system has no dedicated
  /// icon-button-size token.
  static const double defaultDiameter = 48;

  /// Default icon glyph size inside the round button.
  static const double defaultIconSize = 20;

  final IconData icon;
  final String semanticLabel;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double diameter;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final isTranslucent = backgroundColor == null;
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        // Background lives on [Ink] (not the inner Container) so the InkWell
        // splash/highlight renders above it instead of being obscured.
        child: Ink(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: backgroundColor ?? dsGlassChipFill(tokens),
            shape: BoxShape.circle,
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Container(
              width: diameter,
              height: diameter,
              // foregroundDecoration so the hairline outline doesn't eat
              // into the icon's content rect — keeps the glyph centred.
              foregroundDecoration: isTranslucent
                  ? BoxDecoration(
                      shape: BoxShape.circle,
                      border: dsGlassChipBorder(tokens),
                    )
                  : null,
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? tokens.colors.text.highEmphasis,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pill-shaped glass action button: an optional leading icon plus a label,
/// one tap target.
///
/// Idle/translucent (no [fillColor]): the shared glass-chip styling with a
/// hairline outline. Solid ([fillColor] set, e.g. the teal primary
/// action): a filled pill with no outline. [expand] stretches the pill to
/// fill its parent's width (centred content) for full-width primary
/// actions; otherwise the pill hugs its content.
///
/// When [enabled] is false the pill renders as a non-actionable affordance:
/// the solid [fillColor] is dropped for the translucent glass treatment, the
/// foreground dims to `text.lowEmphasis`, [onTap] is not wired, and the
/// `Semantics` node reports `enabled: false` so assistive tech doesn't
/// announce it as a live button.
class DsGlassPill extends StatelessWidget {
  const DsGlassPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.fillColor,
    this.foregroundColor,
    this.semanticLabel,
    this.expand = false,
    this.enabled = true,
    this.height = defaultHeight,
    this.iconSize = DsGlassRoundButton.defaultIconSize,
    super.key,
  });

  /// Default pill height — matches [DsGlassRoundButton.defaultDiameter] so
  /// a pill and round buttons line up on the same action row.
  static const double defaultHeight = DsGlassRoundButton.defaultDiameter;

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? fillColor;
  final Color? foregroundColor;
  final String? semanticLabel;
  final bool expand;
  final bool enabled;
  final double height;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final spacing = tokens.spacing;
    // Disabled pills drop any solid fill for the translucent glass treatment
    // and dim the foreground, so they read as non-actionable.
    final effectiveFill = enabled ? fillColor : null;
    final isTranslucent = effectiveFill == null;
    final foreground = enabled
        ? (foregroundColor ?? tokens.colors.text.highEmphasis)
        : tokens.colors.text.lowEmphasis;
    final pillRadius = BorderRadius.circular(tokens.radii.badgesPills);
    final textStyle = tokens.typography.styles.subtitle.subtitle2.copyWith(
      color: foreground,
    );

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: foreground),
          SizedBox(width: spacing.step2),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        // Background lives on [Ink] (not the inner Container) so the InkWell
        // splash/highlight renders above it instead of being obscured.
        child: Ink(
          height: height,
          width: expand ? double.infinity : null,
          decoration: BoxDecoration(
            color: effectiveFill ?? dsGlassChipFill(tokens),
            borderRadius: pillRadius,
          ),
          child: InkWell(
            borderRadius: pillRadius,
            onTap: enabled ? onTap : null,
            child: Container(
              height: height,
              width: expand ? double.infinity : null,
              padding: EdgeInsets.symmetric(horizontal: spacing.step5),
              // foregroundDecoration keeps the hairline a hairline without
              // widening the pill (which would shift action-row layout).
              foregroundDecoration: isTranslucent
                  ? BoxDecoration(
                      borderRadius: pillRadius,
                      border: dsGlassChipBorder(tokens),
                    )
                  : null,
              child: Center(widthFactor: expand ? null : 1, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
