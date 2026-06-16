import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Animation timings for [AudioRecordingOrb].
class AudioRecordingOrbConstants {
  const AudioRecordingOrbConstants._();

  /// Period of one breathing pulse of the orb while recording is active.
  static const Duration pulseDuration = Duration(milliseconds: 1400);
}

/// Display-ready signal level derived from a raw dBFS sample.
///
/// [normalized] is a `0..1` value mapped from the dBFS reading and biased
/// toward the normal speech range (see `fromDbfs`) so the orb visibly reacts at
/// small sidebar sizes instead of only near clipping; [isClipping] flags when
/// the instantaneous level is hot enough to switch the orb to its warning
/// color.
@immutable
class AudioRecordingSignalLevel {
  const AudioRecordingSignalLevel({
    required this.normalized,
    required this.isClipping,
  });

  /// Maps an instantaneous [dBFS] reading onto the `[-64, 0]` dBFS display
  /// window, applies the response curve, and flags clipping above -3 dBFS.
  /// Non-finite input (e.g. silence reported as `-inf`) collapses to a quiet,
  /// non-clipping level.
  factory AudioRecordingSignalLevel.fromDbfs(double dBFS) {
    if (!dBFS.isFinite) {
      return const AudioRecordingSignalLevel(
        normalized: 0,
        isClipping: false,
      );
    }

    final linear = ((dBFS - _floorDbfs) / (_ceilingDbfs - _floorDbfs)).clamp(
      0.0,
      1.0,
    );
    // Bias the display toward the normal speech range so live mic changes are
    // visible at sidebar size instead of only reacting near clipping.
    final normalized = math.pow(linear, _responseCurve).toDouble();

    return AudioRecordingSignalLevel(
      normalized: normalized,
      isClipping: dBFS > _clippingDbfs,
    );
  }

  static const double _clippingDbfs = -3;
  static const double _floorDbfs = -64;
  static const double _ceilingDbfs = 0;
  static const double _responseCurve = 0.9;

  /// Signal level in `0..1`, biased toward the speech range for visibility.
  final double normalized;

  /// Whether the instantaneous level is hot enough to be treated as clipping.
  final bool isClipping;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AudioRecordingSignalLevel &&
            other.normalized == normalized &&
            other.isClipping == isClipping;
  }

  @override
  int get hashCode => Object.hash(normalized, isClipping);
}

/// Compact live recording indicator: a pulsing, signal-reactive orb painted
/// from the current microphone level.
///
/// Feeds [dBFS] through [AudioRecordingSignalLevel.fromDbfs] each frame and
/// drives a continuous breathing pulse via [AudioRecordingOrbPainter]. The
/// pulse only runs while [active]; when inactive it is stopped and reset so the
/// orb sits still. [size] defaults to a design-token step when omitted.
class AudioRecordingOrb extends StatefulWidget {
  const AudioRecordingOrb({
    required this.dBFS,
    this.size,
    this.active = true,
    super.key,
  });

  /// Instantaneous microphone level in dBFS, mapped to the orb's intensity.
  final double dBFS;

  /// Side length of the square orb; falls back to a design-token step.
  final double? size;

  /// Whether the breathing pulse animates (false freezes the orb).
  final bool active;

  @override
  State<AudioRecordingOrb> createState() => _AudioRecordingOrbState();
}

class _AudioRecordingOrbState extends State<AudioRecordingOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: AudioRecordingOrbConstants.pulseDuration,
      vsync: this,
    );
    _syncPulse();
  }

  @override
  void didUpdateWidget(AudioRecordingOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _syncPulse();
    }
  }

  void _syncPulse() {
    if (widget.active) {
      _pulseController.repeat();
    } else {
      _pulseController
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final orbSize = widget.size ?? tokens.spacing.step6;
    final signalLevel = AudioRecordingSignalLevel.fromDbfs(widget.dBFS);

    return RepaintBoundary(
      child: SizedBox.square(
        dimension: orbSize,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            return CustomPaint(
              painter: AudioRecordingOrbPainter(
                signalLevel: signalLevel,
                phase: widget.active ? _pulseController.value : 0,
                baseColor: tokens.colors.alert.error.defaultColor,
                clippingColor: tokens.colors.alert.warning.defaultColor,
                highlightColor: tokens.colors.text.onInteractiveAlert,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Paints the recording orb as four stacked circles — an outer glow, an
/// expanding wave ring, a solid ring, and a gradient core — whose radii and
/// alphas are modulated by both the normalized [signalLevel] and the breathing
/// [phase] (`0..1` of the pulse cycle). Switches from [baseColor] to
/// [clippingColor] when the signal is clipping; [highlightColor] seeds the
/// core's radial gradient.
class AudioRecordingOrbPainter extends CustomPainter {
  const AudioRecordingOrbPainter({
    required this.signalLevel,
    required this.phase,
    required this.baseColor,
    required this.clippingColor,
    required this.highlightColor,
  });

  final AudioRecordingSignalLevel signalLevel;
  final double phase;
  final Color baseColor;
  final Color clippingColor;
  final Color highlightColor;

  @override
  void paint(Canvas canvas, Size size) {
    final shortestSide = math.min(size.width, size.height);
    if (shortestSide <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final signal = signalLevel.normalized;
    final pulse = (math.sin(phase * math.pi * 2) + 1) / 2;
    final pulseImpact = 0.35 + signal * 0.65;
    final color = signalLevel.isClipping ? clippingColor : baseColor;

    final glowRadius =
        shortestSide * (0.30 + signal * 0.12 + pulse * 0.07 * pulseImpact);
    final glowAlpha = (0.32 + signal * 0.45 + pulse * 0.16 * pulseImpact).clamp(
      0.0,
      0.92,
    );
    canvas.drawCircle(
      center,
      glowRadius,
      Paint()..color = color.withValues(alpha: glowAlpha),
    );

    final waveRadius = shortestSide * (0.27 + signal * 0.10 + pulse * 0.08);
    final waveAlpha = ((1 - pulse) * (0.22 + signal * 0.45)).clamp(0.0, 0.58);
    canvas.drawCircle(
      center,
      waveRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shortestSide * (0.03 + signal * 0.03)
        ..color = color.withValues(alpha: waveAlpha),
    );

    final ringRadius =
        shortestSide * (0.22 + signal * 0.11 + pulse * 0.05 * pulseImpact);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = shortestSide * (0.08 + signal * 0.04)
        ..color = color.withValues(alpha: 0.96),
    );

    final coreRadius =
        shortestSide * (0.16 + signal * 0.14 + pulse * 0.04 * pulseImpact);
    final coreRect = Rect.fromCircle(center: center, radius: coreRadius);
    canvas.drawCircle(
      center,
      coreRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            highlightColor.withValues(alpha: 0.95),
            color.withValues(alpha: 0.95),
            color.withValues(alpha: 0.65),
          ],
          stops: const [0, 0.55, 1],
        ).createShader(coreRect),
    );
  }

  @override
  bool shouldRepaint(AudioRecordingOrbPainter oldDelegate) {
    return oldDelegate.signalLevel != signalLevel ||
        oldDelegate.phase != phase ||
        oldDelegate.baseColor != baseColor ||
        oldDelegate.clippingColor != clippingColor ||
        oldDelegate.highlightColor != highlightColor;
  }
}
