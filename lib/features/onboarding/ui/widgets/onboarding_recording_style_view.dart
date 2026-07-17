import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/onboarding/ui/widgets/recording_style_picker.dart';

/// The "pick your recording look" step: the user chooses between two themed
/// pairs of live recording visualizers, previewed alive on one page, via
/// [RecordingStylePicker].
///
/// Presentational + injected: the live level ([vu], [dBFS], [amplitudes]) is fed
/// in by the host (a looping simulated signal by default, or the real mic when
/// [tryingWithVoice] is on), so it renders identically live and in review.
class OnboardingRecordingStyleView extends StatelessWidget {
  const OnboardingRecordingStyleView({
    required this.accent,
    required this.colorScheme,
    required this.title,
    required this.explanation,
    required this.analogueLabel,
    required this.modernLabel,
    required this.tryWithVoiceLabel,
    required this.continueLabel,
    required this.selected,
    required this.onSelect,
    required this.tryingWithVoice,
    required this.onToggleTryWithVoice,
    required this.onContinue,
    required this.vu,
    required this.dBFS,
    required this.amplitudes,
    super.key,
  });

  final Color accent;

  /// Colour scheme handed to the theme-adaptive analog VU meter.
  final ColorScheme colorScheme;

  final String title;
  final String explanation;
  final String analogueLabel;
  final String modernLabel;
  final String tryWithVoiceLabel;
  final String continueLabel;

  /// Currently selected style.
  final RecordingStyle selected;
  final void Function(RecordingStyle style) onSelect;

  /// Whether the previews are being driven by the live mic.
  final bool tryingWithVoice;
  final ValueChanged<bool> onToggleTryWithVoice;

  final VoidCallback onContinue;

  /// Live level the previews react to (VU dB, instantaneous dBFS, and a
  /// normalized amplitude window for the waveform bars).
  final double vu;
  final double dBFS;
  final List<double> amplitudes;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final textHigh = tokens.colors.text.highEmphasis;
    final textMedium = tokens.colors.text.mediumEmphasis;
    final panelBg = tokens.colors.background.level01;

    return ClipRRect(
      borderRadius: BorderRadius.circular(tokens.radii.l),
      child: Stack(
        children: [
          const Positioned.fill(child: OnboardingBackdrop()),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    panelBg.withValues(alpha: 0.2),
                    panelBg.withValues(alpha: 0.62),
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
                SizedBox(height: tokens.spacing.step5),
                RecordingStylePicker(
                  accent: accent,
                  colorScheme: colorScheme,
                  surfaceTokens: tokens,
                  analogueLabel: analogueLabel,
                  modernLabel: modernLabel,
                  tryWithVoiceLabel: tryWithVoiceLabel,
                  selected: selected,
                  onSelect: onSelect,
                  tryingWithVoice: tryingWithVoice,
                  onToggleTryWithVoice: onToggleTryWithVoice,
                  vu: vu,
                  dBFS: dBFS,
                  amplitudes: amplitudes,
                ),
                SizedBox(height: tokens.spacing.step5),
                DesignSystemButton(
                  label: continueLabel,
                  onPressed: onContinue,
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
