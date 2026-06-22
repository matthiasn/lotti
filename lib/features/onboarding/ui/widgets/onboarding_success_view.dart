import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';

/// The connect-success beat: a confident checkmark scales in over the shared
/// alive backdrop, then the promise headline + a single primary CTA onward.
/// Deliberately *not* a particle burst — that peak is reserved for the real
/// task payoff (the crystallize reveal); this is a calm, earned "you're in".
///
/// A natural-height panel (like the connect/key panels) so it sits inside the
/// modal's scroll view; strings + the continue callback are injected so it
/// renders identically under the real flow and in isolation for review.
class OnboardingSuccessView extends StatefulWidget {
  const OnboardingSuccessView({
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.continueLabel,
    required this.onContinue,
    super.key,
  });

  final Color accent;
  final String title;
  final String subtitle;
  final String continueLabel;
  final VoidCallback onContinue;

  @override
  State<OnboardingSuccessView> createState() => _OnboardingSuccessViewState();
}

class _OnboardingSuccessViewState extends State<OnboardingSuccessView>
    with SingleTickerProviderStateMixin {
  static const _checkSize = 88.0;

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionDurations.long2,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _controller.value = 1;
    } else if (_controller.status == AnimationStatus.dismissed) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

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
          // Bottom scrim so the CTA reads against the alive backdrop.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0),
                    panelBg.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacing.step5,
              tokens.spacing.step7,
              tokens.spacing.step5,
              tokens.spacing.step6 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = MotionCurves.emphasizedDecelerate.transform(
                        _controller.value,
                      );
                      return Opacity(
                        opacity: t,
                        child: Transform.scale(
                          scale: 0.7 + 0.3 * t,
                          child: child,
                        ),
                      );
                    },
                    child: _CheckMark(
                      size: _checkSize,
                      accent: widget.accent,
                      iconColor: panelBg,
                    ),
                  ),
                ),
                SizedBox(height: tokens.spacing.step6),
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.heading.heading2.copyWith(
                    color: textHigh,
                  ),
                ),
                SizedBox(height: tokens.spacing.step3),
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: tokens.typography.styles.body.bodyLarge.copyWith(
                    color: textMedium,
                  ),
                ),
                SizedBox(height: tokens.spacing.step7),
                DesignSystemButton(
                  label: widget.continueLabel,
                  onPressed: widget.onContinue,
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

class _CheckMark extends StatelessWidget {
  const _CheckMark({
    required this.size,
    required this.accent,
    required this.iconColor,
  });

  final double size;
  final Color accent;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.4),
            blurRadius: 40,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(Icons.check_rounded, size: size * 0.56, color: iconColor),
    );
  }
}
