import 'dart:async' show unawaited;
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';
import 'package:flutter_gpu/gpu.dart' as gpu;
import 'package:flutter_scene/scene.dart' hide FlyCameraController;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/character_population.dart';
import 'package:lotti/features/plaza/domain/character_traffic.dart';
import 'package:lotti/features/plaza/domain/meerkat_motion.dart';
import 'package:lotti/features/plaza/domain/meerkat_population.dart';
import 'package:lotti/features/plaza/domain/morning_walk.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:lotti/features/plaza/scene/plaza_bench.dart';
import 'package:lotti/features/plaza/scene/plaza_cables.dart';
import 'package:lotti/features/plaza/scene/plaza_characters.dart';
import 'package:lotti/features/plaza/scene/plaza_fire.dart';
import 'package:lotti/features/plaza/scene/plaza_meerkats.dart';
import 'package:lotti/features/plaza/scene/plaza_picker.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/scene/plaza_scene_records.dart';
import 'package:lotti/features/plaza/scene/plaza_sprites.dart';
import 'package:lotti/features/plaza/scene/plaza_surfaces.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/scene/wall_textures.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/debug_overlay.dart';
import 'package:lotti/features/plaza/ui/fly_camera_controller.dart';
import 'package:lotti/features/plaza/ui/plaza_copy.dart';
import 'package:lotti/features/plaza/ui/plaza_frame_pacer.dart';
import 'package:lotti/features/plaza/ui/plaza_frame_window.dart';
import 'package:lotti/features/plaza/ui/plaza_hud.dart';
import 'package:lotti/features/plaza/ui/plaza_pointer_controller.dart';
import 'package:lotti/features/plaza/ui/plaza_repaint.dart';
import 'package:lotti/features/plaza/ui/plaza_search_sheet.dart';
import 'package:lotti/features/plaza/ui/plaza_tour.dart';
import 'package:lotti/features/plaza/ui/task_side_panel.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:material_ui/material_ui.dart';

/// Reusable GPU explorer. All content comes from [world]; the demo launcher
/// and the app are independent clients of this same rendering pipeline.
class PlazaView extends StatefulWidget {
  const PlazaView({
    required this.world,
    this.ticks,
    this.onOpenTask,
    this.onExit,
    this.mode = HarnessMode.interactive,
    this.hidden = const {},
    this.trace = false,
    this.tourOnly,
    this.initialFrameRate = PlazaFrameRate.auto,
    super.key,
  });

  final PlazaWorld world;
  final ChecklistTicks? ticks;
  final ValueChanged<PlazaTask>? onOpenTask;
  final VoidCallback? onExit;
  final HarnessMode mode;
  final Set<String> hidden;
  final bool trace;
  final Set<String>? tourOnly;
  final PlazaFrameRate initialFrameRate;

  @override
  State<PlazaView> createState() => _PlazaViewState();
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

class _PlazaViewState extends State<PlazaView> with WidgetsBindingObserver {
  HarnessMode get _mode => widget.mode;
  Set<String> get _hidden => widget.hidden;
  bool get _traceMode => widget.trace;
  late PlazaFrameRate _frameRate = widget.initialFrameRate;
  PlazaFramePacer? _pacer;

  Duration? _lastPaint;
  final ValueNotifier<int> _frame = ValueNotifier(0);

  /// Movement and input keep the display's rate on `auto` for this long,
  /// so a coast to a halt and direct widget interaction stay smooth.
  static const _movingHold = 0.6;
  double _movingUntil = _movingHold;

  /// Frames the engine produced since the stats were last published,
  /// counted from engine frame timings: the number that shows whether
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
  PlazaFire? _fire;
  PlazaCables? _cables;
  PlazaCharacters? _characters;
  Node? _penguinModel;
  Node? _meerkatModel;
  PlazaMeerkats? _meerkats;
  CharacterTraffic? _traffic;
  bool _loadingCharacterModels = false;
  bool _animateCharacters = true;
  bool _showPenguins = false;
  bool _showConnections = true;
  bool _showMeerkats = false;
  late PlazaSurfaces _surfaces;
  late PlazaPicker _picker;
  late FlyCameraController _camera;
  late final ChecklistTicks _ticks = widget.ticks ?? ChecklistTicks();
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
  String? _connectionFocusTaskId;
  bool _searchOpen = false;
  bool _showDebug = false;
  final List<CameraPose> _back = [];
  int _beaconCursor = -1;

