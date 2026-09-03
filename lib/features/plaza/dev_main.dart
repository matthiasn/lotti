/// Standalone dev entrypoint for the project plaza prototype (M0 perf
/// spike): a street of task buildings with live widget facades, surface
/// LOD, and a debug overlay for finding the live-widget ceiling.
///
/// Run it directly (Flutter GPU must be enabled):
///   fvm flutter run --enable-flutter-gpu \
///       -t lib/features/plaza/dev_main.dart -d linux
///   fvm flutter run --enable-flutter-gpu \
///       -t lib/features/plaza/dev_main.dart -d macos
///
/// This is a developer harness only — it is not part of the shipping app.
///
/// Benchmark mode: launch with `PLAZA_BENCH=1` in the environment and the
/// harness auto-walks the street through a fixed set of LOD configurations,
/// printing an fps table (`PLAZA_BENCH` lines) to stdout.
///
/// Tour mode: launch with `PLAZA_TOUR=1` and the harness steps through the
/// fixed camera poses in `ui/plaza_tour.dart` (the documentation
/// screenshots), holding each for a few seconds and printing
/// `PLAZA_TOUR ready <index> <name>` once the pose has settled — an external
/// capture script keys on those lines. Keyboard/mouse input still works, so
/// a stop can be interacted with before the next one.
library;

import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart' hide FlyCameraController;
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/domain/plaza_generator.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/fly_camera_controller.dart';
import 'package:lotti/features/plaza/ui/plaza_tour.dart';

void main() => runApp(const PlazaDevApp());

/// The datasets the harness can cycle through. `demo` projects real task
/// surfaces from the penguin demo world; the rest are synthetic presets.
enum _HarnessPreset {
  demo('waddle'),
  small('20'),
  medium('80'),
  large('300');

  const _HarnessPreset(this.label);

  final String label;

  List<PlazaTask> load() => switch (this) {
    demo => plazaTasksFromDemoWorld(),
    small => generatePlazaTasks(preset: PlazaPreset.small),
    medium => generatePlazaTasks(preset: PlazaPreset.medium),
    large => generatePlazaTasks(preset: PlazaPreset.large),
  };
}

class PlazaDevApp extends StatelessWidget {
  const PlazaDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const _PlazaHarness(),
    );
  }
}

class _PlazaHarness extends StatefulWidget {
  const _PlazaHarness();

  @override
  State<_PlazaHarness> createState() => _PlazaHarnessState();
}

class _PlazaHarnessState extends State<_PlazaHarness> {
  // Boots on the 300-task perf preset; override with PLAZA_PRESET=demo
  // (or small/medium/large) to start elsewhere, e.g. on the penguin world.
  _HarnessPreset _preset = _HarnessPreset.values.firstWhere(
    (p) => p.name == Platform.environment['PLAZA_PRESET'],
    orElse: () => _HarnessPreset.large,
  );
  late PlazaSceneController _sceneController;
  late FacadeLodManager _lod;
  late FlyCameraController _camera;
  final FacadeLodConfig _config = FacadeLodConfig();
  final PlazaLayoutKnobs _knobs = PlazaLayoutKnobs();
  final PlazaHarnessStats _stats = PlazaHarnessStats();

  Camera? _frameCamera;

  // Rolling frame-time window.
  final List<double> _frameMs = [];
  double _statsAge = 0;

  // --- Benchmark mode (PLAZA_BENCH=1) ---
  static final bool _benchMode = Platform.environment['PLAZA_BENCH'] == '1';
  static const _benchPhaseSeconds = 14.0;
  static const _benchWarmupSeconds = 4.0;
  // (label, nearCap, midCap, nearDistance, midDistance, forceAllLive).
  // The saturated phases stretch the distance thresholds so the caps are
  // the binding limit, not the walkway geometry.
  static const _benchPhases = <(String, int, int, double, double, bool)>[
    ('far-only    (no widgets)', 0, 0, 35, 140, false),
    ('default     (12 live / 60 static)', 12, 60, 35, 140, false),
    ('sat-live-30 (30 live, saturated)', 30, 0, 4000, 4000, false),
    ('sat-live-60 (60 live, saturated)', 60, 0, 4000, 4000, false),
    ('all-static  (292 hosted, no capture)', 0, 300, 4000, 4000, false),
    ('all-live    (every facade live)', 0, 0, 35, 140, true),
  ];
  int _benchPhase = 0;
  double _benchClock = 0;
  final List<double> _benchSamples = [];
  bool _benchDone = false;

