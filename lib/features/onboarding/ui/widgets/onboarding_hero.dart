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
            maxAlpha: 0.10,
          ),
          NeuralConstellation(
            nodeColor: accentColor.withValues(alpha: 0.62),
            lineColor: accentColor.withValues(alpha: 0.32),
            pulseColor: Color.lerp(
              accentColor,
              Colors.white,
              0.35,
            )!.withValues(alpha: 0.7),
            nodeCount: nodeCount,
          ),
        ],
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
        pulseColor: Color.lerp(accent, Colors.white, 0.45)!,
        nodeCount: 30,
        // Tame the brightest blooms ~20% so the hero supports the promise
        // headline rather than out-shouting it (design-panel call).
        glow: 0.8,
      );
    case OnboardingHeroStyle.crystallize:
      return CrystallizeHero(
        accent: accent,
        cardColor: dsTokensLight.colors.background.level01,
        onCardColor: dsTokensLight.colors.text.highEmphasis,
        ghostColor: dsTokensDark.colors.text.mediumEmphasis,
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

/// The cinematic welcome content: an always-dark rounded panel with the
/// animated [heroStyle] hero filling the upper region and the promise + CTA +
/// skip below. Always dark (uses the dark token set) so the intro feels like a
/// deliberate, premium takeover in both light and dark app themes.
class OnboardingHeroPanel extends StatelessWidget {
  const OnboardingHeroPanel({
    required this.onConnect,
    required this.onSkip,
    this.heroStyle = OnboardingHeroStyle.constellation,
    this.heroHeight = 264,
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
              child: buildOnboardingHeroVisual(heroStyle),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                tokens.spacing.step5,
                tokens.spacing.step4,
                tokens.spacing.step5,
                tokens.spacing.step5,
              ),
              child: StaggeredEntrance(
                crossAxisAlignment: CrossAxisAlignment.center,
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
