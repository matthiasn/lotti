import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

/// The static frame the scene holds on when OS reduce-motion is enabled.
const double kSceneryCalmFrameSeconds = 0;

/// A reusable, layered animated backdrop. Composites the [scene]'s ordered
/// layers (shaders interleaved with bitmaps and canvas signals) into a single
/// [CustomPaint], loading the GPU programs once and degrading to per-layer CPU
/// fallbacks until they resolve.
///
/// The clock is injectable: pass [timeSeconds] to drive the scene from an
/// external clock (e.g. the audio-player position) — the widget then repaints
/// whenever its parent rebuilds with a new value. Leave it null to self-drive a
/// [Ticker]. [timeOverride] pins the clock for deterministic tests, and OS
/// reduce-motion freezes the scene on [kSceneryCalmFrameSeconds].
class LayeredBackdrop extends StatefulWidget {
  const LayeredBackdrop({
    required this.scene,
    this.palette = kBlueHourPalette,
    this.timeSeconds,
    this.beatPulse = 0,
    this.skyProgramLoader,
    this.oceanProgramLoader,
    this.timeOverride,
    super.key,
  });

  final BackdropScene scene;
  final BackdropPalette palette;

  /// External clock in seconds; null self-drives a [Ticker].
  final double? timeSeconds;

  /// 0..1 musical-beat intensity forwarded to beat-reactive layers.
  final double beatPulse;

  final SceneryShaderProgramLoader? skyProgramLoader;
  final SceneryShaderProgramLoader? oceanProgramLoader;

  /// Pins the clock for golden/unit tests.
  final double? timeOverride;

  @override
  State<LayeredBackdrop> createState() => _LayeredBackdropState();
}

class _LayeredBackdropState extends State<LayeredBackdrop>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _elapsed = Duration.zero;
  bool _reducedMotion = false;

  ui.FragmentProgram? _skyProgram;
  ui.FragmentProgram? _oceanProgram;

  bool get _usesSelfClock =>
      widget.timeSeconds == null && widget.timeOverride == null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed));
    _loadPrograms();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  @override
  void didUpdateWidget(LayeredBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.skyProgramLoader != widget.skyProgramLoader ||
        oldWidget.oceanProgramLoader != widget.oceanProgramLoader) {
      _loadPrograms();
    }
    _syncTicker();
  }

  void _syncTicker() {
    final shouldRun = _usesSelfClock && !_reducedMotion;
    if (shouldRun && !_ticker.isActive) {
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _ticker.stop();
    }
  }

  void _loadPrograms() {
    final skyLoader =
        widget.skyProgramLoader ?? SceneryShaderProgramCache.loadSky;
    final oceanLoader =
        widget.oceanProgramLoader ?? SceneryShaderProgramCache.loadOcean;
    unawaited(_assign(skyLoader, (p) => _skyProgram = p));
    unawaited(_assign(oceanLoader, (p) => _oceanProgram = p));
  }

  Future<void> _assign(
    SceneryShaderProgramLoader loader,
    void Function(ui.FragmentProgram) store,
  ) async {
    try {
      final program = await loader();
      if (mounted) setState(() => store(program));
    } on Object catch (_) {
      // The program failed to compile/load; the affected layer keeps rendering
      // its CPU fallback. (Web is out of scope; this is load-failure insurance.)
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _time {
    if (widget.timeOverride != null) return widget.timeOverride!;
    if (_reducedMotion) return kSceneryCalmFrameSeconds;
    return widget.timeSeconds ??
        _elapsed.inMicroseconds / Duration.microsecondsPerSecond;
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(
          scene: widget.scene,
          palette: widget.palette,
          timeSeconds: _time,
          beatPulse: widget.beatPulse,
          reducedMotion: _reducedMotion,
          skyProgram: _skyProgram,
          oceanProgram: _oceanProgram,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.scene,
    required this.palette,
    required this.timeSeconds,
    required this.beatPulse,
    required this.reducedMotion,
    this.skyProgram,
    this.oceanProgram,
  });

  final BackdropScene scene;
  final BackdropPalette palette;
  final double timeSeconds;
  final double beatPulse;
  final bool reducedMotion;
  final ui.FragmentProgram? skyProgram;
  final ui.FragmentProgram? oceanProgram;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final ctx = BackdropContext(
      size: size,
      timeSeconds: timeSeconds,
      palette: palette,
      reducedMotion: reducedMotion,
      beatPulse: beatPulse,
      skyProgram: skyProgram,
      oceanProgram: oceanProgram,
    );
    for (final layer in scene.layers) {
      layer.paint(canvas, ctx);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) {
    return old.scene != scene ||
        old.palette != palette ||
        old.timeSeconds != timeSeconds ||
        old.beatPulse != beatPulse ||
        old.reducedMotion != reducedMotion ||
        old.skyProgram != skyProgram ||
        old.oceanProgram != oceanProgram;
  }
}