  // --- Tour mode (PLAZA_TOUR=1) ---
  static final bool _tourMode = Platform.environment['PLAZA_TOUR'] == '1';
  static const _tourSettleSeconds = 5.0;
  static const _tourHoldSeconds = 9.0;
  int _tourStop = -1;
  double _tourClock = 0;
  bool _tourAnnounced = false;
  bool _tourDone = false;

  @override
  void initState() {
    super.initState();
    if (_tourMode) {
      _preset = _HarnessPreset.large;
    }
    if (_benchMode) {
      // The bench phases assume the 300-task workload (their labels and
      // saturation caps are sized for it), so the preset override is
      // ignored in benchmark mode.
      _preset = _HarnessPreset.large;
    }
    _loadPreset(_preset);
    if (_benchMode) {
      _applyBenchPhase(0);
    }
    if (_tourMode && !_benchMode) {
      _applyTourStop(0);
    }
  }

  _HarnessPreset _presetFor(TourPreset preset) => switch (preset) {
    TourPreset.large => _HarnessPreset.large,
    TourPreset.demo => _HarnessPreset.demo,
  };

  void _applyTourStop(int index) {
    final stop = plazaTourStops[index];
    final wanted = _presetFor(stop.preset);
    if (wanted != _preset) {
      _lod.dispose();
      _loadPreset(wanted);
      // A fresh scene needs a rebuild before the pose is worth showing.
      if (mounted) setState(() {});
    }
    final pose = stop.pose(TourScene.fromController(_sceneController));
    _camera
      ..reset(position: pose.position, yaw: pose.yaw, pitch: pose.pitch)
      ..overhead = pose.overhead
      ..autoForward = 0;
    _tourStop = index;
    _tourClock = 0;
    _tourAnnounced = false;
    debugPrint('PLAZA_TOUR stop $index start: ${stop.name}');
  }

  void _tourTick(double dt) {
    if (_tourDone || _tourStop < 0) return;
    _tourClock += dt;
    if (!_tourAnnounced && _tourClock >= _tourSettleSeconds) {
      _tourAnnounced = true;
      debugPrint(
        'PLAZA_TOUR ready $_tourStop ${plazaTourStops[_tourStop].name}',
      );
    }
    if (_tourClock < _tourHoldSeconds) return;
    if (_tourStop + 1 < plazaTourStops.length) {
      _applyTourStop(_tourStop + 1);
    } else {
      _tourDone = true;
      debugPrint('PLAZA_TOUR done');
    }
  }

  void _applyBenchPhase(int phase) {
    final (label, nearCap, midCap, nearDist, midDist, allLive) =
        _benchPhases[phase];
    _config
      ..nearCap = nearCap
      ..midCap = midCap
      ..nearDistance = nearDist
      ..midDistance = midDist
      ..forceAllLive = allLive;
    _camera
      ..reset(
        position: _sceneController.frontierEye,
        yaw: _sceneController.frontierYaw,
      )
      ..autoForward = 1;
    _benchClock = 0;
    _benchSamples.clear();
    debugPrint('PLAZA_BENCH phase $phase start: $label');
  }

