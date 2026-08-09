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

class _GoalBannerAnimatedTextState extends State<GoalBannerAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  static const _cycle = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _cycle);
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

  /// Characters appear over the first ~2/3 of the cycle, then hold.
  Widget _typewriter() {
    final t = (_controller.value / 0.66).clamp(0.0, 1.0);
    final count = (widget.text.length * t).round();
    // Reserve the full size so the banner never reflows while typing.
    return Stack(
      children: [
        Opacity(opacity: 0, child: Text(widget.text, style: widget.style)),
        Text(widget.text.substring(0, count), style: widget.style),
      ],
    );
  }

  Widget _pulse() {
    final phase = math.sin(_controller.value * 2 * math.pi);
    return Opacity(
      opacity: 0.75 + 0.25 * ((phase + 1) / 2),
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
              -2 * math.sin(2 * math.pi * (_controller.value + i * 0.12)),
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
    final active = (t % 0.5) < 0.06;
    final seed = (t * 997).floor();
    final dx = active ? ((seed % 5) - 2).toDouble() : 0.0;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: Text(widget.text, style: widget.style),
    );
  }
}
