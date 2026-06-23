import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/animation/ai_thinking_line_shader.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';
import 'package:lotti/features/daily_os_next/ui/widgets/voice_orb_zone.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// The visible state of the first-capture moment.
enum OnboardingCapturePhase {
  /// Idle — the orb invites a tap; a rotating hint defeats blank-mic freeze.
  prompt,

  /// Mic open — the orb breathes with live voice level, waveform streams.
  listening,

  /// Words captured, structuring in flight — the transcript dims under a
  /// thinking shimmer (honest, indeterminate suspense). When structuring lands,
  /// the page navigates straight to the real task; there is no synthetic reveal
  /// here any more.
  thinking,
}

/// Presentational surface for the onboarding voice→task moment.
///
/// Three frames share one composition: a per-phase headline, then a
/// **fixed-height active band** that keeps the orb and the thinking cluster on
/// the *same* optical line, then a per-phase supporting block. The idle and
/// listening states pin a quiet "Rather type?" escape hatch at the bottom.
///
/// It is string- and callback-injected (no `getIt`/Riverpod) so it renders
/// identically under the real capture flow and in isolation for design review.
class OnboardingCaptureView extends StatelessWidget {
  const OnboardingCaptureView({
    required this.phase,
    required this.accent,
    required this.promptHeadline,
    required this.promptHint,
    required this.listeningCaption,
    required this.thinkingHeadline,
    required this.thinkingReassurance,
    required this.ratherTypeLabel,
    required this.orbSemanticLabel,
    required this.onOrbTap,
    required this.onRatherType,
    this.transcript = '',
    this.amplitudes = const [],
    this.dbfs = CaptureState.defaultDbfs,
    super.key,
  });

  final OnboardingCapturePhase phase;

  final Color accent;

  /// Headline for the prompt + listening states ("What's on your mind?").
  final String promptHeadline;

  /// Rotating example hint shown while idle ("Try: …").
  final String promptHint;

  /// Caption under the orb while the mic is open.
  final String listeningCaption;

  /// Headline while structuring is in flight ("Turning your words into a task…").
  final String thinkingHeadline;

  /// Reassurance that nothing is final ("You'll be able to edit everything").
  final String thinkingReassurance;

  /// Label for the type-instead escape hatch.
  final String ratherTypeLabel;

  /// Accessibility label for the orb button.
  final String orbSemanticLabel;

  final VoidCallback onOrbTap;
  final VoidCallback onRatherType;

  /// The live/captured transcript (shown during [OnboardingCapturePhase.thinking]).
  final String transcript;

  /// Rolling normalized amplitude window for the live waveform.
  final List<double> amplitudes;

  /// Latest raw dBFS for the breathing orb.
  final double dbfs;

  /// Fixed band the active element is centred in, so the orb and the thinking
  /// cluster share one optical anchor across phases.
  static const double _activeBandHeight = 232;

  /// Max width for centred supporting text.
  static const double _supportMaxWidth = 340;

  bool get _isListenable =>
      phase == OnboardingCapturePhase.prompt ||
      phase == OnboardingCapturePhase.listening;

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spacing.step5),
      child: Column(
        children: [
          const Spacer(flex: 4),
          Text(
            _headline,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.heading.heading2.copyWith(
              color: tokens.colors.text.highEmphasis,
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          SizedBox(
            height: _activeBandHeight,
            child: Center(child: _activeElement(tokens)),
          ),
          SizedBox(height: tokens.spacing.step5),
          _supporting(tokens),
          if (_isListenable) ...[
            SizedBox(height: tokens.spacing.step4),
            _bottomAction(tokens),
          ],
          const Spacer(flex: 4),
        ],
      ),
    );
  }

  String get _headline => switch (phase) {
    OnboardingCapturePhase.prompt => promptHeadline,
    OnboardingCapturePhase.listening => promptHeadline,
    OnboardingCapturePhase.thinking => thinkingHeadline,
  };

  Widget _activeElement(DsTokens tokens) {
    switch (phase) {
      case OnboardingCapturePhase.prompt:
        return VoiceOrbZone(
          phase: CapturePhase.idle,
          caption: '',
          captionColor: tokens.colors.text.mediumEmphasis,
          semanticLabel: orbSemanticLabel,
          onTap: onOrbTap,
        );
      case OnboardingCapturePhase.listening:
        return VoiceOrbZone(
          phase: CapturePhase.listening,
          caption: '',
          captionColor: tokens.colors.text.mediumEmphasis,
          semanticLabel: orbSemanticLabel,
          onTap: onOrbTap,
          amplitudes: amplitudes,
          dbfs: dbfs,
        );
      case OnboardingCapturePhase.thinking:
        return _ThinkingCluster(
          tokens: tokens,
          accent: accent,
          transcript: transcript,
          reassurance: thinkingReassurance,
        );
    }
  }

  Widget _supporting(DsTokens tokens) {
    // Thinking carries its reassurance inside the centred cluster, so its
    // supporting slot stays empty to avoid a stranded line.
    if (phase == OnboardingCapturePhase.thinking) {
      return const SizedBox.shrink();
    }

    final text = phase == OnboardingCapturePhase.listening
        ? listeningCaption
        : promptHint;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _supportMaxWidth),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: tokens.typography.styles.body.bodyLarge.copyWith(
          color: tokens.colors.text.highEmphasis,
        ),
      ),
    );
  }

  Widget _bottomAction(DsTokens tokens) {
    return TextButton(
      onPressed: onRatherType,
      child: Text(
        ratherTypeLabel,
        style: tokens.typography.styles.body.bodyLarge.copyWith(color: accent),
      ),
    );
  }
}

class _ThinkingCluster extends StatelessWidget {
  const _ThinkingCluster({
    required this.tokens,
    required this.accent,
    required this.transcript,
    required this.reassurance,
  });

  final DsTokens tokens;
  final Color accent;
  final String transcript;
  final String reassurance;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '"$transcript"',
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodyLarge.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontStyle: FontStyle.italic,
            ),
          ),
          SizedBox(height: tokens.spacing.step6),
          AiThinkingLineShader(
            width: 220,
            height: 30,
            primaryColor: accent,
            secondaryColor: tokens.colors.text.highEmphasis,
            backgroundColor: tokens.colors.background.level01.withValues(
              alpha: 0,
            ),
          ),
          SizedBox(height: tokens.spacing.step5),
          Text(
            reassurance,
            textAlign: TextAlign.center,
            style: tokens.typography.styles.body.bodySmall.copyWith(
              color: tokens.colors.text.mediumEmphasis,
            ),
          ),
        ],
      ),
    );
  }
}