  // Tap-versus-drag.
  final _pointer = PlazaPointerController();

  // Rolling frame-time window.
  final _frameMs = PlazaFrameWindow();
  double _statsAge = 0;

  // Tour mode.
  static const _tourSettleSeconds = 5.0;
  static const _tourHoldSeconds = 9.0;
  int _tourStop = -1;
  double _tourClock = 0;
  bool _tourAnnounced = false;
  int? _tourReadyFrameMicros;
  String? _tourReadyReport;
  bool _tourDone = false;

  /// Sprites and the gradient sky touch the base shader library, which must
  /// be loaded before any of them is constructed.
  bool _ready = false;
  bool _lodCreated = false;
  bool _timingsRegistered = false;
  Object? _bootError;
  bool _renderingEnabled = true;
  WallTextures? _walls;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _knobs
      ..roadWidth = widget.world.layout.roadWidth
      ..pxPerMeter = widget.world.layout.pxPerMeter
      ..maxHeight = widget.world.layout.maxBuildingHeight;
    unawaited(
      _boot().catchError((Object error) {
        if (mounted) setState(() => _bootError = error);
      }),
    );
  }

  Future<void> _boot() async {
    // Fail before Scene starts parallel shader/texture initialization on a
    // backend without GPU support; those child futures otherwise escape it.
    await Future.sync(() => gpu.gpuContext);
    await Scene.initializeStaticResources();
    _walls = await WallTextures.load(copy: widget.world.copy);
    await _ensureCharacterModels();
    if (!mounted) return;
    _load();
    switch (_mode) {
      case HarnessMode.bench:
        _bench!.start(_config, _camera);
      case HarnessMode.tour:
        _applyTourStop(0);
      case HarnessMode.interactive:
        _showToast(
          '${context.messages.designSystemBreadcrumbHomeLabel} — ${_world.projectLabel}',
        );
    }
    setState(() => _ready = true);
    _pacer = PlazaFramePacer(
      onFrame: _onPace,
      cap: () => _mode.scripted
          ? null
          : _frameRate.capFor(
              moving: _moving || _elapsed < _movingUntil,
              activeSurface: _lod.stats.live > 0,
              activeAnimation:
                  (_characters?.hasVisibleMotion ?? false) ||
                  (_meerkats?.hasVisibleMotion ?? false) ||
                  (_cables?.hasVisibleMotion ?? false),
            ),
    );
    if (_renderingEnabled &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed)) {
      _pacer!.start();
    }
    SchedulerBinding.instance.addTimingsCallback(_recordEngineFrames);
    _timingsRegistered = true;
  }

  void _recordEngineFrames(List<FrameTiming> timings) {
    _engineFrames += timings.length;
    _engineFramesSinceTrace += timings.length;
    final readyFrame = _tourReadyFrameMicros;
    if (readyFrame != null &&
        timings.any(
          (frame) =>
              frame.timestampInMicroseconds(FramePhase.vsyncStart) >=
              readyFrame,
        )) {
      // Raster timings acknowledge the frame that includes the captured
      // surfaces. Announcing during _onTick races the X11 screenshot reader.
      debugPrint(_tourReadyReport);
      _tourReadyFrameMicros = null;
      _tourReadyReport = null;
      _tourAnnounced = true;
      _tourClock = _tourSettleSeconds;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_timingsRegistered) {
      SchedulerBinding.instance.removeTimingsCallback(_recordEngineFrames);
    }
    _pacer?.dispose();
    if (_lodCreated) _lod.dispose();
    _characters?.dispose();
    _meerkats?.dispose();
    if (widget.ticks == null) _ticks.dispose();
    _stats.dispose();
    _frame.dispose();
    super.dispose();
  }

  /// Whether anything moves the camera: a flight, the walk, a held key or
  /// a drag; the tour and the benchmark always count as moving.
  bool get _moving =>
      _mode.scripted ||
      _camera.flying ||
      _camera.moving ||
      _pointer.dragging ||
      _walk != null;

  void _onPace(Duration elapsed) {
    final last = _lastPaint;
    final seconds = elapsed.inMicroseconds / 1e6;
    if (_moving) _movingUntil = seconds + _movingHold;
    final dt = last == null ? 1 / 60 : (elapsed - last).inMicroseconds / 1e6;
    _lastPaint = elapsed;
    _onTick(elapsed, dt);
    _frame.value++;
  }

  /// Cancels the idle wait and lets interaction settle at display cadence.
  void _wakeForInput() {
    _movingUntil = _elapsed + _movingHold;
    _pacer?.requestFrame();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _renderingEnabled) {
      _pacer?.start();
    } else {
      _pacer?.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animateCharacters = !MediaQuery.disableAnimationsOf(context);
    _renderingEnabled = TickerMode.valuesOf(context).enabled;
    if (_renderingEnabled &&
        (WidgetsBinding.instance.lifecycleState == null ||
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed)) {
      _pacer?.start();
    } else {
      _pacer?.stop();
    }
  }

  // ---------------------------------------------------------------- data

  void _load({CameraPose? pose}) {
    final input = widget.world;
    _world = PlazaWorld(
      tasks: input.tasks,
      connections: input.connections,
      now: input.now,
      projectLabel: input.projectLabel,
      categoryLabels: input.categoryLabels,
      epoch: input.epoch,
      copy: input.copy,
      ambientCreatures: input.ambientCreatures,
      architecture: input.architecture,
      cables: input.cables,
      avenueLabels: input.avenueLabels,
      avenueByProjectId: input.avenueByProjectId,
      layout: input.layout.copyWith(
        roadWidth: _knobs.roadWidth,
        pxPerMeter: _knobs.pxPerMeter,
        maxBuildingHeight: _knobs.maxHeight,
      ),
    );
    _sceneController = PlazaSceneController(world: _world, hidden: _hidden);
    final walls = _walls;
    if (walls != null) _sceneController.attachWallTextures(walls);
    _lod = FacadeLodManager(
      buildings: _sceneController.bindings.buildings,
      config: _config,
      ticks: _ticks,
      onOpen: (building) {
        final onOpen = widget.onOpenTask;
        if (onOpen != null) {
          onOpen(building.task);
        } else {
          setState(() => _panel = building);
        }
      },
    );
    _lodCreated = true;
    _sprites = PlazaSprites(
      scene: _sceneController.scene,
      world: _world,
      bindings: _sceneController.bindings,
    );
    // Fire and forget: sprites are square dots until the glow lands.
    unawaited(_sprites.loadGlow().catchError(_reportTextureError));
    _fire = _hidden.contains('fire')
        ? null
        : PlazaFire(scene: _sceneController.scene, world: _world);
    unawaited(_fire?.loadTexture().catchError(_reportTextureError));
    _surfaces = PlazaSurfaces(
      bindings: _sceneController.bindings,
      scene: _sceneController.scene,
      world: _world,
      pxPerMeter: _sceneController.pxPerMeter,
    );
    final batches = _sceneController.bakeStaticMeshes();
    _cables = walls == null || _hidden.contains('cables')
        ? null
        : PlazaCables(
            scene: _sceneController.scene,
            world: _world,
            glowTexture: walls.pool,
          );
    _cables?.root.visible = _showConnections;
    _attachCharacters();
    debugPrint(
      'PLAZA_BATCHES meshes=${batches.meshes} batches=${batches.batches}',
    );
    debugPrint(
      'PLAZA_CABLES edges=${_world.connections.length} '
      'meshes=${_cables?.meshCount ?? 0} '
      'batches=${_cables?.batchCount ?? 0}',
    );
    _picker = PlazaPicker(controller: _sceneController, sprites: _sprites);
    final home =
        _world.plaza?.home ??
        const CameraPose(x: 0, y: eyeHeight, z: -10, yaw: 0);
    _camera =
        FlyCameraController(
            pose: pose ?? home,
            collider: _world.collider,
            solids: _world.solids,
            network: _world.network,
          )
          ..onArrived = _onArrived
          ..onMovement = _endWalk;
    if (pose == null) _back.clear();
    _beaconCursor = -1;
    _walk = null;
    _panel = null;
    if (!_world.attention.containsKey(_connectionFocusTaskId)) {
      _connectionFocusTaskId = null;
    }
  }

  void _attachCharacters() {
    // Animated skeletons must remain outside stationary mesh batches.
    _characters?.dispose();
    _meerkats?.dispose();
    final budget = _hidden.contains('characters') || _hidden.contains('life')
        ? 0
        : _world.ambientCreatures;
    final meerkatBudget = _meerkatModel == null ? 0 : budget ~/ 4;
    final penguins = _penguinModel == null
        ? const <CharacterCompanion>[]
        : CharacterPopulation.forWorld(
            plan: _world.plan,
            plaza: _world.plaza,
            solids: _world.solids,
            roadWidth: _world.layout.roadWidth,
            maxCount: budget - meerkatBudget,
          );
    final meerkats = meerkatBudget == 0
        ? const <MeerkatMotion>[]
        : MeerkatPopulation.forWorld(
            plan: _world.plan,
            plaza: _world.plaza,
            solids: _world.solids,
            roadWidth: _world.layout.roadWidth,
            penguins: penguins,
            maxCount: meerkatBudget,
          );
    _traffic = CharacterTraffic([
      for (final penguin in penguins) TrafficCharacter.penguin(penguin),
      for (final meerkat in meerkats) TrafficCharacter.meerkat(meerkat),
    ]);
    _characters = PlazaCharacters(
      parent: _sceneController.scene.root,
      model: _penguinModel,
      shadowTexture: _walls?.pool,
      population: penguins,
    )..enabled = _showPenguins;
    _meerkats = PlazaMeerkats(
      parent: _sceneController.scene.root,
      model: _meerkatModel,
      shadowTexture: _walls?.pool,
      population: meerkats,
    );
  }

  /// Load each species independently when the scope permits ambient life.
  /// A live configuration change can enable companions after a zero budget.
  Future<void> _ensureCharacterModels() async {
    if ((_penguinModel != null && _meerkatModel != null) ||
        _loadingCharacterModels ||
        widget.world.ambientCreatures == 0 ||
        _hidden.contains('characters') ||
        _hidden.contains('life')) {
      return;
    }
    _loadingCharacterModels = true;
    try {
      // A failed optional species must not block the other or project data.
      await Future.wait([
        if (_penguinModel == null)
          PlazaCharacters.loadModel()
              .then((model) {
                if (mounted) _penguinModel = model;
              })
              .catchError(_reportTextureError),
        if (_meerkatModel == null)
          PlazaMeerkats.loadModel()
              .then((model) {
                if (mounted) _meerkatModel = model;
              })
              .catchError(_reportTextureError),
      ]);
      if (!mounted) return;
      if (_ready) {
        _attachCharacters();
        setState(() {});
        _wakeForInput();
      }
    } finally {
      _loadingCharacterModels = false;
    }
  }

  @override
  void didUpdateWidget(PlazaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_ready && !identical(oldWidget.world, widget.world)) {
      final pose = _camera.pose;
      _lod.dispose();
      _load(pose: pose);
      unawaited(_ensureCharacterModels());
      _frameCamera = null;
      _wakeForInput();
      if (oldWidget.world.copy.messages.localeName !=
          widget.world.copy.messages.localeName) {
        unawaited(
          _reloadWalls(widget.world.copy).catchError(_reportTextureError),
        );
      }
    }
  }

  void _reportTextureError(Object error, StackTrace stack) {
    if (!mounted) return;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'plaza',
        context: ErrorDescription('loading plaza textures'),
      ),
    );
  }

  Future<void> _reloadWalls(PlazaCopy copy) async {
    final walls = await WallTextures.load(copy: copy);
    if (!mounted ||
        copy.messages.localeName != widget.world.copy.messages.localeName) {
      return;
    }
    _walls = walls;
    _sceneController.attachWallTextures(walls);
    _wakeForInput();
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
    _wakeForInput();
    _showToast(label);
  }

  void _flyToBuilding(PlazaBuilding building) {
    _connectionFocusTaskId = building.task.id;
    _lod.prepare(building);
    _flyTo(taskPoseFor(building.placement), building.task.title);
  }

  void _flyToTask(PlazaTask task) {
    final building = _sceneController.bindings.buildings
        .where((b) => b.task.id == task.id)
        .firstOrNull;
    if (building != null) _flyToBuilding(building);
  }

  void _onArrived() => _walk?.arrived();

  void _goBack() {
    if (_back.isEmpty) {
      widget.onExit?.call();
      return;
    }
    final pose = _back.removeLast();
    _flyTo(pose, context.messages.designSystemBackLabel, push: false);
  }

  /// Flies to one of the plaza's own poses, when there is a plaza.
  void _flyToPlaza(CameraPose Function(FrontierPlaza) pose, String where) {
    final plaza = _world.plaza;
    if (plaza != null) _flyTo(pose(plaza), '$where — ${_world.projectLabel}');
  }

  void _flyHome() {
    _connectionFocusTaskId = null;
    _flyToPlaza(
      (p) => p.home,
      context.messages.designSystemBreadcrumbHomeLabel,
    );
  }

  void _flyOverview() =>
      _flyToPlaza((p) => p.overview, context.messages.plazaOverview);

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
    _wakeForInput();
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.slash) {
      setState(() => _searchOpen = true);
    } else if (key == LogicalKeyboardKey.tab) {
      _cycleBeacon(HardwareKeyboard.instance.isShiftPressed ? -1 : 1);
    } else if (key == LogicalKeyboardKey.keyH) {
      _flyHome();
    } else if (key == LogicalKeyboardKey.keyM) {
      _flyOverview();
    } else if (key == LogicalKeyboardKey.backspace ||
        (HardwareKeyboard.instance.isMetaPressed &&
            key == LogicalKeyboardKey.bracketLeft)) {
      _goBack();
    } else if (key == LogicalKeyboardKey.space) {
      final walk = _walk;
      if (walk != null) setState(walk.togglePause);
    } else if (key == LogicalKeyboardKey.escape) {
      _connectionFocusTaskId = null;
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
    if (_mode.scripted) return;
    _pointer.down(event, _elapsed);
    _wakeForInput();
  }

  void _onPointerMove(PointerMoveEvent event) {
    final delta = _pointer.move(event);
    if (delta != null) {
      _camera.addLookDelta(delta.dx, delta.dy);
      _wakeForInput();
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    final point = _pointer.up(event, _elapsed);
    if (point == null) return;
    final camera = _frameCamera;
    if (camera == null) return;
    switch (_picker.pick(camera, _viewSize, point)) {
      case PickedBeacon(:final beacon):
        _connectionFocusTaskId = beacon.taskId;
        _flyTo(beacon.pose, beacon.label);
      case PickedBuilding(:final building):
        _connectionFocusTaskId = building.task.id;
        if (!_lod.activate(
          building,
          _camera.position,
          forward: _camera.forward,
        )) {
          _flyToBuilding(building);
        }
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
  Set<String>? get _tourOnly => widget.tourOnly;

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
    if (!_tourAnnounced && _surfaces.hasPendingCaptures) {
      _tourClock = 0;
      return;
    }
    _tourClock += dt;
    if (!_tourAnnounced &&
        _tourReadyFrameMicros == null &&
        !_surfaces.hasPendingCaptures &&
        _tourClock >= _tourSettleSeconds) {
      _tourReadyFrameMicros =
          SchedulerBinding.instance.currentSystemFrameTimeStamp.inMicroseconds;
      final focused = _lod.focused;
      final eye = _camera.position;
      _tourReadyReport =
          'PLAZA_TOUR ready $_tourStop ${plazaTourStops[_tourStop].name} '
          'live=${_lod.stats.live} sign=${_lod.stats.sign} '
          'focused=${focused?.task.title} '
          'd=${focused?.groundDistanceTo(eye).toStringAsFixed(1)} '
          'range=${focused?.liveRange.toStringAsFixed(1)} '
          '[${_lod.describeNearest(eye)}]';
    }
    if (!_tourAnnounced || _tourClock < _tourHoldSeconds) return;
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
      'z=${p.z.toStringAsFixed(2)} inside=$inside '
      'captures=${_lod.stats.captures + _surfaces.captures}',
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
    final camera = _camera.camera(
      farClip: math.max(1400, (_world.plaza?.overview.y ?? 0) * 4),
    );
    _frameCamera = camera;
    final eye = camera.position;
    final forward = _camera.forward;
    _lod.update(
      eye,
      forward: forward,
      seconds: _elapsed,
      flying: _camera.flying,
    );
    _surfaces.update(
      eye,
      _elapsed,
      forward: forward,
      glowFade: _sceneController.poolFade,
    );
    _sceneController.updateForCamera(eye);
    _sprites.update(camera, _viewSize, _elapsed);
    _fire?.update(_elapsed, eye);
    _cables?.update(
      _elapsed,
      eye,
      focusedTask: _connectionFocusTaskId ?? _lod.focused?.task.id,
      animate: _animateCharacters,
    );
    final traffic = _traffic;
    traffic?.update(
      seconds: _elapsed,
      animate: _animateCharacters,
      showPenguins: _showPenguins,
      showMeerkats: _showMeerkats,
    );
    _characters?.update(
      seconds: _elapsed,
      eye: eye,
      animate: _animateCharacters,
      clockFor: traffic?.clockFor,
      visibleFor: traffic?.visibleFor,
    );
    _meerkats?.update(
      seconds: _elapsed,
      eye: eye,
      animate: _animateCharacters,
      visible: _showMeerkats,
      clockFor: traffic?.clockFor,
      visibleFor: traffic?.visibleFor,
    );

    if (_toast != null && _elapsed > _toastUntil) {
      setState(() => _toast = null);
    }

    if (dt > 0) {
      _frameMs.add(dt * 1000);
    }
    _statsAge += dt;
    if (_statsAge >= 0.25 && _frameMs.count > 0) {
      final engineFps = _engineFrames / _statsAge;
      _engineFrames = 0;
      _statsAge = 0;
      final avg = _frameMs.average;
      _stats
        ..fps = 1000 / avg
        ..engineFps = engineFps
        ..avgFrameMs = avg
        ..worstFrameMs = _frameMs.worst
        ..buildings = _sceneController.bindings.buildings.length
        ..surfaceCaptures = _surfaces.captures
        ..lod = _lod.stats
        ..publish();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return Scaffold(
        backgroundColor: context.designTokens.colors.background.level01,
        appBar: AppBar(),
        body: _bootError == null
            ? const Center(child: CircularProgressIndicator.adaptive())
            : ErrorStateWidget(
                error: context.messages.plazaUnavailable,
                mode: ErrorDisplayMode.inline,
              ),
      );
    }
    final panel = _panel;
    return Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
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
                onPointerCancel: (event) => _pointer.cancel(event.pointer),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewSize = constraints.biggest;
                    // The frame clock invalidates paint, leaving hosted
                    // widget elements out of the per-frame build path.
                    return PlazaRepaint(
                      frames: _frame,
                      child: SceneView(
                        _sceneController.scene,
                        cameraBuilder: (_) =>
                            _frameCamera ??
                            _camera.camera(
                              farClip: math.max(
                                1400,
                                (_world.plaza?.overview.y ?? 0) * 4,
                              ),
                            ),
                        autoTick: false,
                      ),
                    );
                  },
                ),
              ),
            ),
            PlazaHud(
              projectLabel: _world.projectLabel,
              isCategory: _world.isCategory,
              taskCount: _world.liveTaskCount,
              weekCount: _world.builtWeeks,
              attentionCount: _world.anomalies.length,
              onMorningWalk: _startWalk,
              onOverview: _flyOverview,
              onHome: _flyHome,
              onExit: widget.onExit,
              frameRate: _frameRate,
              onFrameRateChanged: (rate) {
                setState(() => _frameRate = rate);
                _wakeForInput();
              },
              showPenguins:
                  _showPenguins &&
                  _penguinModel != null &&
                  _world.ambientCreatures > 0,
              onShowPenguinsChanged:
                  _penguinModel == null || _world.ambientCreatures == 0
                  ? null
                  : (show) {
                      setState(() => _showPenguins = show);
                      _characters?.enabled = show;
                      _wakeForInput();
                    },
              showConnections: _showConnections,
              onShowConnectionsChanged: _world.connections.isEmpty
                  ? null
                  : (show) {
                      setState(() => _showConnections = show);
                      _cables?.root.visible = show;
                      _wakeForInput();
                    },
              showMeerkats:
                  _showMeerkats &&
                  _meerkatModel != null &&
                  _world.ambientCreatures >= 4,
              onShowMeerkatsChanged:
                  _meerkatModel == null || _world.ambientCreatures < 4
                  ? null
                  : (show) {
                      setState(() => _showMeerkats = show);
                      _wakeForInput();
                    },
              showDebug: _showDebug,
              onShowDebugChanged: (show) => setState(() => _showDebug = show),
              toast: _toast,
              walkChip: _walk == null
                  ? null
                  : '${context.messages.plazaMorningWalk} · ${_walk!.index + 1}/${_walk!.stops.length} · ${_walk!.paused ? context.messages.plazaPaused : context.messages.plazaTourControls}',
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
                    padding: EdgeInsets.fromLTRB(
                      context.designTokens.spacing.step3,
                      context.designTokens.spacing.step10,
                      context.designTokens.spacing.step3,
                      context.designTokens.spacing.step3,
                    ),
                    child: PlazaDebugOverlay(
                      stats: _stats,
                      config: _config,
                      knobs: _knobs,
                      datasetLabel: _world.projectLabel,
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
