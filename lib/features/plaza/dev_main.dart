/// Standalone dev entrypoint for the project plaza prototype: the penguin
/// demo world as a walkable district with a frontier plaza, billboards,
/// beacons, flights and the morning walk.
///
/// Run it directly (Flutter GPU must be enabled):
///   fvm flutter run --enable-flutter-gpu \
///       -t lib/features/plaza/dev_main.dart -d linux
///   fvm flutter run --enable-flutter-gpu \
///       -t lib/features/plaza/dev_main.dart -d macos
///
/// This is a developer harness only — it is not part of the shipping app.
///
/// Benchmark mode: `PLAZA_BENCH=1` auto-walks the penguin street from home
/// through a fixed set of LOD budgets, printing an fps table
/// (`PLAZA_BENCH` lines) to stdout.
///
/// Tour mode: `PLAZA_TOUR=1` steps through the fixed poses in
/// `ui/plaza_tour.dart` (the documentation screenshots), printing
/// `PLAZA_TOUR ready <index> <name>` once each has settled.
library;

import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding, Ticker;
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart' hide FlyCameraController;
import 'package:lotti/features/demo/seed/demo_world.dart' show manualDemoNow;
import 'package:lotti/features/design_system/theme/design_system_theme.dart';
import 'package:lotti/features/plaza/data/demo_world_projection.dart';
import 'package:lotti/features/plaza/domain/morning_walk.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:lotti/features/plaza/scene/plaza_bench.dart';
import 'package:lotti/features/plaza/scene/plaza_picker.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/scene/plaza_sprites.dart';
import 'package:lotti/features/plaza/scene/plaza_surfaces.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/wall_textures.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/fly_camera_controller.dart';
import 'package:lotti/features/plaza/ui/plaza_hud.dart';
import 'package:lotti/features/plaza/ui/plaza_search_sheet.dart';
import 'package:lotti/features/plaza/ui/plaza_tour.dart';
import 'package:lotti/features/plaza/ui/task_side_panel.dart';

void main() => runApp(const PlazaDevApp());

class PlazaDevApp extends StatelessWidget {
  const PlazaDevApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: DesignSystemTheme.dark(),
      home: const _PlazaHarness(),
    );
  }
}

class _PlazaHarness extends StatefulWidget {
  const _PlazaHarness();

  @override
  State<_PlazaHarness> createState() => _PlazaHarnessState();
}

/// What the harness is doing: driven by hand, stepping through the tour's
/// screenshot poses, or running the benchmark. A scripted run takes no
/// input and paints on every vsync.
enum HarnessMode {
  interactive,
  tour,
  bench;

  /// `PLAZA_BENCH=1` wins over `PLAZA_TOUR=1`; neither is interactive.
  static HarnessMode fromEnvironment(Map<String, String> env) {
    if (env['PLAZA_BENCH'] == '1') return HarnessMode.bench;
    if (env['PLAZA_TOUR'] == '1') return HarnessMode.tour;
    return HarnessMode.interactive;
  }

  bool get scripted => this != HarnessMode.interactive;
}

