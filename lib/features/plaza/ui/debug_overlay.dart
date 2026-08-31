import 'package:flutter/material.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';

/// Rolling frame stats published by the harness a few times a second.
class PlazaHarnessStats extends ChangeNotifier {
  double fps = 0;
  double avgFrameMs = 0;
  double worstFrameMs = 0;
  int buildings = 0;
  int near = 0;
  int mid = 0;
  int far = 0;
  int captures = 0;
  double lastCaptureMs = 0;
  int promotions = 0;

  void publish() => notifyListeners();
}

/// World-scale tuning knobs. Changing one rebuilds the scene (they are
/// layout inputs, not surface state), so sliders apply on release.
class PlazaLayoutKnobs {
  double pxPerMeter = 90;
  double roadWidth = 25;
  double maxHeight = 12;
}

/// The M0 instrumentation and knobs: frame time, tier counts, capture
/// stats, plus the levers used to find the live-widget ceiling.
class PlazaDebugOverlay extends StatelessWidget {
  const PlazaDebugOverlay({
    required this.stats,
    required this.config,
    required this.knobs,
    required this.presetLabel,
    required this.onCyclePreset,
    required this.onConfigChanged,
    required this.onKnobsApplied,
    required this.onToggleOverhead,
    super.key,
  });

  final PlazaHarnessStats stats;
  final FacadeLodConfig config;
  final PlazaLayoutKnobs knobs;
  final String presetLabel;
  final VoidCallback onCyclePreset;
  final VoidCallback onConfigChanged;

  /// Fired when a layout slider is released — the scene rebuilds.
  final VoidCallback onKnobsApplied;
  final VoidCallback onToggleOverhead;

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
                    Text(
                      '${stats.avgFrameMs.toStringAsFixed(1)} ms avg\n'
                      '${stats.worstFrameMs.toStringAsFixed(1)} ms worst',
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
                const Divider(color: Color(0xFF2A2E38)),
                Text('buildings ${stats.buildings}   preset $presetLabel'),
                Text(
                  'live ${stats.near}   static ${stats.mid}   '
                  'far ${stats.far}',
                ),
                Text(
                  'captures ${stats.captures}   '
                  'last ${stats.lastCaptureMs.toStringAsFixed(1)} ms   '
                  'promos ${stats.promotions}',
                ),
                const Divider(color: Color(0xFF2A2E38)),
                _slider(
                  label: 'live cap ${config.nearCap}',
                  value: config.nearCap.toDouble(),
                  max: 100,
                  onChanged: (v) {
                    config.nearCap = v.round();
                    onConfigChanged();
                  },
                ),
                _slider(
                  label: 'static cap ${config.midCap}',
                  value: config.midCap.toDouble(),
                  max: 300,
                  onChanged: (v) {
                    config.midCap = v.round();
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
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: onCyclePreset,
                      child: const Text('preset'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: onToggleOverhead,
                      child: const Text('overhead'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'WASD walk · space stop/go · drag look · shift sprint',
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
