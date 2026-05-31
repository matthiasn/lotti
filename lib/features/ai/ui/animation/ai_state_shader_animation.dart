import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

typedef AiShaderProgramLoader = Future<ui.FragmentProgram> Function();

enum AiVoiceShaderRoute {
  elasticMembrane,
  impactRipples,
  tensionLoop,
  liquidPulse,
  resonanceBraid,
}

extension AiVoiceShaderRouteLabel on AiVoiceShaderRoute {
  String get label {
    return switch (this) {
      AiVoiceShaderRoute.elasticMembrane => 'Elastic membrane',
      AiVoiceShaderRoute.impactRipples => 'Impact ripples',
      AiVoiceShaderRoute.tensionLoop => 'Tension loop',
      AiVoiceShaderRoute.liquidPulse => 'Liquid pulse',
      AiVoiceShaderRoute.resonanceBraid => 'Resonance braid',
    };
  }
}

enum AiThinkingShaderRoute {
  quietThread,
  packetScan,
  circuitTrace,
  probabilityBand,
  decoderBars,
}

extension AiThinkingShaderRouteLabel on AiThinkingShaderRoute {
  String get label {
    return switch (this) {
      AiThinkingShaderRoute.quietThread => 'Quiet thread',
      AiThinkingShaderRoute.packetScan => 'Packet scan',
      AiThinkingShaderRoute.circuitTrace => 'Circuit trace',
      AiThinkingShaderRoute.probabilityBand => 'Probability band',
      AiThinkingShaderRoute.decoderBars => 'Decoder bars',
    };
  }
}

@visibleForTesting
abstract final class AiStateShaderAssets {
  static const voiceInput = 'shaders/ai_voice_input.frag';
  static const thinkingLine = 'shaders/ai_thinking_line.frag';
}

abstract final class AiStateShaderProgramCache {
  static Future<ui.FragmentProgram>? _voiceInputProgram;
  static Future<ui.FragmentProgram>? _thinkingLineProgram;

  static Future<ui.FragmentProgram> loadVoiceInput() {
    return _voiceInputProgram ??= ui.FragmentProgram.fromAsset(
      AiStateShaderAssets.voiceInput,
    );
  }

  static Future<ui.FragmentProgram> loadThinkingLine() {
    return _thinkingLineProgram ??= ui.FragmentProgram.fromAsset(
      AiStateShaderAssets.thinkingLine,
    );
  }

