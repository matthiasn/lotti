import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/motion/staggered_entrance.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/aurora_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/crystallize_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/neural_constellation.dart';
import 'package:lotti/features/onboarding/ui/widgets/waveform_text_hero.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The candidate animated welcome heroes. The active one is chosen via
/// [OnboardingHeroPanel.heroStyle]; the debug animation gallery lets all of
/// them be compared live (look + motion) before committing to one.
enum OnboardingHeroStyle {
  /// Drifting "external brain" node network with a travelling thought pulse.
  constellation,

  /// Spoken phrases that crystallize into a structured checklist card.
  crystallize,

  /// Slow flowing aurora of additive colour blooms.
  aurora,

  /// A luminous voice waveform that resolves into a typed task title.
  waveform;

  String get label => switch (this) {
    OnboardingHeroStyle.constellation => 'Constellation',
    OnboardingHeroStyle.crystallize => 'Crystallize',
    OnboardingHeroStyle.aurora => 'Aurora',
    OnboardingHeroStyle.waveform => 'Waveform',
  };
}

/// The aurora bloom palette derived from the brand accent (teal family), shared
/// by the welcome hero and the connect-page backdrop.
List<Color> onboardingAuroraColors(Color accent) {
  final base = HSLColor.fromColor(accent);
  return [
    accent,
    base.withHue((base.hue + 28) % 360).toColor(),
    base
        .withHue((base.hue - 36) % 360)
        .withLightness((base.lightness + 0.08).clamp(0.0, 1.0))
        .toColor(),
  ];
}

/// The shared alive dark backdrop for the connect + API-key pages: a toned-down
/// aurora wash layered under the neural constellation, on the dark panel
/// background. Keeps the post-welcome steps as alive as the welcome itself.
///
/// [accent] tints the aurora + constellation; it defaults to the brand teal but
/// the API-key step passes the chosen provider's brand colour so the backdrop
/// shifts to that provider's hue once the user has picked one.
class OnboardingBackdrop extends StatelessWidget {
  const OnboardingBackdrop({this.nodeCount = 26, this.accent, super.key});

  final int nodeCount;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent ?? dsTokensDark.colors.interactive.enabled;
    // The motion stays (it carries the welcome's "alive" thread forward) but is
    // toned down behind the working steps so it never competes with the tiles
    // / key field the user is reading and typing into — the review panels'
    // dominant note. Lower aurora wash + dimmer nodes/lines + a calmer pulse.
    return ColoredBox(
      color: dsTokensDark.colors.background.level01,
      child: Stack(
        fit: StackFit.expand,
        children: [
          AuroraHero(
            colors: onboardingAuroraColors(accentColor),
            maxAlpha: 0.09,
          ),
          NeuralConstellation(
            nodeColor: accentColor.withValues(alpha: 0.30),
            lineColor: accentColor.withValues(alpha: 0.10),
            // The working-step backdrop should stay alive but recede behind
            // provider tiles / key fields, so it is smaller, dimmer and uses
            // fewer travelling activations than the welcome hero.
            pulseColor: Color.lerp(
              accentColor,
              dsTokensDark.colors.text.highEmphasis,
              0.42,
            )!.withValues(alpha: 0.36),
            nodeCount: nodeCount,
            pulseCount: 2,
            glow: 0.28,
            compositionScale: 0.78,
            compositionOffset: const Offset(0, -0.18),
            loop: const Duration(seconds: 14),
          ),
          const _BackdropContentScrim(),
        ],
      ),
    );
  }
}

/// Keeps later onboarding steps quiet enough for form controls: the organism is
/// still alive, but it fades before it sits under titles, cards, and text fields.
class _BackdropContentScrim extends StatelessWidget {
  const _BackdropContentScrim();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              dsTokensDark.colors.background.level01.withValues(alpha: 0.42),
              dsTokensDark.colors.background.level01.withValues(alpha: 0.86),
              dsTokensDark.colors.background.level01.withValues(alpha: 0.92),
            ],
            stops: const [0, 0.14, 0.34, 1],
          ),
        ),
      ),
    );
  }
}

/// Builds the animated visual for [style], coloured from the dark token set so
/// it reads on the cinematic dark panel regardless of the app's theme.
Widget buildOnboardingHeroVisual(OnboardingHeroStyle style) {
  final accent = dsTokensDark.colors.interactive.enabled;
  switch (style) {
    case OnboardingHeroStyle.constellation:
      return NeuralConstellation(
        nodeColor: accent,
        lineColor: accent.withValues(alpha: 0.6),
        pulseColor: Color.lerp(
          accent,
          dsTokensDark.colors.text.highEmphasis,
          0.45,
        )!,
        nodeCount: 62,
        // The welcome page is the only place where the organism should own the
        // opening beat. Later FTUE pages use OnboardingBackdrop's smaller,
        // dimmer values so form controls stay dominant.
        glow: 0.9,
        compositionScale: 1.32,
        compositionOffset: const Offset(0, 0.02),
        vineCount: 3,
        entanglement: 0.64,
      );
    case OnboardingHeroStyle.crystallize:
      return CrystallizeHero(
        accent: accent,
        cardColor: dsTokensLight.colors.background.level01,
        onCardColor: dsTokensLight.colors.text.highEmphasis,
        ghostColor: dsTokensDark.colors.text.mediumEmphasis,
        title: 'Car & health errands',
        items: const ['Call the dentist', 'Book the car service'],
        spokenLines: const [
          '"remind me to call the dentist"',
          '"and book the car service"',
        ],
        loop: true,
      );
    case OnboardingHeroStyle.aurora:
      return AuroraHero(colors: onboardingAuroraColors(accent));
    case OnboardingHeroStyle.waveform:
      return WaveformTextHero(
        waveColor: accent,
        textColor: dsTokensDark.colors.text.highEmphasis,
      );
  }
}