  void _benchTick(double dt) {
    if (_benchDone) return;
    _benchClock += dt;
    if (_benchClock > _benchWarmupSeconds && dt > 0) {
      _benchSamples.add(dt * 1000);
    }
    if (_benchClock < _benchPhaseSeconds) return;

    final avg =
        _benchSamples.fold<double>(0, (a, b) => a + b) / _benchSamples.length;
    final worst = _benchSamples.reduce((a, b) => a > b ? a : b);
    final sorted = [..._benchSamples]..sort();
    final p99 =
        sorted[(sorted.length * 0.99).floor().clamp(0, sorted.length - 1)];
    final (label, _, _, _, _, _) = _benchPhases[_benchPhase];
    debugPrint(
      'PLAZA_BENCH result | $label | '
      '${(1000 / avg).toStringAsFixed(1)} fps avg | '
      '${avg.toStringAsFixed(1)} ms avg | '
      '${p99.toStringAsFixed(1)} ms p99 | '
      '${worst.toStringAsFixed(1)} ms worst | '
      'live ${_lod.stats.near} static ${_lod.stats.mid} '
      'captures ${_lod.stats.captures}',
    );

    if (_benchPhase + 1 < _benchPhases.length) {
      _benchPhase++;
      _applyBenchPhase(_benchPhase);
    } else {
      _benchDone = true;
      _camera.autoForward = 0;
      debugPrint('PLAZA_BENCH done');
    }
  }

  void _loadPreset(_HarnessPreset preset) {
    _preset = preset;
    _sceneController = PlazaSceneController(
      tasks: preset.load(),
      projectSeed: 1337,
      layout: StreetLayout(
        projectSeed: 1337,
        roadWidth: _knobs.roadWidth,
        pxPerMeter: _knobs.pxPerMeter,
        maxBuildingHeight: _knobs.maxHeight,
      ),
    );
    _lod = FacadeLodManager(
      buildings: _sceneController.buildings,
      config: _config,
    );
    _camera = FlyCameraController(
      position: _sceneController.frontierEye,
      yaw: _sceneController.frontierYaw,
    );
  }

  void _cyclePreset() {
    _lod.dispose();
    setState(() {
      final next = (_preset.index + 1) % _HarnessPreset.values.length;
      _loadPreset(_HarnessPreset.values[next]);
    });
  }

  /// Rebuilds the scene with the current layout knobs, keeping the preset.
  void _applyKnobs() {
    _lod.dispose();
    setState(() => _loadPreset(_preset));
    // _loadPreset replaces the camera; keep the scripted walk going if a
    // benchmark phase is mid-flight.
    if (_benchMode && !_benchDone) {
      _camera.autoForward = 1;
    }
  }

  void _onTick(Duration elapsed, double dt) {
    if (_benchMode) _benchTick(dt);
    if (_tourMode && !_benchMode) _tourTick(dt);
    _camera.update(dt);
    final camera = _camera.camera();
    _frameCamera = camera;
    _lod.update(camera.position);

    if (dt > 0) {
      _frameMs.add(dt * 1000);
      if (_frameMs.length > 120) _frameMs.removeAt(0);
    }
    _statsAge += dt;
    if (_statsAge >= 0.25 && _frameMs.isNotEmpty) {
      _statsAge = 0;
      final sum = _frameMs.fold<double>(0, (a, b) => a + b);
      final avg = sum / _frameMs.length;
      _stats
        ..fps = 1000 / avg
        ..avgFrameMs = avg
        ..worstFrameMs = _frameMs.reduce((a, b) => a > b ? a : b)
        ..buildings = _sceneController.buildings.length
        ..near = _lod.stats.near
        ..mid = _lod.stats.mid
        ..far = _lod.stats.far
        ..captures = _lod.stats.captures
        ..lastCaptureMs = _lod.stats.lastCapture.inMicroseconds / 1000
        ..promotions = _lod.stats.promotions
        ..publish();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06070C),
      body: Focus(
        autofocus: true,
        onKeyEvent: (node, event) => _camera.handleKeyEvent(event)
            ? KeyEventResult.handled
            : KeyEventResult.ignored,
        child: Listener(
          onPointerMove: (event) {
            if (event.buttons != 0) {
              _camera.addLookDelta(event.delta.dx, event.delta.dy);
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: SceneView(
                  _sceneController.scene,
                  cameraBuilder: (_) => _frameCamera ?? _camera.camera(),
                  onTick: _onTick,
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: PlazaDebugOverlay(
                      stats: _stats,
                      config: _config,
                      knobs: _knobs,
                      presetLabel: _preset.label,
                      onCyclePreset: _cyclePreset,
                      onConfigChanged: () => setState(() {}),
                      onKnobsApplied: _applyKnobs,
                      onToggleOverhead: _camera.toggleOverhead,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