class _PlazaHarnessState extends State<_PlazaHarness>
    with SingleTickerProviderStateMixin {
  static final HarnessMode _mode = HarnessMode.fromEnvironment(
    Platform.environment,
  );

  /// Dev-only: `PLAZA_HIDE=gantry,jumbotron,fillers,skyline,pylons,walls`
  /// leaves those pieces out of the scene, to isolate what a screenshot
  /// is showing.
  static final Set<String> _hidden = {
    ...?Platform.environment['PLAZA_HIDE']?.split(','),
  };

  /// `PLAZA_TRACE=1` prints one line per frame: the frame time, whether a
  /// flight is under way, the pose, and how many solids contain the eye —
  /// the ground truth for a stall, a missing flight or a wall flown
  /// through, read off the running harness rather than a unit test.
  static final bool _traceMode = Platform.environment['PLAZA_TRACE'] == '1';

  /// The harness owns the frame pacing: the scene view does not tick on
  /// its own, a ticker here paints at most [_frameRate] frames a second
  /// (the benchmark and the tour paint on every vsync). Every painted
  /// frame runs [_onTick] first.
  PlazaFrameRate _frameRate = _initialFrameRate();
  Ticker? _pacer;

  /// `PLAZA_FPS=auto|60|30` picks the cap at start; 60 otherwise.
  static PlazaFrameRate _initialFrameRate() {
    final wanted = Platform.environment['PLAZA_FPS'];
    return PlazaFrameRate.values.firstWhere(
      (rate) => rate.label == wanted,
      orElse: () => PlazaFrameRate.sixty,
    );
  }

  Duration? _lastPaint;
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// Movement keeps the display's rate on `auto` for this long after it
  /// stops, so a coast to a halt is smooth.
  static const _movingHold = 0.6;
  double _movingUntil = 0;

  /// Frames the engine produced since the stats were last published,
  /// counted on a persistent frame callback: the number that shows whether
  /// anything besides the pacer keeps the engine running.
  int _engineFrames = 0;
  int _engineFramesSinceTrace = 0;
  late final PlazaBench? _bench = _mode == HarnessMode.bench
      ? PlazaBench()
      : null;

  late PlazaWorld _world;
  late PlazaSceneController _sceneController;
  late FacadeLodManager _lod;
  late PlazaSprites _sprites;
  late PlazaSurfaces _surfaces;
  late PlazaPicker _picker;
  late FlyCameraController _camera;
  final ChecklistTicks _ticks = ChecklistTicks();
  final FacadeLodConfig _config = FacadeLodConfig();
  final PlazaLayoutKnobs _knobs = PlazaLayoutKnobs();
  final PlazaHarnessStats _stats = PlazaHarnessStats();

  Camera? _frameCamera;
  Size _viewSize = const Size(1, 1);

  /// Seconds since boot, advanced once per painted frame: the harness's
  /// one time value, which the surfaces turn into their capture clocks.
  double _elapsed = 0;

  // HUD state.
  String? _toast;
  double _toastUntil = 0;
  MorningWalk? _walk;
  PlazaBuilding? _panel;
  bool _searchOpen = false;
  bool _showDebug = false;
  final List<CameraPose> _back = [];
  int _beaconCursor = -1;

  // Tap-versus-drag.
  Offset? _pointerDown;
  double _pointerDownAt = 0;
  bool _dragging = false;

  // Rolling frame-time window.
  final List<double> _frameMs = [];
  double _statsAge = 0;

  // Tour mode.
  static const _tourSettleSeconds = 5.0;
  static const _tourHoldSeconds = 9.0;
  int _tourStop = -1;
  double _tourClock = 0;
  bool _tourAnnounced = false;
  bool _tourDone = false;

  /// Sprites and the gradient sky touch the base shader library, which must
  /// be loaded before any of them is constructed.
  bool _ready = false;
  WallTextures? _walls;

  @override
  void initState() {
    super.initState();
    unawaited(_boot());
  }

  Future<void> _boot() async {
    await Scene.initializeStaticResources();
    _walls = await WallTextures.load();
    if (!mounted) return;
    _load();
    switch (_mode) {
      case HarnessMode.bench:
        _bench!.start(_config, _camera);
      case HarnessMode.tour:
        _applyTourStop(0);
      case HarnessMode.interactive:
        _showToast('Home — ${_world.projectLabel}');
    }
    setState(() => _ready = true);
    _pacer = createTicker(_onPace)..start();
    SchedulerBinding.instance.addPersistentFrameCallback((_) {
      _engineFrames++;
      _engineFramesSinceTrace++;
    });
  }

  @override
  void dispose() {
    _pacer?.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Whether anything moves the camera: a flight, the walk, a held key or
  /// a drag; the tour and the benchmark always count as moving.
  bool get _moving =>
      _mode.scripted ||
      _camera.flying ||
      _camera.moving ||
      _dragging ||
      _walk != null;

  void _onPace(Duration elapsed) {
    final last = _lastPaint;
    final seconds = elapsed.inMicroseconds / 1e6;
    if (_moving) _movingUntil = seconds + _movingHold;
    final cap = _mode.scripted
        ? null
        : _frameRate.capFor(moving: seconds < _movingUntil);
    if (last != null && cap != null) {
      // A hair under the interval: a 60 Hz cap on a 60 Hz display must
      // not skip every other vsync to jitter.
      final due = last + Duration(microseconds: (1e6 / cap * 0.9).round());
      if (elapsed < due) return;
    }
    final dt = last == null ? 1 / 60 : (elapsed - last).inMicroseconds / 1e6;
    _lastPaint = elapsed;
    _onTick(elapsed, dt);
    _frame.value++;
  }

  // ---------------------------------------------------------------- data

  void _load() {
    // The demo world is expressed against its fixture clock ("overdue by
    // two days" is relative to it), so score it against the same.
    final tasks = plazaTasksFromDemoWorld(now: manualDemoNow);
    final now = manualDemoNow;
    const label = 'Project Waddle';
    final categoryLabels = demoCategoryLabels(now: manualDemoNow);
    _world = PlazaWorld(
      tasks: tasks,
      now: now,
      projectLabel: label,
      categoryLabels: categoryLabels,
      layout: StreetLayout(
        projectSeed: 1337,
        roadWidth: _knobs.roadWidth,
        pxPerMeter: _knobs.pxPerMeter,
        maxBuildingHeight: _knobs.maxHeight,
      ),
    );
    _sceneController = PlazaSceneController(world: _world, hidden: _hidden);
    final walls = _walls;
    if (walls != null) _sceneController.attachWallTextures(walls);
    _lod = FacadeLodManager(
      buildings: _sceneController.buildings,
      config: _config,
      ticks: _ticks,
      onOpen: (b) => setState(() => _panel = b),
    );
    _sprites = PlazaSprites(
      scene: _sceneController.scene,
      world: _world,
      buildings: _sceneController.buildings,
      lampAnchors: _sceneController.lampAnchors,
      spireAnchors: _sceneController.spireAnchors,
      chaseLightPoints: _sceneController.chaseLightPoints,
    );
    // Fire and forget: sprites are square dots until the glow lands.
    unawaited(_sprites.loadGlow());
    _surfaces = PlazaSurfaces(
      scene: _sceneController.scene,
      world: _world,
      markerAnchors: _sceneController.markerAnchors,
      billboards: _sceneController.billboards,
      pxPerMeter: _sceneController.pxPerMeter,
      bannerAnchors: _sceneController.bannerAnchors,
      jumbotronAnchor: _sceneController.jumbotronAnchor,
      weekSignAnchors: _sceneController.weekSignAnchors,
      skylineScreens: _sceneController.skylineScreens,
      fillerSigns: _sceneController.fillerSigns,
    );
    _picker = PlazaPicker(controller: _sceneController, sprites: _sprites);
    final home =
        _world.plaza?.home ??
        const CameraPose(x: 0, y: eyeHeight, z: -10, yaw: 0);
    _camera =
        FlyCameraController(
            pose: home,
            collider: _world.collider,
            solids: _world.solids,
            network: _world.network,
          )
          ..onArrived = _onArrived
          ..onMovement = _endWalk;
    _back.clear();
    _beaconCursor = -1;
    _walk = null;
    _panel = null;
  }

  /// Rebuilds the scene with the current layout knobs.
  void _applyKnobs() {
    _lod.dispose();
    setState(_load);
    _bench?.resume(_camera);
  }

  // ------------------------------------------------------------- flights

  void _flyTo(CameraPose pose, String label, {bool push = true}) {
    if (push) _back.add(_camera.pose);
    _camera.flyTo(pose);
    _showToast(label);
  }

  void _flyToBuilding(PlazaBuilding building) {
    _lod.prepare(building);
    _flyTo(taskPoseFor(building.placement), building.task.title);
  }

  void _flyToTask(PlazaTask task) {
    final building = _sceneController.buildings
        .where((b) => b.task.id == task.id)
        .firstOrNull;
    if (building != null) _flyToBuilding(building);
  }

  void _onArrived() => _walk?.arrived();

  void _goBack() {
    if (_back.isEmpty) return;
    final pose = _back.removeLast();
    _flyTo(pose, 'Back', push: false);
  }

  /// Flies to one of the plaza's own poses, when there is a plaza.
  void _flyToPlaza(CameraPose Function(FrontierPlaza) pose, String where) {
    final plaza = _world.plaza;
    if (plaza != null) _flyTo(pose(plaza), '$where — ${_world.projectLabel}');
  }

  void _flyHome() => _flyToPlaza((p) => p.home, 'Home');

  void _flyOverview() => _flyToPlaza((p) => p.overview, 'Overview');

  void _cycleBeacon(int direction) {
    final nav = _world.beacons
        .where((b) => b.kind != BeaconKind.attention)
        .toList();
    if (nav.isEmpty) return;
    _beaconCursor = (_beaconCursor + direction + nav.length) % nav.length;
    final beacon = nav[_beaconCursor];
    // Block and corner beacons look along the road; when cycling toward
    // older weeks, look that way so the walk reads as walking, not
    // reversing.
    final pose = beacon.kind == BeaconKind.home || direction < 0
        ? beacon.pose
        : CameraPose(
            x: beacon.pose.x,
            y: beacon.pose.y,
            z: beacon.pose.z,
            yaw: beacon.pose.yaw + math.pi,
            pitch: beacon.pose.pitch,
          );
    _flyTo(pose, beacon.label);
  }

  // -------------------------------------------------------- morning walk

  void _startWalk() {
    final stops = _world.walkStops;
    if (stops == null) return;
    final walk = MorningWalk(stops);
    setState(() => _walk = walk);
    _flyTo(walk.current.pose, walk.current.label);
  }

  void _endWalk() {
    if (_walk == null) return;
    _walk!.abandon();
    setState(() => _walk = null);
  }

  void _walkTick(double dt) {
    final walk = _walk;
    if (walk == null) return;
    final next = walk.tick(Duration(microseconds: (dt * 1e6).round()));
    if (next != null) {
      _flyTo(next.pose, next.label);
      setState(() {});
    } else if (walk.finished) {
      setState(() => _walk = null);
    }
  }

  // ------------------------------------------------------------- input

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    // A tour is a screenshot run: stray input must not move the camera.
    if (_mode.scripted) return KeyEventResult.handled;
    if (_searchOpen) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return _camera.handleKeyEvent(event)
          ? KeyEventResult.handled
          : KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.slash) {
      setState(() => _searchOpen = true);
    } else if (key == LogicalKeyboardKey.tab) {
      _cycleBeacon(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
    } else if (key == LogicalKeyboardKey.keyH) {
      _flyHome();
    } else if (key == LogicalKeyboardKey.keyM) {
      _flyOverview();
    } else if (key == LogicalKeyboardKey.backspace) {
      _goBack();
    } else if (key == LogicalKeyboardKey.space) {
      final walk = _walk;
      if (walk != null) setState(walk.togglePause);
    } else if (key == LogicalKeyboardKey.escape) {
      setState(() => _panel = null);
      _endWalk();
    } else if (key == LogicalKeyboardKey.backquote) {
      setState(() => _showDebug = !_showDebug);
    } else if (!_camera.handleKeyEvent(event)) {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_mode.scripted || event.buttons != kPrimaryButton) return;
    _pointerDown = event.localPosition;
    _pointerDownAt = _elapsed;
    _dragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final down = _pointerDown;
    if (down == null || event.buttons == 0) return;
    if (!_dragging && (event.localPosition - down).distance > 6) {
      _dragging = true;
    }
    if (_dragging) _camera.addLookDelta(event.delta.dx, event.delta.dy);
  }

  void _onPointerUp(PointerUpEvent event) {
    final down = _pointerDown;
    _pointerDown = null;
    if (down == null || _dragging) return;
    if (_elapsed - _pointerDownAt > 0.25) return;
    final camera = _frameCamera;
    if (camera == null) return;
    switch (_picker.pick(camera, _viewSize, event.localPosition)) {
      case PickedBeacon(:final beacon):
        _flyTo(beacon.pose, beacon.label);
      case PickedBuilding(:final building):
        if (_lod.focused != building) _flyToBuilding(building);
      case PickedBillboard(:final billboard):
        _flyToTask(billboard.attention.task);
      case null:
        break;
    }
  }

  void _showToast(String label) {
    setState(() {
      _toast = label;
      _toastUntil = _elapsed + 3.2;
    });
  }

  // -------------------------------------------------------------- tour

  /// Dev-only: `PLAZA_TOUR_ONLY=home,block` restricts the tour to those
  /// stops.
  static final Set<String>? _tourOnly = Platform.environment['PLAZA_TOUR_ONLY']
      ?.split(',')
      .toSet();

  void _applyTourStop(int from) {
    var index = from;
    while (index < plazaTourStops.length) {
      final stop = plazaTourStops[index];
      final only = _tourOnly;
      if (only != null && !only.contains(stop.name)) {
        index++;
        continue;
      }
      final pose = stop.pose(_world);
      if (pose != null) {
        _camera.pose = pose;
        _surfaces.pinJumbotron.value = stop.pinJumbotron;
        _tourStop = index;
        _tourClock = 0;
        _tourAnnounced = false;
        debugPrint('PLAZA_TOUR stop $index start: ${stop.name}');
        return;
      }
      debugPrint('PLAZA_TOUR stop $index skipped: ${stop.name}');
      index++;
    }
    _tourDone = true;
    debugPrint('PLAZA_TOUR done');
  }

  void _tourTick(double dt) {
    if (_tourDone || _tourStop < 0) return;
    _tourClock += dt;
    if (!_tourAnnounced && _tourClock >= _tourSettleSeconds) {
      _tourAnnounced = true;
      final focused = _lod.focused;
      final eye = _camera.position;
      debugPrint(
        'PLAZA_TOUR ready $_tourStop ${plazaTourStops[_tourStop].name} '
        'live=${_lod.stats.live} sign=${_lod.stats.sign} '
        'focused=${focused?.task.title} '
        'd=${focused?.groundDistanceTo(eye).toStringAsFixed(1)} '
        'range=${focused?.liveRange.toStringAsFixed(1)} '
        '[${_lod.describeNearest(eye)}]',
      );
    }
    if (_tourClock < _tourHoldSeconds) return;
    _applyTourStop(_tourStop + 1);
  }

  // -------------------------------------------------------------- frame

  void _trace(double dt) {
    final p = _camera.pose;
    final inside = _world.solids.where((s) => s.contains(p.x, p.y, p.z)).length;
    final engine = _engineFramesSinceTrace;
    _engineFramesSinceTrace = 0;
    debugPrint(
      'PLAZA_TRACE t=${_elapsed.toStringAsFixed(3)} '
      'dt=${(dt * 1000).toStringAsFixed(1)} engine=$engine '
      'flying=${_camera.flying} walk=${_walk?.index} '
      'x=${p.x.toStringAsFixed(2)} y=${p.y.toStringAsFixed(2)} '
      'z=${p.z.toStringAsFixed(2)} inside=$inside',
    );
  }

  void _onTick(Duration elapsed, double dt) {
    _elapsed = elapsed.inMicroseconds / 1e6;
    switch (_mode) {
      case HarnessMode.bench:
        _bench!.tick(dt, _lod, _camera);
      case HarnessMode.tour:
        _tourTick(dt);
      case HarnessMode.interactive:
        break;
    }
    _walkTick(dt);
    _camera.update(dt);
    if (_traceMode) _trace(dt);
    final camera = _camera.camera();
    _frameCamera = camera;
    final eye = camera.position;
    final forward = _camera.forward;
    _lod.update(
      eye,
      forward: forward,
      seconds: _elapsed,
      flying: _camera.flying,
    );
    _surfaces.update(eye, _elapsed, forward: forward);
    _sceneController.updateForCamera(eye);
    _sprites.update(camera, _viewSize, _elapsed);

    if (_toast != null && _elapsed > _toastUntil) {
      setState(() => _toast = null);
    }

    if (dt > 0) {
      _frameMs.add(dt * 1000);
      if (_frameMs.length > 120) _frameMs.removeAt(0);
    }
    _statsAge += dt;
    if (_statsAge >= 0.25 && _frameMs.isNotEmpty) {
      final engineFps = _engineFrames / _statsAge;
      _engineFrames = 0;
      _statsAge = 0;
      final sum = _frameMs.fold<double>(0, (a, b) => a + b);
      final avg = sum / _frameMs.length;
      _stats
        ..fps = 1000 / avg
        ..engineFps = engineFps
        ..avgFrameMs = avg
        ..worstFrameMs = _frameMs.reduce((a, b) => a > b ? a : b)
        ..buildings = _sceneController.buildings.length
        ..live = _lod.stats.live
        ..sign = _lod.stats.sign
        ..far = _lod.stats.far
        ..captures = _lod.stats.captures
        ..surfaceCaptures = _surfaces.captures
        ..lastCaptureMs = _lod.stats.lastCapture.inMicroseconds / 1000
        ..promotions = _lod.stats.promotions
        ..publish();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(
        backgroundColor: Color(0xFF04060C),
        body: SizedBox.expand(),
      );
    }
    final panel = _panel;
    return Scaffold(
      backgroundColor: const Color(0xFF04060C),
      body: Focus(
        autofocus: true,
        onKeyEvent: _onKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewSize = constraints.biggest;
                    // Rebuilt by the pacer: a rebuilt SceneView repaints
                    // once, and it does not tick on its own.
                    return ValueListenableBuilder<int>(
                      valueListenable: _frame,
                      builder: (context, _, _) => SceneView(
                        _sceneController.scene,
                        cameraBuilder: (_) => _frameCamera ?? _camera.camera(),
                        autoTick: false,
                      ),
                    );
                  },
                ),
              ),
            ),
            PlazaHud(
              projectLabel: _world.projectLabel,
              taskCount: _world.liveTaskCount,
              weekCount: _world.builtWeeks,
              attentionCount: _world.anomalies.length,
              onMorningWalk: _startWalk,
              onOverview: _flyOverview,
              onHome: _flyHome,
              frameRate: _frameRate,
              onFrameRateChanged: (rate) => setState(() => _frameRate = rate),
              showDebug: _showDebug,
              onShowDebugChanged: (show) => setState(() => _showDebug = show),
              toast: _toast,
              walkChip: _walk?.chip,
            ),
            if (_searchOpen)
              PlazaSearchSheet(
                tasks: _world.tasks,
                attentionOf: _world.attentionOf,
                weekOf: _world.weekOf,
                onPick: (task) {
                  setState(() => _searchOpen = false);
                  _flyToTask(task);
                },
                onClose: () => setState(() => _searchOpen = false),
              ),
            if (panel != null)
              TaskSidePanel(
                attention: panel.attention,
                categoryLabel: _world.categoryLabelOf(panel.task),
                ticks: _ticks,
                onClose: () => setState(() => _panel = null),
              ),
            if (_showDebug)
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 60, 12, 12),
                    child: PlazaDebugOverlay(
                      stats: _stats,
                      config: _config,
                      knobs: _knobs,
                      datasetLabel: 'waddle',
                      onConfigChanged: () => setState(() {}),
                      onKnobsApplied: _applyKnobs,
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
