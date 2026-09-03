import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/plaza_generator.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:lotti/features/plaza/ui/plaza_tour.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// Builds a [TourScene] the way the scene controller would, without a GPU:
/// same street plan, same facade-centre formula.
TourScene _sceneFor(List<PlazaTask> tasks) {
  final layout = StreetLayout(projectSeed: 1337);
  final plan = layout.plan(tasks);
  final byId = {for (final t in tasks) t.id: t};
  final buildings = <TourBuilding>[];
  for (final placement in plan.placements.values) {
    final task = byId[placement.taskId]!;
    if (task.deleted) continue;
    final facing = placement.facingRadians;
    final d = placement.depth;
    buildings.add(
      TourBuilding(
        task: task,
        placement: placement,
        facadeCenter: Vector3(
          placement.x + math.sin(facing) * (d / 2),
          placement.height / 2,
          placement.z + math.cos(facing) * (d / 2),
        ),
      ),
    );
  }
  final last = plan.segments.last;
  return TourScene(
    frontierEye: Vector3(
      last.startX + math.sin(last.headingRadians) * last.length,
      1.7,
      last.startZ + math.cos(last.headingRadians) * last.length,
    ),
    frontierYaw: last.headingRadians + math.pi,
    plan: plan,
    buildings: buildings,
  );
}

void main() {
  final scene = _sceneFor(generatePlazaTasks(preset: PlazaPreset.medium));

  group('tour stops', () {
    test('names are unique and usable as file names', () {
      final names = plazaTourStops.map((s) => s.name).toList();
      expect(names.toSet().length, names.length);
      for (final name in names) {
        expect(
          RegExp(r'^[a-z][a-z0-9-]*$').hasMatch(name),
          isTrue,
          reason: name,
        );
      }
    });

    test('covers both presets, the overhead view and a close-up', () {
      expect(
        plazaTourStops.map((s) => s.preset).toSet(),
        TourPreset.values.toSet(),
      );
      expect(plazaTourStops.where((s) => s.pose(scene).overhead), hasLength(1));
      expect(plazaTourStops.map((s) => s.name), contains('facade-closeup'));
    });

    test('every pose is finite and stands at eye height', () {
      for (final stop in plazaTourStops) {
        final pose = stop.pose(scene);
        expect(pose.position.x.isFinite && pose.position.z.isFinite, isTrue);
        expect(pose.yaw.isFinite, isTrue);
        expect(pose.pitch.abs(), lessThan(1.35));
      }
    });

    test('is a pure function of the scene', () {
      final again = _sceneFor(generatePlazaTasks(preset: PlazaPreset.medium));
      for (final stop in plazaTourStops) {
        final a = stop.pose(scene);
        final b = stop.pose(again);
        expect(a.position, b.position, reason: stop.name);
        expect(a.yaw, b.yaw);
        expect(a.pitch, b.pitch);
      }
    });
  });

  group('onRoadPose', () {
    test('stands at a segment start looking along its heading', () {
      final pose = onRoadPose(scene, fraction: 0.4);
      final index = (scene.plan.segments.length * 0.4).floor();
      final segment = scene.plan.segments[index];
      // Vector3 stores float32; compare within that precision.
      expect(pose.position.x, closeTo(segment.startX, 1e-3));
      expect(pose.position.z, closeTo(segment.startZ, 1e-3));
      expect(pose.yaw, segment.headingRadians);
    });

    test('clamps the fraction to the last segment', () {
      final pose = onRoadPose(scene, fraction: 5);
      final last = scene.plan.segments.last;
      expect(pose.position.x, closeTo(last.startX, 1e-3));
      expect(pose.position.z, closeTo(last.startZ, 1e-3));
    });

    test('an empty street yields the origin', () {
      final empty = TourScene(
        frontierEye: Vector3.zero(),
        frontierYaw: 0,
        plan: StreetPlan(
          epoch: DateTime.utc(2000),
          segments: const [],
          placements: const {},
        ),
        buildings: const [],
      );
      expect(onRoadPose(empty, fraction: 0.5).position, Vector3.zero());
    });
  });

  group('closeUpCandidate', () {
    test('picks the building with the most open checklist items', () {
      final pick = closeUpCandidate(scene);
      final most = scene.buildings
          .map((b) => b.task.openChecklistItems.length)
          .reduce(math.max);
      expect(pick.task.openChecklistItems.length, most);
    });

    test('prefers an active task on a tie, then the lowest id', () {
      TourBuilding building(String id, PlazaTaskState state, int items) =>
          TourBuilding(
            task: PlazaTask(
              id: id,
              createdAt: DateTime.utc(2026),
              title: id,
              state: state,
              progress: 0,
              checklistItems: items,
              linkedTaskIds: const [],
              categoryColor: 0,
              openChecklistItems: List.filled(items, 'x'),
            ),
            placement: const PlotPlacement(
              taskId: 'x',
              bucketIndex: 0,
              side: PlotSide.left,
              x: 0,
              z: 0,
              facingRadians: 0,
              width: 4,
              depth: 6,
              height: 5,
            ),
            facadeCenter: Vector3.zero(),
          );
      final tie = TourScene(
        frontierEye: Vector3.zero(),
        frontierYaw: 0,
        plan: scene.plan,
        buildings: [
          building('b-done', PlazaTaskState.done, 3),
          building('c-open', PlazaTaskState.open, 3),
          building('a-open', PlazaTaskState.open, 3),
          building('d-open', PlazaTaskState.open, 2),
        ],
      );
      expect(closeUpCandidate(tie).task.id, 'a-open');
    });
  });

  group('facingBuildingPose', () {
    test('stands closeUpDistance in front of the facade, looking at it', () {
      final building = closeUpCandidate(scene);
      final pose = facingBuildingPose(building);

      final facing = building.placement.facingRadians;
      final outward = Vector3(math.sin(facing), 0, math.cos(facing));
      final toFacade = Vector3(
        building.facadeCenter.x - pose.position.x,
        0,
        building.facadeCenter.z - pose.position.z,
      );
      // Horizontal distance is exactly the close-up distance...
      expect(toFacade.length, closeTo(closeUpDistance, 1e-3));
      // ...straight back along the facade normal...
      expect(toFacade.normalized().dot(outward), closeTo(-1, 1e-4));
      // ...and the yaw points the camera at the facade.
      final forward = Vector3(math.sin(pose.yaw), 0, math.cos(pose.yaw));
      expect(forward.dot(toFacade.normalized()), closeTo(1, 1e-4));
    });

    test('tilts up toward a tall facade and down toward a low one', () {
      TourBuilding ofHeight(double height) => TourBuilding(
        task: closeUpCandidate(scene).task,
        placement: PlotPlacement(
          taskId: 'x',
          bucketIndex: 0,
          side: PlotSide.left,
          x: 0,
          z: 0,
          facingRadians: 0,
          width: 4,
          depth: 6,
          height: height,
        ),
        facadeCenter: Vector3(0, height / 2, 3),
      );
      expect(facingBuildingPose(ofHeight(12)).pitch, greaterThan(0));
      expect(facingBuildingPose(ofHeight(10)).pitch, 0);
      expect(facingBuildingPose(ofHeight(3)).pitch, lessThan(0));
    });
  });
}
