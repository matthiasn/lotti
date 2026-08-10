import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/goals/ui/goal_banner_style.dart';

/// The monogram identity chip: accent letter on the accent's chip wash.
/// Typography and colour only — no faces, no imagery (ADR 0058 holds even
/// for identity). Shared by the banner card and the dock.
class GoalBannerPersonaChip extends StatelessWidget {
  const GoalBannerPersonaChip({
    required this.monogram,
    required this.style,
    super.key,
  });

  /// Derives the monogram for a goal/persona title.
  static String monogramFor(String title) =>
      title.isEmpty ? '·' : title.characters.first.toUpperCase();

  final String monogram;
  final GoalBannerStyle style;

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
      decoration: BoxDecoration(
        color: style.chipFill,
        shape: BoxShape.circle,
      ),
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
/// accent-washed CTA pill. Shared by the banner card and the dock.
class GoalBannerCtaPill extends StatelessWidget {
  const GoalBannerCtaPill({
    required this.label,
    required this.style,
    required this.onTap,
    super.key,
  });

  final String label;
  final GoalBannerStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final radius = BorderRadius.circular(tokens.radii.badgesPills);
    return Material(
      color: style.controlFill,
      borderRadius: radius,
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
    );
  }
}
