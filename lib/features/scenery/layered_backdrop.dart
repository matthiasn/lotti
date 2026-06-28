import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/runtime/scenery_shaders.dart';

/// The static frame the scene holds on when OS reduce-motion is enabled.
const double kSceneryCalmFrameSeconds = 0;

/// Decodes a bundled image asset to a [ui.Image]. Injectable so tests can
/// supply fakes.
typedef SceneryImageLoader = Future<ui.Image> Function(String assetPath);

Future<ui.Image> _defaultImageLoader(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

/// A reusable, layered animated backdrop. Composites the [scene]'s ordered
/// layers (painted bitmaps, shaders and canvas signals) behind an optional
/// [child], with the scene's foreground layers drawn in front of it. GPU
/// programs and bitmap assets load once and the affected layers degrade to CPU
/// fallbacks / no-ops until they resolve.
///
/// The clock is injectable: pass [timeSeconds] to drive the scene from an
/// external clock (e.g. the audio-player position) — the widget repaints
/// whenever its parent rebuilds with a new value. Leave it null to self-drive a
/// [Ticker]. [timeOverride] pins the clock for tests, and OS reduce-motion
/// freezes the scene on [kSceneryCalmFrameSeconds].
class LayeredBackdrop extends StatefulWidget {
  const LayeredBackdrop({
    required this.scene,
    this.child,
    this.palette = kBlueHourPalette,
    this.timeSeconds,
    this.beatPulse = 0,
    this.skyProgramLoader,
    this.oceanProgramLoader,
    this.imageLoader,
    this.timeOverride,
    super.key,
  });

  final BackdropScene scene;

  /// Content drawn between the scene's background and foreground layers.
  final Widget? child;

  final BackdropPalette palette;

  /// External clock in seconds; null self-drives a [Ticker].
  final double? timeSeconds;

  /// 0..1 musical-beat intensity forwarded to beat-reactive layers.
  final double beatPulse;

  final SceneryShaderProgramLoader? skyProgramLoader;
  final SceneryShaderProgramLoader? oceanProgramLoader;
  final SceneryImageLoader? imageLoader;

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
  ui.FragmentProgram? _cityLightsProgram;
  final Map<String, ui.Image> _images = {};
  int _imagesVersion = 0;

  bool get _usesSelfClock =>
      widget.timeSeconds == null && widget.timeOverride == null;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) => setState(() => _elapsed = elapsed));
    _loadPrograms();
    _loadImages();
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
    if (oldWidget.scene.imageAssets != widget.scene.imageAssets) {
      _loadImages();
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
    unawaited(_assignProgram(skyLoader, (p) => _skyProgram = p));
    unawaited(_assignProgram(oceanLoader, (p) => _oceanProgram = p));
    unawaited(
      _assignProgram(
        SceneryShaderProgramCache.loadCityLights,
        (p) => _cityLightsProgram = p,
      ),
    );
  }

  Future<void> _assignProgram(
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

  void _loadImages() {
    final loader = widget.imageLoader ?? _defaultImageLoader;
    for (final asset in widget.scene.imageAssets) {
      if (_images.containsKey(asset)) continue;
      unawaited(_assignImage(loader, asset));
    }
  }

  Future<void> _assignImage(SceneryImageLoader loader, String asset) async {
    try {
      final image = await loader(asset);
      if (!mounted) {
        image.dispose();
        return;
      }
      setState(() {
        _images[asset] = image;
        _imagesVersion++;
      });
    } on Object catch (_) {
      // Asset failed to decode; the ImageLayer no-ops (graceful degrade).
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    for (final image in _images.values) {
      image.dispose();
    }
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
    final time = _time;
    final background = _backdropPaint(widget.scene.layers, time);

    if (widget.child == null && widget.scene.foregroundLayers.isEmpty) {
      return background;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        background,
        if (widget.child != null) widget.child!,
        if (widget.scene.foregroundLayers.isNotEmpty)
          _backdropPaint(widget.scene.foregroundLayers, time),
      ],
    );
  }

  // Paints [layers] at the viewport size. Each layer cover-fits the art into the
  // viewport itself (the master plate via BoxFit.cover, the lights via the same
  // coverFit mapping), so painted art, shader mask sampling and light anchors
  // all stay aligned at any aspect ratio.
  Widget _backdropPaint(List<BackdropLayer> layers, double time) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _BackdropPainter(
          layers: layers,
          palette: widget.palette,
          timeSeconds: time,
          beatPulse: widget.beatPulse,
          reducedMotion: _reducedMotion,
          skyProgram: _skyProgram,
          oceanProgram: _oceanProgram,
          cityLightsProgram: _cityLightsProgram,
          images: _images,
          imagesVersion: _imagesVersion,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({
    required this.layers,
    required this.palette,
    required this.timeSeconds,
    required this.beatPulse,
    required this.reducedMotion,
    required this.images,
    required this.imagesVersion,
    this.skyProgram,
    this.oceanProgram,
    this.cityLightsProgram,
  });

  final List<BackdropLayer> layers;
  final BackdropPalette palette;
  final double timeSeconds;
  final double beatPulse;
  final bool reducedMotion;
  final Map<String, ui.Image> images;
  final int imagesVersion;
  final ui.FragmentProgram? skyProgram;
  final ui.FragmentProgram? oceanProgram;
  final ui.FragmentProgram? cityLightsProgram;

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
      images: images,
    );
    for (final layer in layers) {
      layer.paint(canvas, ctx);
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) {
    return old.layers != layers ||
        old.palette != palette ||
        old.timeSeconds != timeSeconds ||
        old.beatPulse != beatPulse ||
        old.reducedMotion != reducedMotion ||
        old.skyProgram != skyProgram ||
        old.oceanProgram != oceanProgram ||
        old.imagesVersion != imagesVersion;
  }
}
