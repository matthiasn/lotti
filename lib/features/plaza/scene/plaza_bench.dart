import 'package:flutter/foundation.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:lotti/features/plaza/ui/fly_camera_controller.dart';

/// `PLAZA_BENCH=1`: auto-walks the penguin street from home through a
/// fixed set of LOD budgets, printing an fps table (`PLAZA_BENCH result`
/// lines) to stdout. Relative numbers are what matter; the VM is slow.
class PlazaBench {
  static const phaseSeconds = 14.0;
  static const warmupSeconds = 4.0;

  // (label, liveCap, signCap, liveDistance, signDistance, forceAllLive).
  // The saturated phases stretch the distance thresholds so the caps are
  // the binding limit, not the walkway geometry.
  static const phases = <(String, int, int, double, double, bool)>[
    ('far-only    (no widgets)', 0, 0, 26, 140, false),
    ('default     (4 live / 80 sign)', 4, 80, 26, 140, false),
    ('sat-live-30 (30 live, saturated)', 30, 0, 4000, 4000, false),
    ('sat-live-60 (60 live, saturated)', 60, 0, 4000, 4000, false),
    ('all-sign    (every facade hosted)', 0, 300, 4000, 4000, false),
    ('all-live    (every facade live)', 0, 0, 26, 140, true),
  ];

  int _phase = 0;
  double _clock = 0;
  final List<double> _samples = [];
  bool _done = false;
  late FacadeLodConfig _config;

  bool get done => _done;

  void start(FacadeLodConfig config, FlyCameraController camera) {
    _config = config;
    _apply(0, camera);
  }

  /// After a scene rebuild the camera is new; keep walking.
  void resume(FlyCameraController camera) {
    if (!_done) camera.autoForward = 1;
  }

  void _apply(int phase, FlyCameraController camera) {
    final (label, liveCap, signCap, liveDist, signDist, allLive) =
        phases[phase];
    _config
      ..liveCap = liveCap
      ..signCap = signCap
      ..liveDistance = liveDist
      ..signDistance = signDist
      ..forceAllLive = allLive;
    camera.autoForward = 1;
    _clock = 0;
    _samples.clear();
    debugPrint('PLAZA_BENCH phase $phase start: $label');
  }

  void tick(double dt, FacadeLodManager lod, FlyCameraController camera) {
    if (_done) return;
    _clock += dt;
    if (_clock > warmupSeconds && dt > 0) _samples.add(dt * 1000);
    if (_clock < phaseSeconds) return;

    final avg = _samples.fold<double>(0, (a, b) => a + b) / _samples.length;
    final worst = _samples.reduce((a, b) => a > b ? a : b);
    final sorted = [..._samples]..sort();
    final p99 =
        sorted[(sorted.length * 0.99).floor().clamp(0, sorted.length - 1)];
    final (label, _, _, _, _, _) = phases[_phase];
    debugPrint(
      'PLAZA_BENCH result | $label | '
      '${(1000 / avg).toStringAsFixed(1)} fps avg | '
      '${avg.toStringAsFixed(1)} ms avg | '
      '${p99.toStringAsFixed(1)} ms p99 | '
      '${worst.toStringAsFixed(1)} ms worst | '
      'live ${lod.stats.live} sign ${lod.stats.sign} '
      'captures ${lod.stats.captures}',
    );

    if (_phase + 1 < phases.length) {
      _phase++;
      _apply(_phase, camera);
    } else {
      _done = true;
      camera.autoForward = 0;
      debugPrint('PLAZA_BENCH done');
    }
  }
}
