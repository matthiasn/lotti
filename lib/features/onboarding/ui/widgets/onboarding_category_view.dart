import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';

/// Backdrop blur strength for the frosted-glass category chips. Sits within
/// the codebase's glass-surface range (10–20); chip-sized blurs use a softer
/// sigma than the wide sticky action strip (`DesignSystemGlassStrip`, 20).
const double _kChipBlurSigma = 14;

/// The unselected option chips are *tinted* glass: a teal wash lives IN the
/// chip material as a vertical gradient — brighter at the top, like glass
/// catching light from above, fading down. Painted over the [BackdropFilter],
/// it makes the chip read as colour-tinted frosted glass against the dark
/// backdrop instead of the flat neutral grey that an earlier white-sheen +
/// dark-wash fill produced (the colour has to be in the material; relying on a
/// glow transmitting through a neutral pane read as dead grey). Kept well below
/// a solid fill so the blurred ambient glow + constellation still show through,
/// but saturated enough that the teal reads as *lit* glass rather than a tint
/// over near-black (a too-dark tint read as muted/quiet in review).
const double _kChipTintTopAlpha = 0.36;
const double _kChipTintBottomAlpha = 0.18;

/// The "+ Add your own" chip shares the same teal glass, but at a quieter tint
/// so it recedes below the real options — same hue, less presence, never a
/// *different* grey that competes with the primary CTA.
const double _kAddOwnTintTopAlpha = 0.14;
const double _kAddOwnTintBottomAlpha = 0.05;

/// Crisp white hairline that defines the glass edge and catches light — bright
/// enough that the unselected chips' tap-target boundary is unmistakable
/// against the dark gradient (the low-vision soft spot in review). The add-own
/// chip uses a quieter hairline to match its lower tint.
const double _kChipBorderAlpha = 0.44;
const double _kAddOwnBorderAlpha = 0.24;

/// Ambient-glow opacities. Kept low so the layer reads as a premium colour
/// wash the frosted chips can pick up, never a garish rainbow. The teal is the
/// brand-led primary; the cooler companion is more restrained still.
const double _kGlowTealAlpha = 0.28;
const double _kGlowCoolAlpha = 0.18;

/// Feathering blur applied to the whole ambient-glow layer, on top of the
/// already heavily-feathered radial gradients, so the glows melt together into
/// a soft wash with no hard radial edge.
const double _kGlowBlurSigma = 60;

