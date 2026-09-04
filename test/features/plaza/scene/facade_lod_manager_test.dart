import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/facade_lod_manager.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/ui/checklist_ticks.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

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

void main() {
  final eye = Vector3(0, 1.7, 0);
  final forward = Vector3(0, 0, 1);

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
      // Within the sign distance but flying: the sign is wanted every
      // frame and never granted, so the ranking is never settled.
      final lod = _manager([_building('near', 0, 50)]);
      for (var frame = 0; frame < 3; frame++) {
        lod.update(
          eye,
          forward: forward,
          seconds: frame * 0.016,
          flying: true,
        );
      }
      expect(lod.rankings, 3);
      expect((lod.stats.sign, lod.stats.far), (0, 1));

      // The same holds when the per-frame promotion budget is zero.
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
