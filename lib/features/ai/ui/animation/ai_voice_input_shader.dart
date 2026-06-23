import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lotti/features/ai/ui/animation/ai_state_shader_animation.dart';

/// GLSL fragment-shader visualization of live microphone input.
///
/// Reacts to the current voice level [dbfs] (clamped at [dbfsFloor]),
/// modulating line density and intensity so the visual swells with speech.
/// Falls back to a CPU-painted approximation ([AiVoiceInputFallbackPainter])
/// when the shader can't load. [timeOverride] / [programLoader] support
/// deterministic golden tests.
class AiVoiceInputShader extends StatefulWidget {
  const AiVoiceInputShader({
    required this.dbfs,
    required this.size,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    this.dbfsFloor = -80,
    this.speed = 2,
    this.intensity = 0.78,
    this.lineDensity = 19,
    this.orbitalMix = 0.55,
    this.route = AiVoiceShaderRoute.tensionLoop,
    this.timeOverride,
    this.programLoader,
    this.semanticsLabel,
    super.key,
  });

  /// Current voice level in dBFS, typically `-80..0`.
  final double dbfs;
  final double dbfsFloor;
  final double size;
  final double speed;
  final double intensity;
  final double lineDensity;
  final double orbitalMix;
  final AiVoiceShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final double? timeOverride;
  final AiShaderProgramLoader? programLoader;
  final String? semanticsLabel;

  @override
  State<AiVoiceInputShader> createState() => _AiVoiceInputShaderState();
}

