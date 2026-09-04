/// The fixed camera tour the harness drives with `PLAZA_TOUR=1`: the poses
/// the documentation screenshots are taken from.
///
/// Poses are derived from the built world, never hard-coded, so they track
/// layout changes; and they are a function of seeded data alone, so the
/// tour is reproducible on every machine.
library;

import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_surfaces.dart';
import 'package:lotti/features/plaza/scene/plaza_world.dart';

/// A named stop on the tour: a pose derived from the world. Poses may be
/// null when the world lacks the thing (no anomalies, no plaza); the
/// harness skips those stops.
class TourStop {
  const TourStop({required this.name, required this.pose});

  final String name;
  final CameraPose? Function(PlazaWorld world) pose;
}

/// The tour, in order. Names double as screenshot file names.
final List<TourStop> plazaTourStops = [
  TourStop(
    name: 'home',
    pose: (w) => w.plaza?.home,
  ),
  TourStop(
    name: 'overview',
    pose: (w) => w.plaza?.overview,
  ),
  TourStop(
    name: 'block',
    pose: (w) => blockBeaconPose(w, fraction: 0.25),
  ),
  TourStop(
    name: 'billboard',
    pose: (w) {
      final slot = w.plaza?.pylons.firstOrNull;
      return slot == null ? null : PlazaSurfaces.facingPose(slot);
    },
  ),
  TourStop(
    name: 'attention-closeup',
    // The second anomaly when there is one: the billboard stop has just
    // shown the first, and six stops should show a project, not a task.
    pose: (w) {
      final attention = w.beacons
          .where((b) => b.kind == BeaconKind.attention)
          .toList();
      if (attention.isEmpty) return null;
      return attention[attention.length > 1 ? 1 : 0].pose;
    },
  ),
  TourStop(
    name: 'jumbotron',
    pose: (w) {
      final slot = w.jumbotron;
      return slot == null
          ? null
          : PlazaSurfaces.facingPose(slot, distance: slot.width * 1.1);
    },
  ),
];

/// The block beacon [fraction] of the way from oldest to newest, or null
/// when the street has no built weeks.
CameraPose? blockBeaconPose(PlazaWorld world, {required double fraction}) {
  final blocks = world.beacons
      .where((b) => b.kind == BeaconKind.block)
      .toList()
      .reversed
      .toList(); // oldest first
  if (blocks.isEmpty) return null;
  final index = (blocks.length * fraction).floor().clamp(0, blocks.length - 1);
  return blocks[index].pose;
}
