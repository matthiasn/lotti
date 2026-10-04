import 'dart:async' show unawaited;
import 'dart:io' show File;
import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming, ImageByteFormat;

import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
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
import 'package:lotti/features/plaza/ui/plaza_palette.dart';
import 'package:lotti/features/plaza/ui/plaza_pointer_controller.dart';
import 'package:lotti/features/plaza/ui/plaza_repaint.dart';
import 'package:lotti/features/plaza/ui/plaza_search_sheet.dart';
import 'package:lotti/features/plaza/ui/plaza_top_bar.dart';
import 'package:lotti/features/plaza/ui/plaza_tour.dart';
import 'package:lotti/features/plaza/ui/plaza_wall_swap.dart';
import 'package:lotti/features/plaza/ui/task_side_panel.dart';
import 'package:lotti/l10n/app_localizations_context.dart';
import 'package:lotti/widgets/ui/error_state_widget.dart';
import 'package:material_ui/material_ui.dart';

part 'plaza_view_plaza_view_part.dart';
part 'plaza_view_internals.dart';

class _PlazaViewState extends State<PlazaView> with WidgetsBindingObserver {
  HarnessMode get _mode => widget.mode;
  Set<String> get _hidden => widget.hidden;
  bool get _traceMode => widget.trace;
  late PlazaFrameRate _frameRate = widget.initialFrameRate;
  late PlazaSkyMode _skyMode = widget.initialSkyMode;
  PlazaPalette get _palette => PlazaPalette.of(_skyMode);

  /// Which painted texture set is on its way, so a walker who flips back and
  /// forth lands on their last choice rather than on whichever paint
  /// finished last.
  final PlazaWallSwap _wallSwap = PlazaWallSwap();
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
  bool _toolbarOpen = false;

  /// The world's own keyboard. Named rather than implicit because the toolbar
  /// hands focus to the chrome and has to be able to hand it back: a control
  /// that has left the screen must not keep the keyboard, or walking stops
  /// working until something else takes it.
  final _worldFocus = FocusNode(debugLabel: 'plaza world');
  final List<CameraPose> _back = [];
  int _beaconCursor = -1;

  // Tap-versus-drag.
  final _pointer = PlazaPointerController();

  /// The subtree a fixture capture reads back: the world and its chrome.
  final GlobalKey _shotKey = GlobalKey();

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
    _toolbarOpen = widget.initialToolbarOpen;
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
    _walls = await WallTextures.load(copy: widget.world.copy, mode: _skyMode);
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

