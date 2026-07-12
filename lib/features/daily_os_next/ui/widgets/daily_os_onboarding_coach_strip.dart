import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/glass_strip.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// A small, static glass banner that narrates one beat of the Daily OS
/// onboarding walkthrough inside the real create modal (Capture / Reconcile /
/// Drafting).
///
/// Presentational only: the [message] copy and the optional "hide tips"
/// affordance are injected, so the strip carries no session or metrics logic of
/// its own and stays trivially testable. It is deliberately static — no shimmer
/// or entrance animation — so it needs no reduced-motion branch and never
/// competes with the real modal content for attention.
class DailyOsOnboardingCoachStrip extends StatelessWidget {
  const DailyOsOnboardingCoachStrip({
    required this.message,
    this.onHide,
    this.hideLabel,
    super.key,
  }) : assert(
         onHide == null || hideLabel != null,
         'hideLabel is required when onHide is provided',
       );

  /// The one-line coaching sentence for this beat.
  final String message;

  /// Invoked when the user hides coaching for the rest of the session. When
  /// null, no hide affordance is shown.
  final VoidCallback? onHide;

  /// Localized label for the hide affordance. Required when [onHide] is set.
  final String? hideLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    return DesignSystemGlassStrip(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacing.step5,
          vertical: tokens.spacing.step3,
        ),
        child: Row(
          children: [
            Icon(
              Icons.tips_and_updates_outlined,
              size: 16,
              color: tokens.colors.interactive.enabled,
            ),
            SizedBox(width: tokens.spacing.step3),
            Expanded(
              child: Text(
                message,
                style: tokens.typography.styles.body.bodySmall.copyWith(
                  color: tokens.colors.text.mediumEmphasis,
                ),
              ),
            ),
            if (onHide != null) ...[
              SizedBox(width: tokens.spacing.step2),
              TextButton(
                onPressed: onHide,
                child: Text(
                  hideLabel!,
                  style: tokens.typography.styles.body.bodySmall.copyWith(
                    color: tokens.colors.text.lowEmphasis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
