import 'dart:math' as math;

import 'package:flutter/material.dart';
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
          // A teal "processing" pulse keeps a hero presence through the wait —
          // the orb's energy carries into the thinking beat rather than
          // deflating to a bare progress bar.
          _ThinkingPulse(color: accent, size: tokens.spacing.step11),
          SizedBox(height: tokens.spacing.step6),
          Text(
            '"$transcript"',
            textAlign: TextAlign.center,
            // Bounded so a long transcript can't overflow the fixed-height
            // active band.
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: tokens.typography.styles.body.bodyLarge.copyWith(
              color: tokens.colors.text.highEmphasis,
              fontStyle: FontStyle.italic,
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

/// A calm teal "processing" pulse: a breathing core under an expanding sonar
/// ring. Reads as *working* (distinct from the mic orb) and keeps a teal hero
/// in the thinking frame. Holds a static frame under reduced motion.
class _ThinkingPulse extends StatefulWidget {
  const _ThinkingPulse({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_ThinkingPulse> createState() => _ThinkingPulseState();
}

class _ThinkingPulseState extends State<_ThinkingPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1700),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      if (_c.isAnimating) _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _ThinkingPulsePainter(widget.color, _c.value)),
      ),
    );
  }
}

class _ThinkingPulsePainter extends CustomPainter {
  _ThinkingPulsePainter(this.color, this.t);

  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxR = size.shortestSide / 2;
    // Expanding sonar ring, fading as it grows.
    canvas.drawCircle(
      center,
      maxR * (0.42 + 0.58 * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = color.withValues(alpha: (1 - t) * 0.6),
    );
    // Breathing core (glow + crisp dot).
    final breath = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
    canvas
      ..drawCircle(
        center,
        maxR * 0.26 * (0.85 + 0.3 * breath),
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      )
      ..drawCircle(center, maxR * 0.18, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ThinkingPulsePainter old) =>
      old.t != t || old.color != color;
}