class _AiVoiceInputShaderState extends State<AiVoiceInputShader>
    with SingleTickerProviderStateMixin {
  static const _animationLoop = Duration(seconds: 48);

  late final AnimationController _controller;
  late Future<ui.FragmentProgram> _programFuture;

  /// Whether the OS "reduce motion" accessibility setting is on. When true the
  /// continuous time ticker is held still and the shader renders one calm
  /// static frame — still tinted by the live voice level, which is direct
  /// feedback rather than decorative motion (mirroring how `VoiceButton` keeps
  /// its dBFS-driven core swell while dropping its idle-breath ticker).
  bool _reducedMotion = false;

  @override
  void initState() {
    super.initState();
    _programFuture = _loadProgram();
    _controller = AnimationController(vsync: this, duration: _animationLoop);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // didChangeDependencies (not initState) so the reduced-motion setting is
    // readable here, and a later toggle of it re-syncs the ticker.
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncController();
  }

  @override
  void didUpdateWidget(covariant AiVoiceInputShader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.programLoader != widget.programLoader) {
      _programFuture = _loadProgram();
    }
    _syncController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<ui.FragmentProgram> _loadProgram() {
    final loader =
        widget.programLoader ?? AiStateShaderProgramCache.loadVoiceInput;
    return loader();
  }

  void _syncController() {
    // The time ticker drives the continuous swirl. Hold it still when a frame
    // is pinned for golden tests ([timeOverride]) or when the user asked for
    // reduced motion — the shader then renders one calm, static frame.
    final shouldAnimate = widget.timeOverride == null && !_reducedMotion;
    if (shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
      return;
    }
    if (_controller.isAnimating) _controller.stop();
    // Pin a deterministic static frame for reduced motion (golden tests supply
    // their own [timeOverride], so only touch the controller when they don't).
    if (_reducedMotion && widget.timeOverride == null) _controller.value = 0;
  }

  double get _timeSeconds {
    return widget.timeOverride ??
        _controller.value * _animationLoop.inMilliseconds / 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox.square(
        dimension: widget.size,
        child: ClipRect(
          child: RepaintBoundary(
            child: FutureBuilder<ui.FragmentProgram>(
              future: _programFuture,
              builder: (context, snapshot) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final time = _timeSeconds * widget.speed;
                    final program = snapshot.data;
                    return CustomPaint(
                      painter: program == null
                          ? AiVoiceInputFallbackPainter(
                              dbfs: widget.dbfs,
                              dbfsFloor: widget.dbfsFloor,
                              time: time,
                              intensity: widget.intensity,
                              lineDensity: widget.lineDensity,
                              orbitalMix: widget.orbitalMix,
                              route: widget.route,
                              primaryColor: widget.primaryColor,
                              secondaryColor: widget.secondaryColor,
                              backgroundColor: widget.backgroundColor,
                            )
                          : AiVoiceInputShaderPainter(
                              program: program,
                              dbfs: widget.dbfs,
                              dbfsFloor: widget.dbfsFloor,
                              time: time,
                              intensity: widget.intensity,
                              lineDensity: widget.lineDensity,
                              orbitalMix: widget.orbitalMix,
                              route: widget.route,
                              primaryColor: widget.primaryColor,
                              secondaryColor: widget.secondaryColor,
                              backgroundColor: widget.backgroundColor,
                            ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Drives the loaded fragment [program] for [AiVoiceInputShader] — maps the
/// voice level and animation params to shader uniforms and paints them.
class AiVoiceInputShaderPainter extends CustomPainter {
  AiVoiceInputShaderPainter({
    required this.program,
    required this.dbfs,
    required this.dbfsFloor,
    required this.time,
    required this.intensity,
    required this.lineDensity,
    required this.orbitalMix,
    required this.route,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  final ui.FragmentProgram program;
  final double dbfs;
  final double dbfsFloor;
  final double time;
  final double intensity;
  final double lineDensity;
  final double orbitalMix;
  final AiVoiceShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final shader = program.fragmentShader()
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time)
      ..setFloat(3, dbfs)
      ..setFloat(4, dbfsFloor)
      ..setFloat(5, intensity)
      ..setFloat(6, lineDensity)
      ..setFloat(7, orbitalMix)
      ..setFloat(8, route.index.toDouble());
    aiSetShaderColor(shader, 9, primaryColor);
    aiSetShaderColor(shader, 13, secondaryColor);
    aiSetShaderColor(shader, 17, backgroundColor);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(AiVoiceInputShaderPainter oldDelegate) {
    return oldDelegate.program != program ||
        oldDelegate.dbfs != dbfs ||
        oldDelegate.dbfsFloor != dbfsFloor ||
        oldDelegate.time != time ||
        oldDelegate.intensity != intensity ||
        oldDelegate.lineDensity != lineDensity ||
        oldDelegate.orbitalMix != orbitalMix ||
        oldDelegate.route != route ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// CPU-painted approximation of the voice visualization, used when the GLSL
/// shader is unavailable (load failure or unsupported platform).
@visibleForTesting
class AiVoiceInputFallbackPainter extends CustomPainter {
  AiVoiceInputFallbackPainter({
    required this.dbfs,
    required this.dbfsFloor,
    required this.time,
    required this.intensity,
    required this.lineDensity,
    required this.orbitalMix,
    required this.route,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  final double dbfs;
  final double dbfsFloor;
  final double time;
  final double intensity;
  final double lineDensity;
  final double orbitalMix;
  final AiVoiceShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  double get _level {
    final floor = math.min(dbfsFloor, -0.001);
    final normalized = ((dbfs - floor) / floor.abs()).clamp(0.0, 1.0);
    return Curves.easeOut.transform(normalized);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final shortest = math.min(size.width, size.height);
    final center = Offset(size.width / 2, size.height / 2);
    final level = _level;

    final outerPaint = Paint()
      ..color = primaryColor.withValues(alpha: primaryColor.a * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * (0.010 + 0.012 * level)
      ..strokeCap = StrokeCap.round;
    final innerPaint = Paint()
      ..color = secondaryColor.withValues(
        alpha: secondaryColor.a * intensity * (0.54 + 0.40 * level),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * (0.007 + 0.008 * level)
      ..strokeCap = StrokeCap.round;

    canvas
      ..drawCircle(center, shortest * (0.30 + 0.035 * level), outerPaint)
      ..drawCircle(center, shortest * 0.20, innerPaint);

    final orbitPaint = Paint()
      ..color = secondaryColor.withValues(alpha: intensity * orbitalMix * 0.65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * 0.005;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: shortest * 0.38),
      time * -0.8,
      math.pi * (0.32 + 0.30 * level),
      false,
      orbitPaint,
    );

    final scanPaint = Paint()
      ..color = Color.lerp(primaryColor, secondaryColor, 0.45)!.withValues(
        alpha: intensity * (0.18 + 0.30 * level),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = shortest * (0.003 + 0.002 * level)
      ..strokeCap = StrokeCap.round;
    final scanRect = Rect.fromCircle(center: center, radius: shortest * 0.25);
    canvas.drawArc(
      scanRect,
      time * 0.42,
      math.pi * (0.42 + 0.18 * level),
      false,
      scanPaint,
    );

    final corePaint = Paint()
      ..color = Color.lerp(primaryColor, secondaryColor, 0.25)!.withValues(
        alpha: intensity * (0.08 + 0.20 * level),
      );
    canvas.drawCircle(center, shortest * (0.045 + 0.018 * level), corePaint);
  }

  @override
  bool shouldRepaint(AiVoiceInputFallbackPainter oldDelegate) {
    return oldDelegate.dbfs != dbfs ||
        oldDelegate.dbfsFloor != dbfsFloor ||
        oldDelegate.time != time ||
        oldDelegate.intensity != intensity ||
        oldDelegate.lineDensity != lineDensity ||
        oldDelegate.orbitalMix != orbitalMix ||
        oldDelegate.route != route ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}
