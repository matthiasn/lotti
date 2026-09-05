import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:material_ui/material_ui.dart';

/// Rolling frame stats published by the harness a few times a second.
class PlazaHarnessStats extends ChangeNotifier {
  /// Frames the harness painted per second, and frames the engine
  /// produced per second: the two differ when something other than the
  /// pacer keeps the engine running (a widget capture's frame pump, an
  /// animation controller inside a captured surface).
  double fps = 0;
  double engineFps = 0;
  double avgFrameMs = 0;
  double worstFrameMs = 0;
  int buildings = 0;
  int get live => lod.live;
  int get sign => lod.sign;
  int get far => lod.far;
  int get captures => lod.captures;
  int surfaceCaptures = 0;
  double get lastCaptureMs => lod.lastCapture.inMicroseconds / 1000;
  FacadeLodStats lod = FacadeLodStats();
  int get promotions => lod.promotions;

  void publish() => notifyListeners();
}

/// How often the harness paints a frame; the HUD's segmented control
/// picks one. The scene is animated (tickers, chase lights, pulsing
/// glows), so without a cap it paints on every vsync, 120 times a second
/// on a ProMotion display, and re-encodes the whole district each time.
enum PlazaFrameRate {
  /// Display rate on movement/input, 30 Hz for live facades, 15 Hz at rest.
  auto,
  sixty,
  thirty;

  /// Uses the explicit development override, or saves idle work by default.
  static PlazaFrameRate fromEnvironment(Map<String, String> environment) =>
      values.firstWhere(
        (rate) => rate.label == environment['PLAZA_FPS'],
        orElse: () => auto,
      );

  String get label => switch (this) {
    PlazaFrameRate.auto => 'auto',
    PlazaFrameRate.sixty => '60',
    PlazaFrameRate.thirty => '30',
  };

  /// The cap, frames per second, or null for the display's rate.
  double? capFor({required bool moving, bool activeSurface = false}) =>
      switch (this) {
        PlazaFrameRate.auto =>
          moving
              ? null
              : activeSurface
              ? 30
              : 15,
        PlazaFrameRate.sixty => 60,
        PlazaFrameRate.thirty => 30,
      };
}

/// World-scale tuning knobs. Changing one rebuilds the scene (they are
/// layout inputs, not surface state), so sliders apply on release.
class PlazaLayoutKnobs {
  double pxPerMeter = 90;
  double roadWidth = 25;
  double maxHeight = 14;
}

/// Frame time, tier counts, capture stats and the LOD budget knobs.
/// Hidden by default; the Debug box in the HUD (or the backtick key)
/// shows it.
class PlazaDebugOverlay extends StatelessWidget {
  const PlazaDebugOverlay({
    required this.stats,
    required this.config,
    required this.knobs,
    required this.datasetLabel,
    required this.onConfigChanged,
    required this.onKnobsApplied,
    super.key,
  });

  final PlazaHarnessStats stats;
  final FacadeLodConfig config;
  final PlazaLayoutKnobs knobs;
  final String datasetLabel;
  final VoidCallback onConfigChanged;

  /// Fired when a layout slider is released — the scene rebuilds.
  final VoidCallback onKnobsApplied;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: stats,
      builder: (context, _) {
        final good = stats.fps >= 55;
        return Container(
          width: 280,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xE6101218),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: Color(0xFFD6DAE3),
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${stats.fps.toStringAsFixed(0)} fps',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: good
                            ? const Color(0xFF63C99A)
                            : const Color(0xFFE87C6C),
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${stats.avgFrameMs.toStringAsFixed(1)} ms avg\n'
                          '${stats.worstFrameMs.toStringAsFixed(1)} ms worst\n'
                          'engine ${stats.engineFps.toStringAsFixed(0)} fps',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF2A2E38)),
                Text('buildings ${stats.buildings}   data $datasetLabel'),
                Text(
                  'live ${stats.live}   sign ${stats.sign}   far ${stats.far}',
                ),
                Text(
                  'captures ${stats.captures}+${stats.surfaceCaptures}   '
                  'last ${stats.lastCaptureMs.toStringAsFixed(1)} ms   '
                  'promos ${stats.promotions}',
                ),
                const Divider(color: Color(0xFF2A2E38)),
                _slider(
                  label: 'live cap ${config.liveCap}',
                  value: config.liveCap.toDouble(),
                  max: 40,
                  onChanged: (v) {
                    config.liveCap = v.round();
                    onConfigChanged();
                  },
                ),
                _slider(
                  label: 'sign cap ${config.signCap}',
                  value: config.signCap.toDouble(),
                  max: 300,
                  onChanged: (v) {
                    config.signCap = v.round();
                    onConfigChanged();
                  },
                ),
                _slider(
                  label: 'live ${config.liveDistance.round()} m',
                  value: config.liveDistance,
                  min: 5,
                  max: 80,
                  onChanged: (v) {
                    config.liveDistance = v;
                    onConfigChanged();
                  },
                ),
                _slider(
                  label: 'sign ${config.signDistance.round()} m',
                  value: config.signDistance,
                  min: 20,
                  max: 400,
                  onChanged: (v) {
                    config.signDistance = v;
                    onConfigChanged();
                  },
                ),
                _slider(
                  label: 'px/m ${knobs.pxPerMeter.round()}',
                  value: knobs.pxPerMeter,
                  min: 40,
                  max: 160,
                  onChanged: (v) {
                    knobs.pxPerMeter = v;
                    onConfigChanged();
                  },
                  onChangeEnd: (_) => onKnobsApplied(),
                ),
                _slider(
                  label: 'road ${knobs.roadWidth.round()} m',
                  value: knobs.roadWidth,
                  min: 6,
                  max: 50,
                  onChanged: (v) {
                    knobs.roadWidth = v;
                    onConfigChanged();
                  },
                  onChangeEnd: (_) => onKnobsApplied(),
                ),
                _slider(
                  label: 'max h ${knobs.maxHeight.round()} m',
                  value: knobs.maxHeight,
                  min: 4,
                  max: 25,
                  onChanged: (v) {
                    knobs.maxHeight = v;
                    onConfigChanged();
                  },
                  onChangeEnd: (_) => onKnobsApplied(),
                ),
                Row(
                  children: [
                    const Expanded(child: Text('ALL LIVE (stress)')),
                    Switch(
                      value: config.forceAllLive,
                      onChanged: (v) {
                        config.forceAllLive = v;
                        onConfigChanged();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'the Debug box in the HUD hides this panel',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slider({
    required String label,
    required double value,
    required double max,
    required ValueChanged<double> onChanged,
    double min = 0,
    ValueChanged<double>? onChangeEnd,
  }) {
    return Row(
      children: [
        SizedBox(width: 110, child: Text(label)),
        Expanded(
          child: SliderTheme(
            data: const SliderThemeData(
              trackHeight: 2,
              thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
      ],
    );
  }
}
