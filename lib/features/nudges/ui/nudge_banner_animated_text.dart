import 'dart:math' as math;

import 'package:lotti/classes/nudge_models.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:material_ui/material_ui.dart';

/// Renders a banner headline through one of the code-owned animation
/// presets (ADR 0058: the model *selects*, code *implements*).
///
/// Every preset degrades to plain text when the platform asks for
/// reduced motion — the animation is a garnish, never the content.
class NudgeBannerAnimatedText extends StatefulWidget {
  const NudgeBannerAnimatedText({
    required this.text,
    required this.animation,
    required this.style,
    this.maxLines = _NudgeBannerMotion.defaultMaxLines,
    super.key,
  });

  final String text;
  final NudgeBannerAnimation animation;
  final TextStyle style;
  final int? maxLines;

  @override
  State<NudgeBannerAnimatedText> createState() =>
      _NudgeBannerAnimatedTextState();
}

/// The preset parameters — the code-owned animation catalog itself
/// (ADR 0058: the model selects presets, code implements them). These
/// are motion amplitudes, not layout values, which is why they live here
/// as the catalog rather than in the spacing/typography token pipeline;
/// durations and easing come from the motion tokens where they apply.
abstract final class _NudgeBannerMotion {
  /// One full animation cycle for every preset.
  static const cycle = Duration(seconds: 3);

  /// Pulse breathes between these opacities — never below the readable
  /// floor.
  static const pulseFloorOpacity = 0.55;

  /// Wave bob amplitude in logical pixels, and the per-word phase shift.
  static const waveAmplitude = 2.0;
  static const wavePhaseStep = 0.12;

  /// Portion of the cycle the typewriter spends revealing characters.
  static const typewriterRevealFraction = 0.66;

  /// Glitch: the active-jitter slice of each half cycle, and the maximum
  /// horizontal displacement in logical pixels.
  static const glitchActiveFraction = 0.06;
  static const glitchMaxOffset = 2.0;

  /// Model copy is unbounded, banner hosts are not: every preset caps the
  /// headline at this many lines (marquee stays single-line by design),
  /// so a runaway headline or large text scaling can never overflow a
  /// fixed-height host like the day page.
  static const defaultMaxLines = 2;
}

class _NudgeBannerAnimatedTextState extends State<NudgeBannerAnimatedText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _NudgeBannerMotion.cycle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncController();
  }

  @override
  void didUpdateWidget(NudgeBannerAnimatedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync can swap the preset under the SAME element (deterministic row
    // id, unchanged key): a steady→pulse update must start the stopped
    // controller, and the reverse must stop the invisible one.
    if (oldWidget.animation != widget.animation) _syncController();
  }

  void _syncController() {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final animated =
        !reduced && widget.animation != NudgeBannerAnimation.steady;
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
        widget.animation == NudgeBannerAnimation.steady) {
      return _capped(widget.text);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => switch (widget.animation) {
        NudgeBannerAnimation.steady => _capped(widget.text),
        NudgeBannerAnimation.typewriter => _typewriter(),
        NudgeBannerAnimation.pulse => _pulse(),
        NudgeBannerAnimation.wave => _wave(),
        NudgeBannerAnimation.marquee => _marquee(),
        NudgeBannerAnimation.glitch => _glitch(),
      },
    );
  }

  /// The bounded headline every preset builds on.
  Widget _capped(String text) => Text(
    text,
    style: widget.style,
    maxLines: widget.maxLines,
    overflow: widget.maxLines == null
        ? TextOverflow.visible
        : TextOverflow.ellipsis,
  );

  /// Characters appear over the reveal fraction of the cycle, then hold.
  /// Grapheme-cluster stepping: model copy can carry emoji and composed
  /// characters, and a UTF-16 substring would split them mid-glyph.
  Widget _typewriter() {
    final t = (_controller.value / _NudgeBannerMotion.typewriterRevealFraction)
        .clamp(0.0, 1.0);
    final graphemes = widget.text.characters;
    final count = (graphemes.length * t).round();
    // Screen readers get the STABLE full copy; the ever-changing visual
    // prefix (empty at every cycle start) is excluded so VoiceOver never
    // announces a truncated or blank headline.
    return Semantics(
      label: widget.text,
      child: ExcludeSemantics(
        // Reserve the full size so the banner never reflows while typing.
        child: Stack(
          children: [
            Opacity(opacity: 0, child: _capped(widget.text)),
            _capped(graphemes.take(count).toString()),
          ],
        ),
      ),
    );
  }

  Widget _pulse() {
    final phase = math.sin(_controller.value * 2 * math.pi);
    const floor = _NudgeBannerMotion.pulseFloorOpacity;
    return Opacity(
      opacity: floor + (1 - floor) * ((phase + 1) / 2),
      child: _capped(widget.text),
    );
  }

  /// Per-word vertical bob, phase-shifted along the line. A `Wrap` of
  /// words cannot ellipsize, so copy that would exceed the line cap
  /// renders as the bounded steady text instead of bobbing off the card.
  Widget _wave() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        if (painter.didExceedMaxLines) return _capped(widget.text);
        return _waveWords();
      },
    );
  }

  Widget _waveWords() {
    final words = widget.text.split(' ');
    // The gap between bobbing words is the style's own space glyph,
    // measured under the ambient scaler — typography-derived, not an ad
    // hoc visual constant (the design system has no token for a font's
    // word gap).
    final spacePainter = TextPainter(
      text: TextSpan(text: ' ', style: widget.style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return Wrap(
      spacing: spacePainter.width,
      children: [
        for (final (i, word) in words.indexed)
          Transform.translate(
            offset: Offset(
              0,
              -_NudgeBannerMotion.waveAmplitude *
                  math.sin(
                    2 *
                        math.pi *
                        (_controller.value +
                            i * _NudgeBannerMotion.wavePhaseStep),
                  ),
            ),
            child: Text(word, style: widget.style),
          ),
      ],
    );
  }

  /// Scrolls overflow distance, or a small minimum distance for concise copy.
  Widget _marquee() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: widget.style),
          maxLines: 1,
          textDirection: Directionality.of(context),
          // The rendered Text inherits the ambient scaler; measuring
          // unscaled would under-estimate travel under large text.
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final travel = math.max(
          painter.width - constraints.maxWidth,
          context.designTokens.spacing.step4,
        );
        // Ease across, hold at each end (the standard curve both ways).
        final t = MotionCurves.standard.transform(
          (math.sin(_controller.value * 2 * math.pi - math.pi / 2) + 1) / 2,
        );
        // OverflowBox lifts the viewport's max-width constraint inside
        // the clip: without it the SizedBox is clamped to the viewport,
        // the line is truncated at layout time, and translation would
        // reveal nothing.
        return SizedBox(
          height: painter.height,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: double.infinity,
              child: Transform.translate(
                offset: Offset(-travel * t, 0),
                child: SizedBox(
                  width: painter.width + 1,
                  child: Text(widget.text, style: widget.style, maxLines: 1),
                ),
              ),
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
    final active = (t % 0.5) < _NudgeBannerMotion.glitchActiveFraction;
    final seed = (t * 997).floor();
    const range = 2 * _NudgeBannerMotion.glitchMaxOffset + 1;
    final dx = active
        ? (seed % range) - _NudgeBannerMotion.glitchMaxOffset
        : 0.0;
    return Transform.translate(
      offset: Offset(dx, 0),
      child: _capped(widget.text),
    );
  }
}