/// A selectable life-area option on the category step.
@immutable
class OnboardingCategoryOption {
  const OnboardingCategoryOption({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// The "where should this brain work?" step: the user picks one or more life
/// areas (Work / Fitness / Family / Friends …) that the just-connected provider
/// should power. It teaches the app's core model — *which AI runs is chosen per
/// category* — instead of silently creating a throwaway "Test Category".
///
/// A natural-height panel (sits in the modal scroll view) over the shared alive
/// backdrop; the option chips arrive on a staggered cascade. Selection state +
/// callbacks are injected so it renders identically live and in review.
class OnboardingCategoryView extends StatelessWidget {
  const OnboardingCategoryView({
    required this.accent,
    required this.title,
    required this.explanation,
    required this.whyLabel,
    required this.continueLabel,
    required this.addOwnLabel,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.onWhy,
    required this.onAddOwn,
    required this.onContinue,
    super.key,
  });

  final Color accent;

  /// "Where should your AI work?"
  final String title;

  /// Benefit-led lead copy (keeps each area separate). The per-category-AI
  /// mechanism lives behind [whyLabel] / [onWhy], not in the lead.
  final String explanation;

  /// Label for the "why areas?" disclosure.
  final String whyLabel;

  final String continueLabel;
  final String addOwnLabel;

  final List<OnboardingCategoryOption> options;

  /// Labels currently selected.
  final Set<String> selected;

  final void Function(String label) onToggle;
  final VoidCallback onWhy;
  final VoidCallback onAddOwn;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final panelBg = dsTokensDark.colors.background.level01;
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMedium = dsTokensDark.colors.text.mediumEmphasis;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          const Positioned.fill(child: OnboardingBackdrop()),
          // Ambient colour wash, painted above the (sparse, near-black)
          // constellation backdrop but below the scrim + content. The frosted
          // chips blur whatever sits behind them; without this the blur had
          // only near-black to frost, so the glass read milky. These soft
          // brand-led glows give the chips real colour to pick up.
          Positioned.fill(child: _AmbientGlow(accent: accent)),
          // Soft scrim only: the drifting constellation + ambient glow stay
          // visible behind the frosted-glass chips (which carry their own
          // local legibility via backdrop blur), while the lower CTA area
          // keeps a little backing so the primary button reads cleanly.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0.1),
                    panelBg.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step6,
              tokens.spacing.step5,
              tokens.spacing.step6 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: tokens.typography.styles.heading.heading3.copyWith(
                    color: textHigh,
                  ),
                ),
                SizedBox(height: tokens.spacing.step2),
                Text(
                  explanation,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: textMedium,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: onWhy,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: tokens.spacing.step2,
                      ),
                      child: Text(
                        whyLabel,
                        style: tokens.typography.styles.body.bodySmall.copyWith(
                          color: accent,
                          decoration: TextDecoration.underline,
                          decorationColor: accent,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                _CategoryGrid(
                  tokens: tokens,
                  accent: accent,
                  options: options,
                  selected: selected,
                  onToggle: onToggle,
                  addOwnLabel: addOwnLabel,
                  onAddOwn: onAddOwn,
                ),
                SizedBox(height: tokens.spacing.step6),
                DesignSystemButton(
                  label: continueLabel,
                  onPressed: selected.isEmpty ? null : onContinue,
                  fullWidth: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A soft ambient colour wash concentrated behind the chip-grid region so the
/// frosted-glass chips have rich brand-led colour to blur (the fix for the
/// milky frost over the near-black constellation backdrop).
///
/// Two heavily-feathered radial glows, blurred again as a layer so they melt
/// into one premium wash rather than reading as two discrete blobs:
///  * a teal [accent] glow (the brand-led primary) centred left-of-centre in
///    the chip region, and
///  * one restrained cooler companion — the cyan-blue hue from
///    [onboardingAuroraColors] — centred lower-right.
///
/// Both stay low-opacity and very soft: an ambient wash, not a rainbow. The
/// constellation still sparkles on top of it.
class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    // The cooler companion: the +28° (cyan-blue) hue from the shared aurora
    // palette, so the wash stays inside the brand family.
    final cool = onboardingAuroraColors(accent)[1];

    return ImageFiltered(
      imageFilter: ui.ImageFilter.blur(
        sigmaX: _kGlowBlurSigma,
        sigmaY: _kGlowBlurSigma,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Teal brand glow: left-of-centre, sitting over the chip region.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.55, 0.15),
                radius: 0.95,
                colors: [
                  accent.withValues(alpha: _kGlowTealAlpha),
                  accent.withValues(alpha: 0),
                ],
                stops: const [0, 1],
              ),
            ),
          ),
          // Cooler companion glow: lower-right, restrained.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.7, 0.55),
                radius: 0.9,
                colors: [
                  cool.withValues(alpha: _kGlowCoolAlpha),
                  cool.withValues(alpha: 0),
                ],
                stops: const [0, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A tidy uniform grid of selectable area chips: the options laid out in rows
/// of two equal-width cells (`Expanded`), with the "+ Add your own" chip on its
/// own full-width row below. Every chip shares the same height + padding so the
/// grid never looks ragged (the review-panel blocker). An odd final option pairs
/// with an empty spacer so the column edges stay aligned.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.tokens,
    required this.accent,
    required this.options,
    required this.selected,
    required this.onToggle,
    required this.addOwnLabel,
    required this.onAddOwn,
  });

  final DsTokens tokens;
  final Color accent;
  final List<OnboardingCategoryOption> options;
  final Set<String> selected;
  final void Function(String label) onToggle;
  final String addOwnLabel;
  final VoidCallback onAddOwn;

  @override
  Widget build(BuildContext context) {
    final gap = tokens.spacing.step3;
    final rows = <Widget>[];
    for (var i = 0; i < options.length; i += 2) {
      if (i > 0) rows.add(SizedBox(height: gap));
      final left = options[i];
      final right = i + 1 < options.length ? options[i + 1] : null;
      rows.add(
        Row(
          children: [
            Expanded(
              child: _CategoryChip(
                tokens: tokens,
                accent: accent,
                option: left,
                selected: selected.contains(left.label),
                onTap: () => onToggle(left.label),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: right == null
                  ? const SizedBox.shrink()
                  : _CategoryChip(
                      tokens: tokens,
                      accent: accent,
                      option: right,
                      selected: selected.contains(right.label),
                      onTap: () => onToggle(right.label),
                    ),
            ),
          ],
        ),
      );
    }
    if (rows.isNotEmpty) rows.add(SizedBox(height: gap));
    rows.add(
      _AddOwnChip(
        tokens: tokens,
        accent: accent,
        label: addOwnLabel,
        onTap: onAddOwn,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows,
    );
  }
}

/// A frosted-glass surface: a [BackdropFilter] blur clipped to [radius] under a
/// teal [tint] that lives in the material as a vertical gradient ([topAlpha] →
/// [bottomAlpha], brighter at the top so the glass reads as catching light) and
/// a crisp hairline ([borderColor]). The tint is what makes the chip read as
/// *colour-tinted* glass over the dark backdrop rather than flat neutral grey;
/// it stays translucent so the blurred ambient glow + constellation still show
/// through. Shared by the option chips and the "+ Add your own" chip so they
/// read as one glass family (only the tint strength + content differ).
class _FrostedGlass extends StatelessWidget {
  const _FrostedGlass({
    required this.tint,
    required this.topAlpha,
    required this.bottomAlpha,
    required this.borderColor,
    required this.radius,
    required this.child,
  });

  final Color tint;
  final double topAlpha;
  final double bottomAlpha;
  final Color borderColor;
  final BorderRadius radius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(
          sigmaX: _kChipBlurSigma,
          sigmaY: _kChipBlurSigma,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                tint.withValues(alpha: topAlpha),
                tint.withValues(alpha: bottomAlpha),
              ],
            ),
            borderRadius: radius,
            border: Border.all(color: borderColor),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// One uniform area chip. Unselected reads as *available* teal-tinted glass — a
/// backdrop-blurred surface under a translucent teal gradient + crisp white
/// hairline, so it reads as coloured frosted glass (the brand teal lives in the
/// material) while the enriched backdrop still shows through. A bright-mint
/// leading icon and a full-white label sit on top. Selected fills solid brand
/// (no blur — the chosen state should pop) and gains a trailing check with a
/// dark icon + label.
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.tokens,
    required this.accent,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final DsTokens tokens;
  final Color accent;
  final OnboardingCategoryOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final panelBg = dsTokensDark.colors.background.level01;
    final fg = selected ? panelBg : textHigh;
    final radius = BorderRadius.circular(tokens.radii.m);
    final padding = EdgeInsets.symmetric(
      horizontal: tokens.spacing.step4,
      vertical: tokens.spacing.step4,
    );

    final row = Row(
      children: [
        // The category icon gives each chip identity; a bright mint on the
        // frosted surface (legible brand pop), dark once it fills solid.
        Icon(
          option.icon,
          size: tokens.spacing.step5,
          color: selected
              ? fg
              : Color.lerp(accent, const Color(0xFFFFFFFF), 0.35),
        ),
        SizedBox(width: tokens.spacing.step3),
        Expanded(
          child: Text(
            option.label,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodyLarge.copyWith(color: fg),
          ),
        ),
        // Trailing check is the non-colour selection cue (accessibility).
        if (selected) ...[
          SizedBox(width: tokens.spacing.step2),
          Icon(Icons.check_rounded, size: tokens.spacing.step5, color: fg),
        ],
      ],
    );

    // Selected pops as a solid brand fill (no blur). Unselected is teal-tinted
    // frosted glass via [_FrostedGlass]: the blur lets the enriched backdrop
    // (ambient glow + constellation) read through, and the teal tint in the
    // material is what makes it read as *coloured* frosted glass rather than
    // the flat neutral grey an earlier neutral fill produced. The chip sits
    // dark over the dark backdrop, so the full-white label stays AA-legible
    // with no extra wash.
    final body = selected
        ? DecoratedBox(
            decoration: BoxDecoration(
              color: accent,
              borderRadius: radius,
              border: Border.all(color: accent),
            ),
            child: Padding(padding: padding, child: row),
          )
        : _FrostedGlass(
            tint: accent,
            topAlpha: _kChipTintTopAlpha,
            bottomAlpha: _kChipTintBottomAlpha,
            borderColor: textHigh.withValues(alpha: _kChipBorderAlpha),
            radius: radius,
            child: Padding(padding: padding, child: row),
          );

    return Semantics(
      button: true,
      selected: selected,
      label: option.label,
      child: GestureDetector(onTap: onTap, child: body),
    );
  }
}

/// The full-width "+ Add your own" chip. Shares the option chips' height +
/// padding and the same [_FrostedGlass] treatment, so the grid reads as one
/// glass family, but at a quieter teal tint + hairline and with a dimmer
/// icon/label, so it recedes as the secondary "add" action rather than reading
/// as a peer option (or a *different* grey competing with the primary CTA).
class _AddOwnChip extends StatelessWidget {
  const _AddOwnChip({
    required this.tokens,
    required this.accent,
    required this.label,
    required this.onTap,
  });

  final DsTokens tokens;
  final Color accent;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMedium = dsTokensDark.colors.text.mediumEmphasis;
    final radius = BorderRadius.circular(tokens.radii.m);
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: _FrostedGlass(
          tint: accent,
          topAlpha: _kAddOwnTintTopAlpha,
          bottomAlpha: _kAddOwnTintBottomAlpha,
          borderColor: textHigh.withValues(alpha: _kAddOwnBorderAlpha),
          radius: radius,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: tokens.spacing.step4,
              vertical: tokens.spacing.step4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_rounded,
                  size: tokens.spacing.step5,
                  color: textMedium,
                ),
                SizedBox(width: tokens.spacing.step2),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: tokens.typography.styles.body.bodyLarge.copyWith(
                      color: textMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
