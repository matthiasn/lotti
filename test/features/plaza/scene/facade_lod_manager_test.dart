import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:lotti/features/plaza/scene/plaza_scene_records.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:lotti/features/plaza/ui/facade_widget.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

import 'test_utils.dart';

final _now = DateTime.utc(2026, 7, 15);

/// A building whose facade stands at ([x], [z]) facing [facing]; no
/// geometry, so nothing here needs a GPU as long as no tier is promoted.
PlazaBuilding _building(String id, double x, double z, {double facing = 0}) {
  final task = PlazaTask(
    id: id,
    createdAt: DateTime.utc(2026, 7),
    title: 'Building $id on the street',
    state: PlazaTaskState.open,
    progress: 0,
    checklistItems: 0,
    linkedTaskIds: const [],
    categoryColor: 0xFF4AB6E8,
  );
  return PlazaBuilding(
    task: task,
    attention: attentionFor(task, _now),
    placement: PlotPlacement(
      taskId: id,
      bucketIndex: 0,
      side: PlotSide.left,
      x: x,
      z: z,
      facingRadians: facing,
      width: 8,
      depth: 10,
      height: 12,
    ),
    node: Node(),
    facadeAnchor: Node(),
    ring: Node(),
    neon: Node(),
    lanternAnchor: Node(),
    facadeCenter: Vector3(x, 6, z),
    facadeNormal: Vector3(math.sin(facing), 0, math.cos(facing)),
    facadeWorldWidth: 8,
    facadeWorldHeight: 12,
    liveRange: 14,
    pxPerMeter: 90,
  );
}

FacadeLodManager _manager(
  List<PlazaBuilding> buildings, {
  FacadeLodConfig? config,
}) => FacadeLodManager(
  buildings: buildings,
  config: config ?? FacadeLodConfig(),
  ticks: ChecklistTicks(),
  onOpen: (_) {},
);

class _TestSurface extends WidgetComponent {
  _TestSurface({
    required super.child,
    required super.size,
    required super.input,
    super.pixelRatio,
  }) : super.bindOnly(bind: (_) {}, update: WidgetUpdatePolicy.manual);

  final _controller = FakeWidgetTextureController();

  @override
  FakeWidgetTextureController get controller => _controller;
}

FacadeSurfaceBuilder _surfaceBuilder(List<_TestSurface> surfaces) =>
    ({
      required child,
      required width,
      required height,
      required pxPerMeter,
      input = WidgetInput.manual,
      pixelRatio = 1,
    }) {
      final surface = _TestSurface(
        child: child,
        size: Size(width * pxPerMeter, height * pxPerMeter),
        input: input,
        pixelRatio: pixelRatio,
      );
      surfaces.add(surface);
      return surface;
    };

