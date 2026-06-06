part of 'ai_state_shader_animation.dart';

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
    this.opacity = 1,
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
  final double opacity;
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
                              opacity: widget.opacity,
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
                              opacity: widget.opacity,
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
    this.opacity = 1,
  });

  final ui.FragmentProgram program;
  final double time;
  final double speed;
  final double amplitude;
  final double randomness;
  final int lineCount;
  final double pulse;
  final double opacity;
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
      ..setFloat(8, route.index.toDouble())
      ..setFloat(9, opacity);
    _setColor(shader, 10, primaryColor);
    _setColor(shader, 14, secondaryColor);
    _setColor(shader, 18, backgroundColor);

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
        oldDelegate.opacity != opacity ||
        oldDelegate.route != route ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

@visibleForTesting
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
    this.opacity = 1,
  });

  final double time;
  final double speed;
  final double amplitude;
  final double randomness;
  final int lineCount;
  final double pulse;
  final double opacity;
  final AiThinkingShaderRoute route;
  final Color primaryColor;
  final Color secondaryColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final safeOpacity = opacity.clamp(0.0, 1.0);
    if (backgroundColor.a > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = backgroundColor.withValues(
            alpha: backgroundColor.a * safeOpacity,
          ),
      );
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
        ..color = color.withValues(
          alpha: color.a * safeOpacity * (0.42 + 0.28 * sweep),
        )
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
        oldDelegate.opacity != opacity ||
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
