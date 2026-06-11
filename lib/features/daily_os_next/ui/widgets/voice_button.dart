import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_material_design_icons/flutter_material_design_icons.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';
import 'package:lotti/features/daily_os_next/state/capture_controller.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';

/// Circular voice button that anchors the capture surfaces.
///
/// Visual states, driven by [CapturePhase]:
/// - **idle / error** — solid teal disc + mic glyph, resting
///   concentric frames.
/// - **listening** — the disc wrapped by the dBFS-driven tension-loop
///   shader; glyph becomes a stop square (tap = stop recording).
/// - **transcribing** — dimmed button while the recording is converted to
///   text; tapping is a no-op at the controller level.
/// - **captured** — mic glyph again (tap = discard and re-record).
///
/// The button is deliberately "alive": presses scale the core down and
/// release it with a slight overshoot, the ink ripple is painted *above*
/// the fill so it is actually visible, glyph changes cross-fade, and —
/// while listening — the core itself breathes with the live voice level
/// (it rests smaller inside the shader field and swells with the same
/// dBFS signal the shader renders, so the inside and the outside of the
/// orb move as one organism instead of a live ring around a dead disc).
///
/// Pure presentation. The parent calls [onTap] which delegates to
/// `CaptureController.toggle()`.
class VoiceButton extends StatefulWidget {
  const VoiceButton({
    required this.phase,
    required this.onTap,
    required this.semanticLabel,
    this.size = 96,
    this.dbfs = CaptureState.defaultDbfs,
    this.dbfsFloor = CaptureState.defaultDbfs,
    super.key,
  });

  @visibleForTesting
  static const coreButtonKey = ValueKey<String>('daily-os-voice-button-core');

  @visibleForTesting
  static const fieldKey = ValueKey<String>('daily-os-voice-button-field');

  @visibleForTesting
  static const listeningFrameKey = ValueKey<String>(
    'daily-os-voice-button-listening-frame',
  );

  @visibleForTesting
  static const restingFrameKey = ValueKey<String>(
    'daily-os-voice-button-resting-frame',
  );

  /// Key on the [AnimatedScale] that carries the press feedback, so tests
  /// can assert the pressed scale.
  @visibleForTesting
  static const pressScaleKey = ValueKey<String>(
    'daily-os-voice-button-press-scale',
  );

  /// The amplitude shader spills past the button — kept tight so the orb
  /// reads as an accent, not a centerpiece (was 2.5 in the first design).
  @visibleForTesting
  static const shaderSizeScale = 1.9;

  @visibleForTesting
  static const listeningFrameSizeScale = 1.42;

  @visibleForTesting
  static const restingFrameSizeScale = 1.34;

  @visibleForTesting
  static const shaderHoleSizeScale = 1.18;

  /// Scale applied to the core while pressed.
  @visibleForTesting
  static const pressedScale = 0.9;

  /// Resting scale of the core while listening: the disc steps back so
  /// the tension-loop shader owns the field and the core reads as its
  /// responsive nucleus instead of a static plate.
  @visibleForTesting
  static const listeningCoreScale = 0.86;

  /// How far the core swells from [listeningCoreScale] at full voice
  /// level — the disc literally breathes with the same dBFS signal that
  /// drives the shader, so inside and outside move as one organism.
  @visibleForTesting
  static const listeningBreathSpan = 0.10;

  /// Amplitude of the slow idle breath while listening (sine, one cycle
  /// per [_VoiceButtonState.breathPeriod]). Keeps the core alive in the
  /// pauses BETWEEN words, under the voice-level swell.
  @visibleForTesting
  static const listeningIdleBreath = 0.02;

  /// The layout field reserves the listening frame plus a little clearance —
  /// the shader still overflows it via [OverflowBox], by design, so the
  /// field no longer inflates the layout the way the old `+128` padding
  /// did.
  static double fieldSizeFor(double buttonSize) =>
      listeningFrameSizeFor(buttonSize) + 16;

  @visibleForTesting
  static double shaderSizeFor(double buttonSize) =>
      buttonSize * shaderSizeScale;

  @visibleForTesting
  static double listeningFrameSizeFor(double buttonSize) =>
      buttonSize * listeningFrameSizeScale;

  @visibleForTesting
  static double restingFrameSizeFor(double buttonSize) =>
      buttonSize * restingFrameSizeScale;