void main() {
  final eye = Vector3(0, 1.7, 0);
  final forward = Vector3(0, 0, 1);

  testWidgets('flight prepares signs gradually without activating them', (
    tester,
  ) async {
    final surfaces = <_TestSurface>[];
    final ticks = ChecklistTicks();
    addTearDown(ticks.dispose);
    final lod = FacadeLodManager(
      buildings: [
        _building('first', 0, 40, facing: math.pi),
        _building('next', 0, 60, facing: math.pi),
        _building('later', 0, 80, facing: math.pi),
      ],
      config: FacadeLodConfig(promotionsPerFrame: 4),
      ticks: ticks,
      onOpen: (_) {},
      surfaceBuilder: _surfaceBuilder(surfaces),
    );
    addTearDown(lod.dispose);
    lod.update(eye, forward: forward, flying: true);
    expect((lod.stats.sign, lod.stats.far, lod.stats.live), (1, 2, 0));
    expect(surfaces.single.input, WidgetInput.manual);
    surfaces.single.controller.landed = 1;
    for (final seconds in [0.016, 0.05, 0.099]) {
      lod.update(eye, forward: forward, seconds: seconds, flying: true);
      expect(lod.stats.promotions, 1, reason: 'no flight-time loading burst');
    }
    lod.update(eye, forward: forward, seconds: 0.1, flying: true);
    expect((lod.stats.sign, lod.stats.far, lod.stats.live), (2, 1, 0));
    // Late image completion still refreshes a sign during travel.
    final first = surfaces.first;
    first.controller.landed = 1;
    (first.child as FacadeWidget).onCoverChanged!();
    lod.update(eye, forward: forward, seconds: 0.15, flying: true);
    expect(first.controller.requests, 2);
    expect(lod.stats.promotions, 2);
    lod.update(eye, forward: forward, seconds: 0.2, flying: true);
    expect((lod.stats.sign, lod.stats.far, lod.stats.live), (3, 0, 0));
    lod.config.signCap = 1;
    lod.update(eye, forward: forward, seconds: 0.21, flying: true);
    expect((lod.stats.sign, lod.stats.far, lod.stats.live), (1, 2, 0));
    expect(lod.stats.promotions, 3, reason: 'the surface cap still applies');
  });

  testWidgets('nearby facades stay static until tapped and disarm on leaving', (
    tester,
  ) async {
    final building = _building('near', 0, 10, facing: math.pi);
    final surfaces = <_TestSurface>[];
    final ticks = ChecklistTicks();
    addTearDown(ticks.dispose);
    final lod = FacadeLodManager(
      buildings: [building],
      config: FacadeLodConfig(),
      ticks: ticks,
      onOpen: (_) {},
      surfaceBuilder: _surfaceBuilder(surfaces),
    );
    addTearDown(lod.dispose);
    lod.update(eye, forward: forward);
    expect((lod.stats.live, lod.stats.sign), (0, 1));
    expect(surfaces.single.input, WidgetInput.manual);
    final sign = surfaces.single;
    expect(sign.pixelRatio, 0.5);
    expect(
      sign.size,
      const Size(720, 1080),
      reason: 'capture density must not shrink widget layout',
    );
    sign.controller.landed = 1;
    lod.update(eye, forward: forward, seconds: 3);
    expect(sign.controller.requests, 1, reason: 'a static sign does not poll');
    (sign.child as FacadeWidget).onCoverChanged!();
    lod.update(eye, forward: forward, seconds: 4);
    expect(
      sign.controller.requests,
      2,
      reason: 'late cover completion refreshes the sign',
    );
    sign.controller.landed = 2;

    expect(lod.activate(building, eye, forward: forward), isTrue);
    lod.update(eye, forward: forward, seconds: 5);
    expect((lod.stats.live, lod.stats.sign), (1, 0));
    expect(lod.focused, building);
    final live = surfaces.last;
    expect(live.input, WidgetInput.automatic);
    expect(live.pixelRatio, 1);
    expect((live.child as FacadeWidget).ticks, same(ticks));
    expect(live.controller.requests, 1);
    lod.update(eye, forward: forward, seconds: 5.1);
    expect(
      live.controller.requests,
      2,
      reason: 'interactive feedback keeps its cadence',
    );

    lod.update(Vector3(0, 1.7, -60), forward: forward, seconds: 6);
    expect((lod.stats.live, lod.stats.sign), (0, 1));
    expect(lod.focused, isNull);
    lod.update(eye, forward: forward, seconds: 7);
    expect(lod.stats.live, 0, reason: 'returning needs another tap');
    expect(
      live.controller.requests,
      2,
      reason: 'the old live texture stopped capturing',
    );
    (live.child as FacadeWidget).onCoverChanged!();
    lod.update(eye, forward: forward, seconds: 8);
    expect(
      live.controller.requests,
      2,
      reason: 'detached cover callbacks are ignored',
    );
    expect(
      lod.activate(building, Vector3(0, 1.7, -100), forward: forward),
      isFalse,
    );
    expect(lod.activate(building, eye, forward: -forward), isFalse);
  });

  test(
    'activation switches walls, disarms on turning, and respects the budget',
    () {
      final a = _building('a', -5, 10, facing: math.pi);
      final b = _building('b', 5, 10, facing: math.pi);
      final config = FacadeLodConfig(promotionsPerFrame: 2);
      final ticks = ChecklistTicks();
      addTearDown(ticks.dispose);
      final lod = FacadeLodManager(
        buildings: [a, b],
        config: config,
        ticks: ticks,
        onOpen: (_) {},
        surfaceBuilder: _surfaceBuilder([]),
      );
      addTearDown(lod.dispose);
      lod.update(eye, forward: forward);
      expect(lod.stats.sign, 2);
      expect(lod.activate(a, eye, forward: forward), isTrue);
      lod.update(eye, forward: forward);
      expect(lod.focused, a);
      expect(lod.activate(a, eye, forward: forward), isTrue);
      expect(lod.activate(b, eye, forward: forward), isTrue);
      lod.update(eye, forward: forward);
      expect((lod.stats.live, lod.stats.sign), (1, 1));
      expect(lod.focused, b);
      lod.update(eye, forward: -forward);
      expect(lod.stats.live, 0);
      lod.update(eye, forward: forward);
      expect(lod.stats.live, 0);
      config.liveCap = 0;
      expect(lod.activate(a, eye, forward: forward), isFalse);
      expect(lod.activate(_building('other', 0, 10), eye), isFalse);
      config.forceAllLive = true;
      lod.update(eye, forward: forward);
      expect(
        lod.stats.live,
        2,
        reason: 'explicit stress mode still bypasses activation',
      );
    },
  );

  group('ranking', () {
    test('runs once while the camera and the budget hold still', () {
      // Every building is beyond the sign distance: the ranking settles
      // at once and nothing is promoted (which would need a GPU).
      final lod = _manager([
        _building('a', 0, 200),
        _building('b', 0, -300),
        _building('c', 250, 0),
      ]);
      expect(lod.rankings, 0);

      lod.update(eye, forward: forward);
      expect(lod.rankings, 1);
      expect((lod.stats.far, lod.stats.promotions), (3, 0));

      lod
        ..update(eye, forward: forward, seconds: 0.016)
        ..update(eye, forward: forward, seconds: 0.033);
      expect(lod.rankings, 1, reason: 'nothing changed');

      lod.update(Vector3(1, 1.7, 0), forward: forward, seconds: 0.05);
      expect(lod.rankings, 2, reason: 'the eye moved');

      lod.update(Vector3(1, 1.7, 0), forward: Vector3(1, 0, 0), seconds: 0.07);
      expect(lod.rankings, 3, reason: 'the view direction changed');

      lod.update(Vector3(1, 1.7, 0), seconds: 0.08);
      expect(lod.rankings, 4, reason: 'the view direction was dropped');

      lod.config.liveCap = 6;
      lod.update(Vector3(1, 1.7, 0), seconds: 0.1);
      expect(lod.rankings, 5, reason: 'the budget changed');

      lod.update(Vector3(1, 1.7, 0), seconds: 0.12, flying: true);
      expect(lod.rankings, 6, reason: 'a flight started');
      lod.update(Vector3(1, 1.7, 0), seconds: 0.14, flying: true);
      expect(lod.rankings, 6);
    });

    test('keeps ranking while a promotion is waiting', () {
      // A zero promotion budget must leave the wanted sign pending.
      final starved = _manager(
        [_building('near', 0, 50)],
        config: FacadeLodConfig(promotionsPerFrame: 0),
      );
      for (var frame = 0; frame < 3; frame++) {
        starved.update(eye, forward: forward, seconds: frame * 0.016);
      }
      expect(starved.rankings, 3);
      expect(starved.stats.promotions, 0);
    });
  });

  test('describeNearest lists buildings nearest first with their tier', () {
    final lod = _manager([
      _building('far', 0, 400),
      _building('near', 0, 200),
      _building('mid', 0, 300),
    ])..update(eye, forward: forward);
    final described = lod.describeNearest(eye, count: 2);
    expect(
      described,
      'Building near on: far d=200.0 range=14.0 front=false | '
      'Building mid on: far d=300.0 range=14.0 front=false',
    );
  });
}
