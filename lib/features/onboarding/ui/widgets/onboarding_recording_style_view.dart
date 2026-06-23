import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/animation/ai_voice_input_shader.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/live_waveform.dart';
import 'package:lotti/features/design_system/components/buttons/design_system_button.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/onboarding/state/recording_style.dart';
import 'package:lotti/features/onboarding/ui/widgets/onboarding_hero.dart';
import 'package:lotti/features/speech/ui/widgets/recording/analog_vu_meter.dart';

/// The "pick your recording look" step: the user chooses between two themed
/// pairs of live recording visualizers, previewed alive on one page.
///
///  * **Analogue** — the skeuomorphic [AnalogVuMeter] + a neutral [LiveWaveform].
///  * **Modern** — the [AiVoiceInputShader] orb + a brand-tinted [LiveWaveform].
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

  /// Colour scheme handed to the analog VU meter (a dark scheme on the dark
  /// onboarding surface).
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
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final textMedium = dsTokensDark.colors.text.mediumEmphasis;
    final panelBg = dsTokensDark.colors.background.level01;

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
                _StyleCard(
                  tokens: tokens,
                  accent: accent,
                  label: modernLabel,
                  selected: selected == RecordingStyle.modern,
                  onTap: () => onSelect(RecordingStyle.modern),
                  preview: _ModernPair(
                    tokens: tokens,
                    accent: accent,
                    dBFS: dBFS,
                    amplitudes: amplitudes,
                  ),
                ),
                SizedBox(height: tokens.spacing.step4),
                _StyleCard(
                  tokens: tokens,
                  accent: accent,
                  label: analogueLabel,
                  selected: selected == RecordingStyle.analogue,
                  onTap: () => onSelect(RecordingStyle.analogue),
                  preview: _AnaloguePair(
                    tokens: tokens,
                    colorScheme: colorScheme,
                    vu: vu,
                    dBFS: dBFS,
                    amplitudes: amplitudes,
                  ),
                ),
                SizedBox(height: tokens.spacing.step5),
                _TryWithVoiceToggle(
                  tokens: tokens,
                  accent: accent,
                  label: tryWithVoiceLabel,
                  value: tryingWithVoice,
                  onChanged: onToggleTryWithVoice,
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

/// A tappable, selectable preview card: a label over the live preview, ringed
/// in [accent] when chosen.
class _StyleCard extends StatelessWidget {
  const _StyleCard({
    required this.tokens,
    required this.accent,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.preview,
  });

  final DsTokens tokens;
  final Color accent;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget preview;

  @override
  Widget build(BuildContext context) {
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    final radius = BorderRadius.circular(tokens.radii.m);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: dsTokensDark.colors.background.level02.withValues(
              alpha: selected ? 0.55 : 0.32,
            ),
            borderRadius: radius,
            border: Border.all(
              color: selected ? accent : textHigh.withValues(alpha: 0.18),
              width: selected ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(tokens.spacing.step4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      selected
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: tokens.spacing.step5,
                      color: selected
                          ? accent
                          : textHigh.withValues(alpha: 0.5),
                    ),
                    SizedBox(width: tokens.spacing.step3),
                    Text(
                      label,
                      style: tokens.typography.styles.subtitle.subtitle1
                          .copyWith(color: textHigh),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spacing.step4),
                Center(child: preview),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern pair: the energy-orb shader + a brand-tinted waveform.
class _ModernPair extends StatelessWidget {
  const _ModernPair({
    required this.tokens,
    required this.accent,
    required this.dBFS,
    required this.amplitudes,
  });

  final DsTokens tokens;
  final Color accent;
  final double dBFS;
  final List<double> amplitudes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AiVoiceInputShader(
          dbfs: dBFS,
          size: tokens.spacing.step12,
          primaryColor: accent,
          secondaryColor: dsTokensDark.colors.text.highEmphasis,
          backgroundColor: const Color(0x00000000),
        ),
        SizedBox(height: tokens.spacing.step3),
        LiveWaveform(amplitudes: amplitudes, color: accent),
      ],
    );
  }
}

/// Analogue pair: the skeuomorphic VU meter + a neutral waveform.
class _AnaloguePair extends StatelessWidget {
  const _AnaloguePair({
    required this.tokens,
    required this.colorScheme,
    required this.vu,
    required this.dBFS,
    required this.amplitudes,
  });

  final DsTokens tokens;
  final ColorScheme colorScheme;
  final double vu;
  final double dBFS;
  final List<double> amplitudes;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnalogVuMeter(
          vu: vu,
          dBFS: dBFS,
          size: tokens.spacing.step11 * 2,
          colorScheme: colorScheme,
        ),
        SizedBox(height: tokens.spacing.step3),
        LiveWaveform(
          amplitudes: amplitudes,
          color: dsTokensDark.colors.text.highEmphasis,
        ),
      ],
    );
  }
}

/// The "Try with your voice" toggle row — flips the previews from the looping
/// simulation to the live mic.
class _TryWithVoiceToggle extends StatelessWidget {
  const _TryWithVoiceToggle({
    required this.tokens,
    required this.accent,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final DsTokens tokens;
  final Color accent;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final textHigh = dsTokensDark.colors.text.highEmphasis;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mic_rounded,
          size: tokens.spacing.step5,
          color: value ? accent : textHigh.withValues(alpha: 0.6),
        ),
        SizedBox(width: tokens.spacing.step3),
        Flexible(
          child: Text(
            label,
            style: tokens.typography.styles.body.bodyLarge.copyWith(
              color: textHigh,
            ),
          ),
        ),
        SizedBox(width: tokens.spacing.step3),
        Switch.adaptive(
          value: value,
          activeThumbColor: accent,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