  /// Reads the settled frame back out of the widget tree and writes it to
  /// [PlazaView.shotDir] as `<stop>.png`.
  Future<void> _writeShot(String name) async {
    final boundary =
        _shotKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    try {
      final bytes = await image.toByteData(format: ImageByteFormat.png);
      if (bytes == null) return;
      final file = File('${widget.shotDir}/$name.png')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(bytes.buffer.asUint8List());
      debugPrint('PLAZA_SHOT wrote ${file.path}');
    } finally {
      image.dispose();
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
    _worldFocus.dispose();
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
    _sceneController = PlazaSceneController(
      world: _world,
      palette: _palette,
      hidden: _hidden,
    );
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
      palette: _palette,
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
            palette: _palette,
          );
    _cables?.root.visible = _showConnections;
    _attachCharacters();
    debugPrint(
      'PLAZA_BATCHES meshes=${batches.meshes} batches=${batches.batches} '
      'shadows=${_sceneController.shadowCount}',
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
          _reloadWalls(widget.world.copy, _skyMode).catchError(
            _reportTextureError,
          ),
        );
      }
    }
  }

  /// Paints and uploads a texture set for [mode] and hands it to the scene.
  ///
  /// The set on screen stays until this one lands, so neither a locale
  /// change nor a sky switch ever shows an untextured city. A result that
  /// is no longer wanted — the locale moved on, or the walker switched
  /// back — is dropped rather than attached.
  Future<void> _reloadWalls(PlazaCopy copy, PlazaSkyMode mode) async {
    try {
      final walls = await WallTextures.load(copy: copy, mode: mode);
      if (!mounted ||
          copy.messages.localeName != widget.world.copy.messages.localeName ||
          mode != _skyMode) {
        return;
      }
      _walls = walls;
      _sceneController.attachWallTextures(walls);
      _wakeForInput();
    } finally {
      // Whatever happened to it — attached, dropped, or thrown — this set is
      // no longer on its way, and its sky must stay askable.
      _wallSwap.settled(mode);
    }
  }

  /// Switches the sky.
  ///
  /// The scene is rebuilt under the new palette at once — geometry, air and
  /// every solid colour — keeping the camera where it stands, and the
  /// painted walls follow when their set finishes uploading. Rebuilding is
  /// what a mode change *is*: the materials are shared and immutable, so
  /// there is nothing to repaint in place.
  void _setSkyMode(PlazaSkyMode mode) {
    if (mode == _skyMode) return;
    final pose = _camera.pose;
    _lod.dispose();
    setState(() {
      _skyMode = mode;
      _load(pose: pose);
    });
    widget.onSkyModeChanged?.call(mode);
    final pending = _wallSwap.request(wanted: mode, attached: _walls?.mode);
    if (pending != null) {
      unawaited(
        _reloadWalls(
          widget.world.copy,
          pending,
        ).catchError(_reportTextureError),
      );
    }
    _frameCamera = null;
    _wakeForInput();
  }

  /// Rebuilds the scene with the current layout knobs.
  void _applyKnobs() {
    _lod.dispose();
    setState(_load);
    _bench?.resume(_camera);
  }

  // ------------------------------------------------------------- flights

  void _onArrived() => _walk?.arrived();

  /// Flies to one of the plaza's own poses, when there is a plaza.
  void _flyToPlaza(CameraPose Function(FrontierPlaza) pose, String where) {
    final plaza = _world.plaza;
    if (plaza != null) _flyTo(pose(plaza), '$where — ${_world.projectLabel}');
  }

  void _flyOverview() =>
      _flyToPlaza((p) => p.overview, context.messages.plazaOverview);

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
    // Who the press belongs to. Once the toolbar is open the chrome can hold
    // the keyboard, and everything it holds — Tab, Enter, Space — has to
    // reach it rather than the world; [PlazaKeyRouting] states that rule
    // where a test can get at it.
    switch (PlazaKeyRouting.of(
      event,
      worldHasFocus: node.hasPrimaryFocus,
      toolbarOpen: _toolbarOpen,
    )) {
      case PlazaKeyRouting.chrome:
        return KeyEventResult.ignored;
      case PlazaKeyRouting.toolbar:
      case PlazaKeyRouting.world:
        break;
    }
    // The toolbar binding is read off [PlazaToolbarKey] rather than spelled
    // out here, so the one place it can be tested is the one place it is
    // stated. Esc keeps falling through: it dismisses the panel and the walk
    // in the same press.
    final toolbarKey = PlazaToolbarKey.pressed(event);
    if (toolbarKey != null) {
      _setToolbarOpen(toolbarKey.applyTo(open: _toolbarOpen));
      if (toolbarKey == PlazaToolbarKey.toggle) return KeyEventResult.handled;
    }
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

  /// Shows or hides the toolbar, and keeps the keyboard where it can be used.
  ///
  /// Shutting the toolbar can strand focus on a control that is no longer in
  /// the tree, which leaves the world deaf to `WASD` until something else
  /// takes focus. The world takes it back instead.
  void _setToolbarOpen(bool open) {
    setState(() => _toolbarOpen = open);
    if (!open) _worldFocus.requestFocus();
    _wakeForInput();
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

  // -------------------------------------------------------------- frame

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
    // The capture boundary is a full-window compositing layer that exists
    // only so a fixture can read the frame back; shipping runs never pay
    // for it. [_writeShot] already tolerates its absence.
    Widget capturable(Widget world) => widget.shotDir == null
        ? world
        : RepaintBoundary(key: _shotKey, child: world);
    return Scaffold(
      backgroundColor: context.designTokens.colors.background.level01,
      body: Focus(
        focusNode: _worldFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: capturable(
          Stack(
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
                toolbarOpen: _toolbarOpen,
                onToolbarToggle: () => _setToolbarOpen(!_toolbarOpen),
                skyMode: _skyMode,
                onSkyModeChanged: _setSkyMode,
                palette: _palette,
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
      ),
    );
  }

  // An instance method, not an extension member: it is registered and removed as a timings callback, and two tear-offs of an extension method are never equal, so removal would miss.
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
      _tourClock = _PlazaViewState._tourSettleSeconds;
      final stop = _tourStop;
      if (widget.shotDir != null && stop >= 0) {
        unawaited(
          _writeShot(plazaTourStops[stop].name).catchError((Object error) {
            debugPrint('PLAZA_SHOT failed: $error');
          }),
        );
      }
    }
  }
}
