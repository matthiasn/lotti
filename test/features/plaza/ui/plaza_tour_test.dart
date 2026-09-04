import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_surfaces.dart';
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

  group('jumbotronStopPose', () {
    test('stands beside the plaza on the tower side, clear of the pylons', () {
      final pose = jumbotronStopPose(large)!;
      final plaza = large.plaza!;
      final slot = large.jumbotron!;
      final h = plaza.headingRadians;
      double lateralOf(double x, double z) =>
          (x - plaza.centerX) * math.cos(h) - (z - plaza.centerZ) * math.sin(h);
      double alongOf(double x, double z) =>
          (x - plaza.centerX) * math.sin(h) + (z - plaza.centerZ) * math.cos(h);
      expect(pose.y, eyeHeight);
      expect(lateralOf(pose.x, pose.z).sign, lateralOf(slot.x, slot.z).sign);
      expect(
        lateralOf(pose.x, pose.z).abs(),
        closeTo(plaza.width / 2 + jumbotronStopClearance, 1e-9),
      );
      expect(
        alongOf(pose.x, pose.z),
        closeTo(plaza.depth / 2 - jumbotronStopBack, 1e-9),
      );
      expect(
        pose.yaw,
        closeTo(math.atan2(slot.x - pose.x, slot.z - pose.z), 1e-9),
      );
      expect(pose.pitch, greaterThan(0));
      expect(pose.pitch, lessThanOrEqualTo(jumbotronStopPitch));
      // The line of sight to the screen passes no pylon panel.
      final dx = slot.x - pose.x;
      final dz = slot.z - pose.z;
      final len = math.sqrt(dx * dx + dz * dz);
      for (final pylon in plaza.pylons) {
        final px = pylon.x - pose.x;
        final pz = pylon.z - pose.z;
        final off = (px * dz - pz * dx).abs() / len;
        final ahead = (px * dx + pz * dz) / len;
        if (ahead <= 0 || ahead >= len) continue;
        expect(
          off,
          greaterThan(pylon.width / 2 + 1),
          reason: 'pylon ${pylon.rank}',
        );
      }
    });

    test('is null without a plaza', () {
      final empty = PlazaWorld(
        tasks: const [],
        now: DateTime.utc(2026, 7, 17),
        projectLabel: 'Empty',
        layout: StreetLayout(projectSeed: 1337),
      );
      expect(jumbotronStopPose(empty), isNull);
    });
  });

  group('shopfrontPose', () {
    test('stands on the road at a row head, facing the near corner', () {
      final pose = shopfrontPose(large)!;
      expect(pose.y, eyeHeight);
      // Find the head building the pose looks at: the one whose near
      // corner lies straight ahead.
      final segments = large.plan.segments.where(
        (s) => !s.isGap && !s.isConnector,
      );
      PlotPlacement? head;
      RoadSegment? row;
      for (final segment in segments) {
        final sinH = math.sin(segment.headingRadians);
        final cosH = math.cos(segment.headingRadians);
        for (final p in large.plan.placements.values) {
          if (p.bucketIndex != segment.bucketIndex) continue;
          final along =
              (p.x - segment.startX) * sinH + (p.z - segment.startZ) * cosH;
          final lateral =
              (p.x - segment.startX) * cosH - (p.z - segment.startZ) * sinH;
          final toRoad = lateral < 0 ? 1.0 : -1.0;
          final ca = along - p.width / 2;
          final cl = lateral + toRoad * p.depth / 2;
          final cx = segment.startX + sinH * ca + cosH * cl;
          final cz = segment.startZ + cosH * ca - sinH * cl;
          final expectAlong = ca - shopfrontStandOff;
          final expectLateral = cl + toRoad * shopfrontRoadOffset;
          final ex = segment.startX + sinH * expectAlong + cosH * expectLateral;
          final ez = segment.startZ + cosH * expectAlong - sinH * expectLateral;
          if ((pose.x - ex).abs() < 1e-6 && (pose.z - ez).abs() < 1e-6) {
            head = p;
            row = segment;
            expect(pose.yaw, closeTo(math.atan2(cx - ex, cz - ez), 1e-9));
          }
        }
      }
      expect(head, isNotNull, reason: 'the pose matches no head corner');
      // The head of its row on its side, never a plaza mount, and the
      // eye is on the road, outside every footprint.
      final sinH = math.sin(row!.headingRadians);
      final cosH = math.cos(row.headingRadians);
      double along(PlotPlacement p) =>
          (p.x - row!.startX) * sinH + (p.z - row.startZ) * cosH;
      for (final p in large.plan.placements.values) {
        if (p.bucketIndex == row.bucketIndex && p.side == head!.side) {
          expect(along(p), greaterThanOrEqualTo(along(head) - 1e-9));
        }
      }
      expect(
        plazaMounts(large.plan).map((p) => p.taskId),
        isNot(contains(head!.taskId)),
      );
      expect(large.collider.resolve(pose.x, pose.z), (pose.x, pose.z));
      final eyeLateral =
          (pose.x - row.startX) * cosH - (pose.z - row.startZ) * sinH;
      expect(eyeLateral.abs(), lessThan(9), reason: 'on the road');
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

    test('skips the alarmed head another stop already shows', () {
      // Four tasks in one week: the blocked one is the top billboard and
      // the closeup's anomaly, so the shopfront stop looks at the other
      // head rather than showing it a third time.
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
      expect(world.billboards.first.task.id, 't1');
      expect(closeupBeacon(world)!.taskId, 't1');
      final head = world.plan.placements['t0']!;
      final pose = shopfrontPose(world)!;
      final segment = world.plan.segments.first;
      final lateral =
          (pose.x - segment.startX) * math.cos(segment.headingRadians) -
          (pose.z - segment.startZ) * math.sin(segment.headingRadians);
      final headLateral =
          (head.x - segment.startX) * math.cos(segment.headingRadians) -
          (head.z - segment.startZ) * math.sin(segment.headingRadians);
      expect(lateral.sign, headLateral.sign);
      expect(lateral.abs(), lessThan(headLateral.abs()));
    });

    test("pitches to the wall's middle, never past the cap", () {
      final pose = shopfrontPose(large)!;
      expect(pose.pitch, greaterThan(0));
      expect(pose.pitch, lessThanOrEqualTo(PlazaSurfaces.maxFacingPitch));
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
        lateralOf(doneLeft, shopfrontPose(doneLeft)!).sign,
        plotLateral(doneLeft, 't1').sign,
      );
      final doneRight = world(PlazaTaskState.open, PlazaTaskState.done);
      expect(
        lateralOf(doneRight, shopfrontPose(doneRight)!).sign,
        plotLateral(doneRight, 't0').sign,
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
