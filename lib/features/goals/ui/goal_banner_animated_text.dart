import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lotti/classes/goal_nudge_models.dart';
import 'package:lotti/features/design_system/theme/motion_tokens.dart';

/// Renders a banner headline through one of the code-owned animation
/// presets (ADR 0058: the model *selects*, code *implements*).
///
/// Every preset degrades to plain text when the platform asks for
/// reduced motion — the animation is a garnish, never the content.
class GoalBannerAnimatedText extends StatefulWidget {
  const GoalBannerAnimatedText({
    required this.text,
    required this.animation,
    required this.style,
    super.key,
  });

  final String text;
  final GoalBannerAnimation animation;
  final TextStyle style;

  @override
  State<GoalBannerAnimatedText> createState() => _GoalBannerAnimatedTextState();
}

/// The preset parameters — the code-owned animation catalog itself
/// (ADR 0058: the model selects presets, code implements them). These
/// are motion amplitudes, not layout values, which is why they live here
/// as the catalog rather than in the spacing/typography token pipeline;
/// durations and easing come from the motion tokens where they apply.
abstract final class _GoalBannerMotion {
  /// One full animation cycle for every preset.
  static const cycle = Duration(seconds: 3);

  /// Pulse breathes between these opacities — never below the readable
  /// floor.
  static const pulseFloorOpacity = 0.75;

  /// Wave bob amplitude in logical pixels, and the per-word phase shift.
  static const waveAmplitude = 2.0;
  static const wavePhaseStep = 0.12;

  /// Portion of the cycle the typewriter spends revealing characters.
  static const typewriterRevealFraction = 0.66;

  /// Glitch: the active-jitter slice of each half cycle, and the maximum
  /// horizontal displacement in logical pixels.
  static const glitchActiveFraction = 0.06;
  static const glitchMaxOffset = 2.0;
}

class _GoalBannerAnimatedTextState extends State<GoalBannerAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _GoalBannerMotion.cycle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    final animated = !reduced && widget.animation != GoalBannerAnimation.steady;
    if (animated && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!animated && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.animation == GoalBannerAnimation.steady) {
      return Text(widget.text, style: widget.style);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => switch (widget.animation) {
        GoalBannerAnimation.steady => Text(widget.text, style: widget.style),
        GoalBannerAnimation.typewriter => _typewriter(),
        GoalBannerAnimation.pulse => _pulse(),
        GoalBannerAnimation.wave => _wave(),
        GoalBannerAnimation.marquee => _marquee(),
        GoalBannerAnimation.glitch => _glitch(),
      },
    );
  }

  /// Characters appear over the reveal fraction of the cycle, then hold.
  /// Grapheme-cluster stepping: model copy can carry emoji and composed
  /// characters, and a UTF-16 substring would split them mid-glyph.
  Widget _typewriter() {
    final t = (_controller.value / _GoalBannerMotion.typewriterRevealFraction)
        .clamp(0.0, 1.0);
    final graphemes = widget.text.characters;
    final count = (graphemes.length * t).round();
    // Reserve the full size so the banner never reflows while typing.
    return Stack(
      children: [
        Opacity(opacity: 0, child: Text(widget.text, style: widget.style)),
        Text(graphemes.take(count).toString(), style: widget.style),
      ],
    );
  }

  Widget _pulse() {
    final phase = math.sin(_controller.value * 2 * math.pi);
    const floor = _GoalBannerMotion.pulseFloorOpacity;
    return Opacity(
      opacity: floor + (1 - floor) * ((phase + 1) / 2),
      child: Text(widget.text, style: widget.style),
    );
  }

  /// Per-word vertical bob, phase-shifted along the line.
  Widget _wave() {
    final words = widget.text.split(' ');
    return Wrap(
      spacing: (widget.style.fontSize ?? 14) * 0.28,
      children: [
        for (final (i, word) in words.indexed)
          Transform.translate(
            offset: Offset(
              0,
              -_GoalBannerMotion.waveAmplitude *
                  math.sin(
                    2 *
                        math.pi *
                        (_controller.value +
                            i * _GoalBannerMotion.wavePhaseStep),
                  ),
            ),
            child: Text(word, style: widget.style),
          ),
      ],
    );
  }

  /// Scrolls only when the text overflows its line; otherwise steady.
  Widget _marquee() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
        )..layout();
        if (painter.width <= constraints.maxWidth) {
          return Text(
            widget.text,
            style: widget.style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
        }
        final travel = painter.width - constraints.maxWidth;
        // Ease across, hold at each end (the standard curve both ways).
        final t = MotionCurves.standard.transform(
          (math.sin(_controller.value * 2 * math.pi - math.pi / 2) + 1) / 2,
        );
        return ClipRect(
          child: Transform.translate(
            offset: Offset(-travel * t, 0),
            child: SizedBox(
              width: painter.width + 1,
              child: Text(widget.text, style: widget.style, maxLines: 1),
            ),
          ),
        );
      },
    );
  }

  /// A brief deterministic jitter twice per cycle — pseudo-random from
  /// the controller value, so tests and replays render identically.
  Widget _glitch() {
    final t = _controller.value;
    final active = (t % 0.5) < _GoalBannerMotion.glitchActiveFraction;
    final seed = (t * 997).floor();
    const range = 2 * _GoalBannerMotion.glitchMaxOffset + 1;
    final dx = active
        ? (seed % range) - _GoalBannerMotion.glitchMaxOffset
        : 0.0;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: Text(widget.text, style: widget.style),
    );
  }
}