  @visibleForTesting
  static double shaderHoleSizeFor(double buttonSize) =>
      buttonSize * shaderHoleSizeScale;

  /// The current Capture phase. Drives glyph + shader visibility.
  final CapturePhase phase;

  final VoidCallback onTap;

  /// Used by screen readers; the button has no visible label.
  final String semanticLabel;

  /// Diameter of the tappable record button in logical pixels.
  final double size;

  /// Latest recorder amplitude in dBFS. Used only while listening.
  final double dbfs;

  /// Floor used to normalize [dbfs] inside the shader.
  final double dbfsFloor;

  @override
  State<VoiceButton> createState() => _VoiceButtonState();
}

class _VoiceButtonState extends State<VoiceButton>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  /// One slow organic cycle for the idle breath while listening.
  @visibleForTesting
  static const breathPeriod = Duration(milliseconds: 2400);

  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: breathPeriod,
  );

  @override
  void initState() {
    super.initState();
    _syncBreath();
  }

  @override
  void didUpdateWidget(covariant VoiceButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _syncBreath();
  }

  /// The breath ticker runs ONLY while listening — every other phase is
  /// static, so no frames are burned on an invisible animation.
  void _syncBreath() {
    if (widget.phase == CapturePhase.listening) {
      _breath.repeat();
    } else {
      _breath
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  /// Voice-coupled core scale. While listening the disc rests at
  /// [VoiceButton.listeningCoreScale] and swells toward
  /// `listeningCoreScale + listeningBreathSpan` with the live dBFS —
  /// the same signal the surrounding shader renders, so the core never
  /// reads dead inside a live field. 1.0 in every other phase.
  double get _voiceScale {
    if (widget.phase != CapturePhase.listening) return 1;
    final floor = widget.dbfsFloor;
    final norm = floor >= 0
        ? 0.0
        : ((widget.dbfs - floor) / -floor).clamp(0.0, 1.0);
    return VoiceButton.listeningCoreScale +
        VoiceButton.listeningBreathSpan * norm;
  }

  IconData get _glyph => switch (widget.phase) {
    CapturePhase.listening => Icons.stop_rounded,
    CapturePhase.idle ||
    CapturePhase.error ||
    CapturePhase.transcribing ||
    CapturePhase.captured => MdiIcons.microphone,
  };

  @override
  Widget build(BuildContext context) {
    final tokens = context.designTokens;
    final teal = tokens.colors.interactive.enabled;
    final onTeal = tokens.colors.text.onInteractiveAlert;
    final size = widget.size;
    final fieldSize = VoiceButton.fieldSizeFor(size);
    final shaderSize = VoiceButton.shaderSizeFor(size);
    final listeningFrameSize = VoiceButton.listeningFrameSizeFor(size);
    final restingFrameSize = VoiceButton.restingFrameSizeFor(size);
    final shaderHoleSize = VoiceButton.shaderHoleSizeFor(size);
    final showRestingFrame =
        widget.phase == CapturePhase.idle || widget.phase == CapturePhase.error;
    final dimmed = widget.phase == CapturePhase.transcribing;
    // After capture the orb is demoted to an outline: talking is no longer
    // the primary action (the advance CTA is), so the full teal fill would
    // shout over it.
    final outlined = widget.phase == CapturePhase.captured;
    final glyphColor = outlined ? teal : onTeal;
    final coreDecoration = outlined
        ? BoxDecoration(
            shape: BoxShape.circle,
            color: teal.withValues(alpha: 0.08),
            border: Border.all(color: teal.withValues(alpha: 0.55), width: 1.5),
          )
        : BoxDecoration(
            shape: BoxShape.circle,
            // Flat brand disc — the one gradient in the system read as a
            // different material from everything else, especially in the
            // light theme.
            color: teal,
            boxShadow: const [
              BoxShadow(
                color: Color(0x24000000),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          );

    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: SizedBox(
        key: VoiceButton.fieldKey,
        width: fieldSize,
        height: fieldSize,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (widget.phase == CapturePhase.listening)
              ExcludeSemantics(
                child: OverflowBox(
                  minWidth: shaderSize,
                  maxWidth: shaderSize,
                  minHeight: shaderSize,
                  maxHeight: shaderSize,
                  child: ClipPath(
                    clipper: _RingFieldClipper(holeDiameter: shaderHoleSize),
                    child: AiVoiceInputShader(
                      dbfs: widget.dbfs,
                      dbfsFloor: widget.dbfsFloor,
                      size: shaderSize,
                      intensity: 0.84,
                      lineDensity: 24,
                      orbitalMix: 0.60,
                      primaryColor: teal,
                      secondaryColor: tokens.colors.text.highEmphasis,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
              ),
            if (widget.phase == CapturePhase.listening)
              ExcludeSemantics(
                child: _ListeningFrame(
                  diameter: listeningFrameSize,
                  color: teal,
                ),
              ),
            if (showRestingFrame)
              ExcludeSemantics(
                child: _RestingFrame(
                  diameter: restingFrameSize,
                  color: teal,
                ),
              ),
            // Press + breathing feedback, all SIZE-based: the disc's
            // painted diameter animates (crisp anti-aliased circle at
            // every size) instead of raster-scaling a fixed circle via a
            // transform, which shimmered at the edges while breathing.
            // The implicit tween carries press dips and the dBFS voice
            // swell (each tick re-targets it with a short ease — no
            // overshoot there, back-curves jitter under the amplitude
            // stream); the AnimatedBuilder multiplies in the slow idle
            // breath so the core stays alive between words. The glyph
            // keeps a fixed size — the disc breathes around it.
            AnimatedBuilder(
              animation: _breath,
              builder: (context, child) {
                final idleBreath = widget.phase == CapturePhase.listening
                    ? 1 +
                          VoiceButton.listeningIdleBreath *
                              math.sin(2 * math.pi * _breath.value)
                    : 1.0;
                return TweenAnimationBuilder<double>(
                  key: VoiceButton.pressScaleKey,
                  tween: Tween<double>(
                    end:
                        (_pressed ? VoiceButton.pressedScale : 1.0) *
                        _voiceScale,
                  ),
                  duration: _pressed
                      ? const Duration(milliseconds: 90)
                      : widget.phase == CapturePhase.listening
                      ? const Duration(milliseconds: 130)
                      : const Duration(milliseconds: 240),
                  curve: _pressed || widget.phase == CapturePhase.listening
                      ? Curves.easeOutCubic
                      : Curves.easeOutBack,
                  builder: (context, target, inner) {
                    final diameter = size * target * idleBreath;
                    return SizedBox(
                      width: diameter,
                      height: diameter,
                      child: inner,
                    );
                  },
                  child: child,
                );
              },
              child: AnimatedOpacity(
                opacity: dimmed ? 0.55 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: Ink(
                    decoration: coreDecoration,
                    child: InkWell(
                      key: VoiceButton.coreButtonKey,
                      onTap: widget.onTap,
                      onTapDown: (_) => _setPressed(true),
                      onTapCancel: () => _setPressed(false),
                      onTapUp: (_) => _setPressed(false),
                      customBorder: const CircleBorder(),
                      splashColor: (outlined ? teal : onTeal).withValues(
                        alpha: 0.22,
                      ),
                      highlightColor: (outlined ? teal : onTeal).withValues(
                        alpha: 0.08,
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.7,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                          child: Icon(
                            _glyph,
                            key: ValueKey<IconData>(_glyph),
                            size: size * 0.38,
                            color: glyphColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListeningFrame extends StatelessWidget {
  const _ListeningFrame({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: VoiceButton.listeningFrameKey,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: color.a * 0.36),
          width: 1.5,
        ),
      ),
      child: SizedBox.square(dimension: diameter),
    );
  }
}

class _RestingFrame extends StatelessWidget {
  const _RestingFrame({
    required this.diameter,
    required this.color,
  });

  final double diameter;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      key: VoiceButton.restingFrameKey,
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: color.a * 0.16),
              ),
            ),
            child: SizedBox.square(dimension: diameter),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: color.a * 0.08),
              ),
            ),
            child: SizedBox.square(dimension: diameter * 0.78),
          ),
        ],
      ),
    );
  }
}

class _RingFieldClipper extends CustomClipper<Path> {
  const _RingFieldClipper({required this.holeDiameter});

  final double holeDiameter;

  @override
  Path getClip(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final hole = Rect.fromCircle(center: center, radius: holeDiameter / 2);
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(hole);
  }

  @override
  bool shouldReclip(covariant _RingFieldClipper oldClipper) {
    return oldClipper.holeDiameter != holeDiameter;
  }
}