/// Composes the hero artwork into the modal instead of letting it end as a hard
/// strip above the copy. The overlays are panel-coloured fades, so the underlying
/// animation topology stays unchanged while edge clipping and the title boundary
/// are softened.
class _HeroArtworkFrame extends StatelessWidget {
  const _HeroArtworkFrame({required this.backgroundColor, required this.child});

  final Color backgroundColor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _HeroCloudWash(backgroundColor: backgroundColor),
        child,
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  backgroundColor.withValues(alpha: 0.52),
                  Colors.transparent,
                  Colors.transparent,
                  backgroundColor.withValues(alpha: 0.34),
                ],
                stops: const [0, 0.14, 0.84, 1],
              ),
            ),
          ),
        ),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  backgroundColor.withValues(alpha: 0.58),
                  backgroundColor,
                ],
                stops: const [0, 0.58, 0.78, 1],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCloudWash extends StatelessWidget {
  const _HeroCloudWash({required this.backgroundColor});

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final lifted = Color.lerp(
      backgroundColor,
      dsTokensDark.colors.background.level02,
      0.78,
    )!;
    final softLifted = Color.lerp(
      backgroundColor,
      dsTokensDark.colors.background.level02,
      0.38,
    )!;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.24, -0.18),
            radius: 0.92,
            colors: [
              lifted.withValues(alpha: 0.74),
              softLifted.withValues(alpha: 0.34),
              backgroundColor.withValues(alpha: 0),
            ],
            stops: const [0, 0.48, 1],
          ),
        ),
      ),
    );
  }
}

/// The cinematic welcome content: an always-dark rounded panel with the
/// animated [heroStyle] hero filling the upper region and the promise + CTA +
/// skip below. Always dark (uses the dark token set) so the intro feels like a
/// deliberate, premium takeover in both light and dark app themes.
class OnboardingHeroPanel extends StatelessWidget {
  const OnboardingHeroPanel({
    required this.onConnect,
    required this.onSkip,
    this.heroStyle = OnboardingHeroStyle.constellation,
    this.heroHeight = 276,
    super.key,
  });

  final OnboardingHeroStyle heroStyle;
  final VoidCallback onConnect;
  final VoidCallback onSkip;
  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final panelBg = dsTokensDark.colors.background.level01;
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMed = dsTokensDark.colors.text.mediumEmphasis;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: ColoredBox(
        color: panelBg,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: heroHeight,
              width: double.infinity,
              child: OverflowBox(
                alignment: Alignment.topCenter,
                maxHeight: heroHeight + tokens.spacing.step5,
                child: SizedBox(
                  height: heroHeight + tokens.spacing.step5,
                  width: double.infinity,
                  child: _HeroArtworkFrame(
                    backgroundColor: panelBg,
                    child: buildOnboardingHeroVisual(heroStyle),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step4,
                tokens.spacing.step5,
                // Clear the home indicator when flush to the screen bottom as a
                // full-width sheet; 0 in the centred dialog / gallery contexts.
                tokens.spacing.step5 + MediaQuery.paddingOf(context).bottom,
              ),
              child: StaggeredEntrance(
                crossAxisAlignment: CrossAxisAlignment.center,
                duration: MotionDurations.short4,
                initialOpacity: 1,
                interval: const Duration(milliseconds: 34),
                rise: tokens.spacing.step2,
                children: [
                  Text(
                    context.messages.onboardingWelcomeTitle,
                    textAlign: TextAlign.center,
                    // heading1 (the display tier of this flow) so the promise
                    // clearly out-ranks the step titles (heading3) — and the
                    // larger size wraps earlier, fixing the orphaned "plan.".
                    style: tokens.typography.styles.heading.heading1.copyWith(
                      color: textHigh,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step3),
                    child: Text(
                      context.messages.onboardingWelcomeMessage,
                      textAlign: TextAlign.center,
                      style: tokens.typography.styles.body.bodyLarge.copyWith(
                        color: textMed,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step6),
                    child: DesignSystemButton(
                      onPressed: onConnect,
                      label: context.messages.onboardingWelcomeConnectButton,
                      leadingIcon: Icons.arrow_forward_rounded,
                      size: DesignSystemButtonSize.large,
                      fullWidth: true,
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: tokens.spacing.step2),
                    child: DesignSystemButton(
                      onPressed: onSkip,
                      label: context.messages.onboardingWelcomeSkipButton,
                      variant: DesignSystemButtonVariant.tertiary,
                      size: DesignSystemButtonSize.large,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