  @visibleForTesting
  static void reset() {
    _voiceInputProgram = null;
    _thinkingLineProgram = null;
  }
}

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

  @override
  void initState() {
    super.initState();
    _programFuture = _loadProgram();
    _controller = AnimationController(vsync: this, duration: _animationLoop);
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
    if (widget.timeOverride == null) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    if (_controller.isAnimating) {
      _controller.stop();
    }
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

class AiThinkingLineShader extends StatefulWidget {
  const AiThinkingLineShader({
    required this.width,
    required this.height,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
    this.speed = 1,
    this.amplitude = 0.58,
    this.randomness = 0.62,
    this.lineCount = 3,
    this.pulse = 0.42,
    this.route = AiThinkingShaderRoute.decoderBars,
    this.timeOverride,
    this.programLoader,
    this.semanticsLabel,
    super.key,
  });

  final double width;
  final double height;
  final double speed;
  final double amplitude;
  final double randomness;
  final int lineCount;
  final double pulse;
  final AiThinkingShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;
  final double? timeOverride;
  final AiShaderProgramLoader? programLoader;
  final String? semanticsLabel;

  @override
  State<AiThinkingLineShader> createState() => _AiThinkingLineShaderState();
}

class _AiThinkingLineShaderState extends State<AiThinkingLineShader>
    with SingleTickerProviderStateMixin {
  static const _animationLoop = Duration(seconds: 40);

  late final AnimationController _controller;
  late Future<ui.FragmentProgram> _programFuture;

  @override
  void initState() {
    super.initState();
    _programFuture = _loadProgram();
    _controller = AnimationController(vsync: this, duration: _animationLoop);
    _syncController();
  }

  @override
  void didUpdateWidget(covariant AiThinkingLineShader oldWidget) {
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
        widget.programLoader ?? AiStateShaderProgramCache.loadThinkingLine;
    return loader();
  }

  void _syncController() {
    if (widget.timeOverride == null) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
      return;
    }

    if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  double get _timeSeconds {
    return widget.timeOverride ??
        _controller.value * _animationLoop.inMilliseconds / 1000;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRect(
          child: RepaintBoundary(
            child: FutureBuilder<ui.FragmentProgram>(
              future: _programFuture,
              builder: (context, snapshot) {
                return AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final time = _timeSeconds;
                    final program = snapshot.data;
                    return CustomPaint(
                      painter: program == null
                          ? AiThinkingLineFallbackPainter(
                              time: time,
                              speed: widget.speed,
                              amplitude: widget.amplitude,
                              randomness: widget.randomness,
                              lineCount: widget.lineCount,
                              pulse: widget.pulse,
                              route: widget.route,
                              primaryColor: widget.primaryColor,
                              secondaryColor: widget.secondaryColor,
                              backgroundColor: widget.backgroundColor,
                            )
                          : AiThinkingLineShaderPainter(
                              program: program,
                              time: time,
                              speed: widget.speed,
                              amplitude: widget.amplitude,
                              randomness: widget.randomness,
                              lineCount: widget.lineCount,
                              pulse: widget.pulse,
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

@visibleForTesting
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
    _setColor(shader, 9, primaryColor);
    _setColor(shader, 13, secondaryColor);
    _setColor(shader, 17, backgroundColor);

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

@visibleForTesting
class AiThinkingLineShaderPainter extends CustomPainter {
  AiThinkingLineShaderPainter({
    required this.program,
    required this.time,
    required this.speed,
    required this.amplitude,
    required this.randomness,
    required this.lineCount,
    required this.pulse,
    required this.route,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  final ui.FragmentProgram program;
  final double time;
  final double speed;
  final double amplitude;
  final double randomness;
  final int lineCount;
  final double pulse;
  final AiThinkingShaderRoute route;
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
      ..setFloat(3, amplitude)
      ..setFloat(4, speed)
      ..setFloat(5, randomness)
      ..setFloat(6, lineCount.toDouble())
      ..setFloat(7, pulse)
      ..setFloat(8, route.index.toDouble());
    _setColor(shader, 9, primaryColor);
    _setColor(shader, 13, secondaryColor);
    _setColor(shader, 17, backgroundColor);

    canvas.drawRect(
      Offset.zero & size,
      Paint()..shader = shader,
    );
  }

  @override
  bool shouldRepaint(AiThinkingLineShaderPainter oldDelegate) {
    return oldDelegate.program != program ||
        oldDelegate.time != time ||
        oldDelegate.speed != speed ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.randomness != randomness ||
        oldDelegate.lineCount != lineCount ||
        oldDelegate.pulse != pulse ||
        oldDelegate.route != route ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

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

@visibleForTesting
class AiThinkingLineFallbackPainter extends CustomPainter {
  AiThinkingLineFallbackPainter({
    required this.time,
    required this.speed,
    required this.amplitude,
    required this.randomness,
    required this.lineCount,
    required this.pulse,
    required this.route,
    required this.primaryColor,
    required this.secondaryColor,
    required this.backgroundColor,
  });

  final double time;
  final double speed;
  final double amplitude;
  final double randomness;
  final int lineCount;
  final double pulse;
  final AiThinkingShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    if (backgroundColor.a > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = backgroundColor);
    }

    final count = lineCount.clamp(1, 6);
    for (var lineIndex = 0; lineIndex < count; lineIndex++) {
      final t = time * speed;
      final layerOffset = (lineIndex - (count - 1) / 2) * size.height * 0.09;
      final path = Path();
      final samples = math.min(math.max(size.width ~/ 4, 12), 48);
      for (var i = 0; i <= samples; i++) {
        final x = size.width * i / samples;
        final progress = i / samples;
        final lowWave = math.sin(
          progress * math.pi * (2.2 + lineIndex * 0.45) +
              t * (0.8 + lineIndex * 0.17),
        );
        final highWave = math.sin(
          progress * math.pi * (8.5 + lineIndex) - t * (1.1 + lineIndex * 0.13),
        );
        final y =
            size.height / 2 +
            layerOffset +
            amplitude *
                size.height *
                (lowWave * 0.13 + highWave * 0.04 * randomness);

        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      final color = Color.lerp(
        primaryColor,
        secondaryColor,
        count == 1 ? 0.0 : lineIndex / (count - 1),
      )!;
      final sweep =
          0.65 + 0.35 * math.sin(t * 1.8 + lineIndex * math.pi * 0.7) * pulse;
      final paint = Paint()
        ..color = color.withValues(alpha: color.a * (0.42 + 0.28 * sweep))
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.height * (0.045 + 0.010 * amplitude)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(AiThinkingLineFallbackPainter oldDelegate) {
    return oldDelegate.time != time ||
        oldDelegate.speed != speed ||
        oldDelegate.amplitude != amplitude ||
        oldDelegate.randomness != randomness ||
        oldDelegate.lineCount != lineCount ||
        oldDelegate.pulse != pulse ||
        oldDelegate.route != route ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

void _setColor(ui.FragmentShader shader, int index, Color color) {
  shader
    ..setFloat(index, color.r)
    ..setFloat(index + 1, color.g)
    ..setFloat(index + 2, color.b)
    ..setFloat(index + 3, color.a);
}
