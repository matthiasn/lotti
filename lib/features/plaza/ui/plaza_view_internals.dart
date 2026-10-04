part of 'plaza_view.dart';

/// Private helpers of [_PlazaViewState] that hold no state of their own; kept beside the class as an extension so the library stays readable.
extension _PlazaViewStateInternals on _PlazaViewState {
  void _onPace(Duration elapsed) {
    final last = _lastPaint;
    final seconds = elapsed.inMicroseconds / 1e6;
    if (_moving) _movingUntil = seconds + _PlazaViewState._movingHold;
    final dt = last == null ? 1 / 60 : (elapsed - last).inMicroseconds / 1e6;
    _lastPaint = elapsed;
    _onTick(elapsed, dt);
    _frame.value++;
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

  void _goBack() {
    if (_back.isEmpty) {
      widget.onExit?.call();
      return;
    }
    final pose = _back.removeLast();
    _flyTo(pose, context.messages.designSystemBackLabel, push: false);
  }

  void _flyHome() {
    _connectionFocusTaskId = null;
    _flyToPlaza(
      (p) => p.home,
      context.messages.designSystemBreadcrumbHomeLabel,
    );
  }

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
        _tourClock >= _PlazaViewState._tourSettleSeconds) {
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
    if (!_tourAnnounced || _tourClock < _PlazaViewState._tourHoldSeconds) {
      return;
    }
    _applyTourStop(_tourStop + 1);
  }

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
}
