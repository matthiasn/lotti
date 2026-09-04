import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';
import 'package:lotti/features/plaza/ui/plaza_tour.dart';

import '../plaza_fixtures.dart';

PlazaWorld _world(List<PlazaTask> tasks) => PlazaWorld(
  tasks: tasks,
  now: syntheticNow(tasks),
  projectLabel: 'Test',
  layout: StreetLayout(projectSeed: 1337),
);

void main() {
  final large = _world(syntheticPlazaTasks(count: 300));
  // Two tasks a week apart: a street far too short to fold.
  final small = _world([
    for (var i = 0; i < 2; i++)
      PlazaTask(
        id: 't$i',
        createdAt: DateTime.utc(2026, 3, 2).add(Duration(days: 7 * i)),
        title: 'Task $i',
        state: PlazaTaskState.open,
        progress: 0,
        checklistItems: 0,
        linkedTaskIds: const [],
        categoryColor: 0,
      ),
  ]);

  test('covers the poses that matter', () {
    expect(
      plazaTourStops.map((s) => s.name),
      containsAll([
        'home',
        'overview',
        'block',
        'billboard',
        'attention-closeup',
        'shopfront',
        'jumbotron',
      ]),
    );
  });

  group('shopfrontPose', () {
    test('stands before a row, square on to a bare head end wall', () {
      final pose = shopfrontPose(large)!;
      final segment = large.plan.segments.firstWhere(
        (s) => !s.isGap && !s.isConnector && s.headingRadians == pose.yaw,
      );
      expect(pose.yaw, segment.headingRadians);
      expect(pose.y, eyeHeight);
      final sinH = math.sin(segment.headingRadians);
      final cosH = math.cos(segment.headingRadians);
      final along =
          (pose.x - segment.startX) * sinH + (pose.z - segment.startZ) * cosH;
      final lateral =
          (pose.x - segment.startX) * cosH - (pose.z - segment.startZ) * sinH;
      // On a plot's own line, one stand-off before the first end wall on
      // that side, and outside every footprint.
      final row = large.plan.placements.values
          .where(
            (p) =>
                p.bucketIndex == segment.bucketIndex &&
                ((p.x - segment.startX) * cosH -
                            (p.z - segment.startZ) * sinH -
                            lateral)
                        .abs() <
                    1e-6,
          )
          .toList();
      expect(row, isNotEmpty);
      final nearest = row.reduce(
        (a, b) =>
            ((a.x - segment.startX) * sinH + (a.z - segment.startZ) * cosH) <
                ((b.x - segment.startX) * sinH + (b.z - segment.startZ) * cosH)
            ? a
            : b,
      );
      final wall =
          (nearest.x - segment.startX) * sinH +
          (nearest.z - segment.startZ) * cosH -
          nearest.width / 2;
      expect(along, closeTo(wall - shopfrontStandOff, 1e-9));
      expect(large.collider.resolve(pose.x, pose.z), (pose.x, pose.z));
      // Never a wall that carries a plaza screen and ticker.
      expect(
        plazaMounts(large.plan).map((p) => p.taskId),
        isNot(contains(nearest.taskId)),
      );
    });

    test('skips a head wall that is a plaza mount', () {
      // Two tasks in one week, one a side: both heads are the plaza
      // mounts of this one-row street, so there is no bare head wall.
      final world = _world([
        for (var i = 0; i < 2; i++)
          PlazaTask(
            id: 't$i',
            createdAt: DateTime.utc(2026, 3, 2, 9 + i),
            title: 'Task $i',
            state: PlazaTaskState.open,
            progress: 0,
            checklistItems: 0,
            linkedTaskIds: const [],
            categoryColor: 0,
          ),
      ]);
      expect(plazaMounts(world.plan), hasLength(2));
      expect(shopfrontPose(world), isNull);
    });

    test('prefers the head that is on alarm', () {
      final alarmed = large.plan.placements.values.where(
        (p) => switch (large.attention[p.taskId]!.lantern) {
          LanternState.blocked || LanternState.overdue => true,
          _ => false,
        },
      );
      // The fixture has alarms; whether a head is one is data, so assert
      // the rule on a world built to have exactly one alarmed head.
      expect(alarmed, isNotEmpty);
      final tasks = [
        for (var i = 0; i < 4; i++)
          PlazaTask(
            id: 't$i',
            createdAt: DateTime.utc(2026, 3, 2, 9 + i),
            title: 'Task $i',
            state: i == 1 ? PlazaTaskState.blocked : PlazaTaskState.open,
            progress: 0,
            checklistItems: 0,
            linkedTaskIds: const [],
            categoryColor: 0,
          ),
      ];
      final world = _world(tasks);
      final head = world.plan.placements['t1']!;
      expect(world.attention['t1']!.lantern, LanternState.blocked);
      final pose = shopfrontPose(world)!;
      final segment = world.plan.segments.first;
      final lateral =
          (pose.x - segment.startX) * math.cos(segment.headingRadians) -
          (pose.z - segment.startZ) * math.sin(segment.headingRadians);
      final headLateral =
          (head.x - segment.startX) * math.cos(segment.headingRadians) -
          (head.z - segment.startZ) * math.sin(segment.headingRadians);
      expect(lateral, closeTo(headLateral, 1e-9));
    });

    test('prefers a trading head over one shut for the night', () {
      PlazaWorld world(PlazaTaskState left, PlazaTaskState right) => _world([
        for (final (i, state) in [
          left,
          right,
          PlazaTaskState.open,
          PlazaTaskState.open,
        ].indexed)
          PlazaTask(
            id: 't$i',
            createdAt: DateTime.utc(2026, 3, 2, 9 + i),
            title: 'Task $i',
            state: state,
            progress: 0,
            checklistItems: 0,
            linkedTaskIds: const [],
            categoryColor: 0,
          ),
      ]);
      double lateralOf(PlazaWorld w, CameraPose pose) {
        final s = w.plan.segments.first;
        return (pose.x - s.startX) * math.cos(s.headingRadians) -
            (pose.z - s.startZ) * math.sin(s.headingRadians);
      }

      double plotLateral(PlazaWorld w, String id) {
        final s = w.plan.segments.first;
        final p = w.plan.placements[id]!;
        return (p.x - s.startX) * math.cos(s.headingRadians) -
            (p.z - s.startZ) * math.sin(s.headingRadians);
      }

      final doneLeft = world(PlazaTaskState.done, PlazaTaskState.inProgress);
      expect(doneLeft.attention['t0']!.lantern, LanternState.off);
      expect(doneLeft.attention['t1']!.lantern, LanternState.inProgress);
      expect(
        lateralOf(doneLeft, shopfrontPose(doneLeft)!),
        closeTo(plotLateral(doneLeft, 't1'), 1e-9),
      );
      final doneRight = world(PlazaTaskState.open, PlazaTaskState.done);
      expect(
        lateralOf(doneRight, shopfrontPose(doneRight)!),
        closeTo(plotLateral(doneRight, 't0'), 1e-9),
      );
    });

    test('is null without a built week', () {
      final empty = PlazaWorld(
        tasks: const [],
        now: DateTime.utc(2026, 7, 17),
        projectLabel: 'Empty',
        layout: StreetLayout(projectSeed: 1337),
      );
      expect(shopfrontPose(empty), isNull);
    });
  });

  test('names are unique and usable as file names', () {
    final names = plazaTourStops.map((s) => s.name).toList();
    expect(names.toSet().length, names.length);
    for (final name in names) {
      expect(RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(name), isTrue, reason: name);
    }
  });

  test('every stop resolves on a district with anomalies and folds', () {
    for (final stop in plazaTourStops) {
      final pose = stop.pose(large);
      expect(pose, isNotNull, reason: stop.name);
      expect(pose!.x.isFinite && pose.z.isFinite && pose.yaw.isFinite, isTrue);
    }
    expect(
      plazaTourStops.firstWhere((s) => s.name == 'home').pose(large),
      large.plaza!.home,
    );
    expect(
      plazaTourStops.firstWhere((s) => s.name == 'overview').pose(large),
      large.plaza!.overview,
    );
  });

  test('a project with no anomalies has no attention stop', () {
    expect(
      plazaTourStops
          .firstWhere((s) => s.name == 'attention-closeup')
          .pose(small),
      isNull,
    );
  });

  test('is a pure function of the world', () {
    final again = _world(syntheticPlazaTasks(count: 300));
    for (final stop in plazaTourStops) {
      final a = stop.pose(large)!;
      final b = stop.pose(again)!;
      expect(a.x, b.x, reason: stop.name);
      expect(a.z, b.z);
      expect(a.yaw, b.yaw);
      expect(a.pitch, b.pitch);
    }
  });

  test('blockBeaconPose walks oldest to newest and clamps', () {
    final blocks = large.beacons
        .where((b) => b.kind == BeaconKind.block)
        .toList();
    final oldest = blocks.last.pose; // beacons list newest first
    expect(blockBeaconPose(large, fraction: 0)!.x, oldest.x);
    expect(blockBeaconPose(large, fraction: 5)!.x, blocks.first.pose.x);
    final empty = PlazaWorld(
      tasks: const [],
      now: DateTime.utc(2026),
      projectLabel: 'Empty',
      layout: StreetLayout(projectSeed: 1),
    );
    expect(blockBeaconPose(empty, fraction: 0.5), isNull);
  });
}
