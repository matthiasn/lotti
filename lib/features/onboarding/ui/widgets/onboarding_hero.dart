import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/components/motion/staggered_entrance.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/neural_constellation.dart';
import 'package:lotti/l10n/app_localizations_context.dart';

/// The cinematic welcome content: an always-dark rounded panel with the
/// animated neural-constellation hero ("your external brain, alive") filling
/// the upper region and the promise + CTA + skip below.
///
/// Always dark (uses the dark token set) so the intro feels like a deliberate,
/// premium takeover in both light and dark app themes.
class OnboardingHeroPanel extends StatelessWidget {
  const OnboardingHeroPanel({
    required this.onConnect,
    required this.onSkip,
    this.heroHeight = 264,
    super.key,
  });

  final VoidCallback onConnect;
  final VoidCallback onSkip;
  final double heroHeight;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final accent = dsTokensDark.colors.interactive.enabled;
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
              child: NeuralConstellation(
                nodeColor: accent,
                lineColor: accent.withValues(alpha: 0.5),
                pulseColor: Color.lerp(accent, Colors.white, 0.45)!,
              ),
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
                    style: tokens.typography.styles.heading.heading2.copyWith(
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
