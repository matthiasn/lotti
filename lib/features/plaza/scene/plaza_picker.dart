import 'dart:ui' show Offset, Size;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/plaza_layout.dart';
import 'package:lotti/features/plaza/scene/plaza_scene.dart';
import 'package:lotti/features/plaza/scene/plaza_sprites.dart';

/// What a tap landed on.
sealed class PickResult {
  const PickResult();
}

class PickedBeacon extends PickResult {
  const PickedBeacon(this.beacon);

  final Beacon beacon;
}

class PickedBuilding extends PickResult {
  const PickedBuilding(this.building);

  final PlazaBuilding building;
}

class PickedBillboard extends PickResult {
  const PickedBillboard(this.billboard);

  final PlazaBillboard billboard;
}

/// Resolves a tap: beacon dots first (screen-space, they are sprites the
/// raycaster skips), then a ray into the scene for buildings and
/// billboards.
class PlazaPicker {
  PlazaPicker({required this.controller, required this.sprites});

  final PlazaSceneController controller;
  final PlazaSprites sprites;

  /// Beacon dots accept a tap within this many logical pixels.
  static const beaconHitPx = 14.0;

  /// Facades and billboards farther than this ignore taps: flying across
  /// the district from a skyline click is disorienting, beacons are for
  /// that.
  static const maxTapDistance = 160.0;

  PickResult? pick(Camera camera, Size viewSize, Offset point) {
    Beacon? nearestBeacon;
    var nearest = beaconHitPx;
    for (final (beacon, screen) in sprites.visibleBeaconScreenPositions(
      camera,
      viewSize,
    )) {
      final d = (screen - point).distance;
      if (d < nearest) {
        nearest = d;
        nearestBeacon = beacon;
      }
    }
    if (nearestBeacon != null) return PickedBeacon(nearestBeacon);

    final ray = camera.screenPointToRay(point, viewSize);
    final hit = controller.scene.raycast(ray, maxDistance: maxTapDistance);
    if (hit == null) return null;
    Node? node = hit.node;
    while (node != null) {
      final billboard = controller.pickableBillboards[node];
      if (billboard != null) return PickedBillboard(billboard);
      final building = controller.pickableBuildings[node];
      if (building != null) return PickedBuilding(building);
      node = node.parent;
    }
    return null;
  }
}
