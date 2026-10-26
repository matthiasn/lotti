import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/nudges/ui/nudge_banner_style.dart';
import 'package:material_ui/material_ui.dart';

/// The monogram identity chip: a letter on a tinted [fill] wash. Typography
/// and colour only — no faces, no imagery (ADR 0058 holds even for
/// identity). Shared by the banner card, the dock and the agents list; the
/// caller supplies the wash (an accent on banners, the health hue on the
/// list row).
class NudgeBannerPersonaChip extends StatelessWidget {
  const NudgeBannerPersonaChip({
    required this.monogram,
    required this.fill,
    super.key,
  });

  /// Convenience: the persona chip for a [NudgeBannerStyle] — the accent's
  /// 22% chip wash.
  NudgeBannerPersonaChip.forStyle({
    required this.monogram,
    required NudgeBannerStyle style,
    super.key,
  }) : fill = style.chipFill;

  /// Derives the monogram for a goal/persona title.
  static String monogramFor(String title) =>
      title.isEmpty ? '·' : title.characters.first.toUpperCase();

  final String monogram;
  final Color fill;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    // The circle grows with the text scale so the monogram never outgrows
    // its bounds at large accessibility sizes (2×–3×) and bleeds into the
    // adjacent headline.
    final size =
        tokens.spacing.step6 * MediaQuery.textScalerOf(context).scale(1);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
      child: Text(
        monogram,
        // High-emphasis, not the raw accent: the accent as 12px text over
        // its own 22% wash drops below the 4.5:1 contrast floor on light
        // accents (e.g. warning). The chip keeps its accent identity
        // through the wash; the glyph stays readable in both themes.
        style: tokens.typography.styles.others.overline.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }
}

/// The one pressable-looking element that is actually pressable: the
/// accent-washed CTA pill, edged in the accent at full strength — the only
/// place on a banner the hue appears undiluted, which is what makes it the
/// primary at a glance and keeps figure-ground on the light theme's paler
/// wash. Its pointer target is the same [TapTargets.minimum] floor the
/// quiet pair stands on, with the visible pill centred in it — the
/// design-system button's padded-target pattern. Shared by the banner card
/// and the dock.
class NudgeBannerCtaPill extends StatelessWidget {
  const NudgeBannerCtaPill({
    required this.label,
    required this.style,
    required this.onTap,
    super.key,
  });

  final String label;
  final NudgeBannerStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    // The whole floor is the target, not just the painted pill: the pill's
    // own InkWell wins the arena inside it and carries the ink; a tap in
    // the slot's slack around it lands here.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: TapTargets.minimum,
          minHeight: TapTargets.minimum,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: Material(
            color: Colors.transparent,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                color: style.controlFill,
                borderRadius: radius,
                border: Border.all(color: style.accent),
              ),
              child: InkWell(
                borderRadius: radius,
                onTap: onTap,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: tokens.spacing.step4,
                    vertical: tokens.spacing.step3,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    // High-emphasis over the accent wash — same contrast reason as
                    // the persona monogram. The pill reads as accent through its
                    // fill; the label stays legible on light accents.
                    style: tokens.typography.styles.subtitle.subtitle2.copyWith(
                      color: tokens.colors.text.highEmphasis,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
