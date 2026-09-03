/// The fixed camera tour the harness drives with `PLAZA_TOUR=1`: the poses
/// the documentation screenshots are taken from.
///
/// Poses are derived from the built street, never hard-coded, so they track
/// layout-knob changes; and they are a function of seeded data alone, so
/// the tour is reproducible on every machine.
library;

import 'dart:math' as math;

import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:lotti/features/plaza/domain/street_layout.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

/// Which harness dataset a tour stop is shot on.
enum TourPreset { large, demo }

/// One camera pose in world space.
class TourPose {
  const TourPose({
    required this.position,
    required this.yaw,
    this.pitch = 0,
    this.overhead = false,
  });

  final Vector3 position;
  final double yaw;
  final double pitch;
  final bool overhead;
}

/// What the tour needs to know about one building: its task and where its
/// facade is.
class TourBuilding {
  const TourBuilding({
    required this.task,
    required this.placement,
    required this.facadeCenter,
  });

  final PlazaTask task;
  final PlotPlacement placement;
  final Vector3 facadeCenter;
}

/// The street as the tour sees it — plain data, so poses are testable
/// without a GPU-backed scene. The harness projects its
/// `PlazaSceneController` into this.
class TourScene {
  const TourScene({
    required this.frontierEye,
    required this.frontierYaw,
    required this.plan,
    required this.buildings,
  });

  final Vector3 frontierEye;
  final double frontierYaw;
  final StreetPlan plan;
  final List<TourBuilding> buildings;
}

/// A named stop on the tour: a preset plus a pose derived from the scene
/// that preset builds.
class TourStop {
  const TourStop({
    required this.name,
    required this.preset,
    required this.pose,
  });

  final String name;
  final TourPreset preset;
  final TourPose Function(TourScene scene) pose;
}

/// Distance in front of a facade for a close-up, world meters.
const closeUpDistance = 16.0;

/// Eye height the walk camera enforces (mirrors `FlyCameraController`).
const _eyeHeight = 5.0;

/// The tour, in order. Names double as screenshot file names.
final List<TourStop> plazaTourStops = [
  TourStop(
    name: 'street-frontier',
    preset: TourPreset.large,
    pose: (scene) => TourPose(
      position: scene.frontierEye,
      yaw: scene.frontierYaw,
    ),
  ),
  TourStop(
    name: 'street-midway',
    preset: TourPreset.large,
    pose: (scene) => onRoadPose(scene, fraction: 0.4),
  ),
  TourStop(
    name: 'street-diagonal',
    preset: TourPreset.large,
    pose: (scene) {
      final straight = onRoadPose(scene, fraction: 0.55);
      return TourPose(
        position: straight.position,
        yaw: straight.yaw + 0.4,
        pitch: 0.1,
      );
    },
  ),
  TourStop(
    name: 'facade-closeup',
    preset: TourPreset.large,
    pose: (scene) => facingBuildingPose(closeUpCandidate(scene)),
  ),
  TourStop(
    name: 'overhead',
    preset: TourPreset.large,
    pose: (scene) {
      final straight = onRoadPose(scene, fraction: 0.5);
      return TourPose(
        position: straight.position,
        yaw: straight.yaw,
        overhead: true,
      );
    },
  ),
  TourStop(
    name: 'waddle-street',
    preset: TourPreset.demo,
    pose: (scene) => TourPose(
      position: scene.frontierEye,
      yaw: scene.frontierYaw,
    ),
  ),
  TourStop(
    name: 'waddle-closeup',
    preset: TourPreset.demo,
    pose: (scene) => facingBuildingPose(closeUpCandidate(scene)),
  ),
];

/// A pose standing on the road centre line at the start of the segment
/// [fraction] of the way down the street, looking along the road.
TourPose onRoadPose(TourScene scene, {required double fraction}) {
  final segments = scene.plan.segments;
  if (segments.isEmpty) return TourPose(position: Vector3.zero(), yaw: 0);
  final index = (segments.length * fraction).floor().clamp(
    0,
    segments.length - 1,
  );
  final segment = segments[index];
  return TourPose(
    position: Vector3(segment.startX, _eyeHeight, segment.startZ),
    yaw: segment.headingRadians,
    pitch: 0.06,
  );
}

/// The building whose facade makes the best close-up: the most open
/// checklist items, ties broken toward active states, then by id so the
/// choice is stable.
TourBuilding closeUpCandidate(TourScene scene) {
  int score(TourBuilding b) {
    final active = switch (b.task.state) {
      PlazaTaskState.inProgress || PlazaTaskState.open => 1,
      _ => 0,
    };
    return b.task.openChecklistItems.length * 2 + active;
  }

  final sorted = [...scene.buildings]
    ..sort((a, b) {
      final byScore = score(b).compareTo(score(a));
      return byScore != 0 ? byScore : a.task.id.compareTo(b.task.id);
    });
  return sorted.first;
}

/// A pose standing on the road [closeUpDistance] in front of [building],
/// looking straight at its facade, tilted so the facade centre stays in
/// frame from the fixed eye height.
TourPose facingBuildingPose(TourBuilding building) {
  final facing = building.placement.facingRadians;
  final outward = Vector3(math.sin(facing), 0, math.cos(facing));
  final eye = building.facadeCenter + outward * closeUpDistance;
  final rise = building.facadeCenter.y - _eyeHeight;
  return TourPose(
    position: Vector3(eye.x, _eyeHeight, eye.z),
    yaw: facing + math.pi,
    pitch: math.atan2(rise, closeUpDistance),
  );
}
