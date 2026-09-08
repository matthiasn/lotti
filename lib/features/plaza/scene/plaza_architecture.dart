import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:lotti/features/plaza/domain/building_architecture.dart';
import 'package:lotti/features/plaza/scene/plaza_boxes.dart';
import 'package:vector_math/vector_math.dart';

/// Articulates reserved building volumes with recessed glazing, structural
/// piers, cornices and illuminated setbacks. All dimensions are world metres;
/// materials belong to the caller's existing scene palette.
///
/// Unit meshes and materials remain shared. Detail is bounded per volume,
/// generated once, and baked with the rest of the static city. Skyline towers
/// retain their silhouette and crown without the street-level column grid.
class PlazaArchitecture {
  PlazaArchitecture(this.boxes);

  final PlazaBoxes boxes;

  /// Builds in the recipe's ground-centred frame. [onVolume] dresses the inset
  /// wall core (usually with shared window textures); trim remains inside the
  /// original envelope and never crosses the front sign plane.
  Node build(
    BuildingArchitecture architecture, {
    required UnlitMaterial wall,
    required UnlitMaterial trim,
    required UnlitMaterial light,
    required void Function(Node, BuildingVolume, {required bool groundFloor})
    onVolume,
    bool detailed = true,
  }) {
    final root = Node(name: 'architecture-${architecture.family.name}');
    for (final (index, volume) in architecture.volumes.indexed) {
      final relief = math.min(0.28, math.min(volume.width, volume.depth) / 20);
      final core = BuildingVolume(
        width: volume.width - relief * 2,
        depth: volume.depth - relief * 2,
        bottom: volume.bottom,
        height: volume.height,
        x: volume.x,
        z: volume.z,
      );
      final tier = boxes.node(
        Vector3(core.width, core.height, core.depth),
        wall,
        transform: Matrix4.translation(
          Vector3(core.x, core.bottom + core.height / 2, core.z),
        ),
        shaded: true,
      );
      root.add(tier);
      onVolume(tier, core, groundFloor: index == 0);

      final crown = volume.bottom >= architecture.frontageHeight;
      final band = math.min(0.3, volume.height / 12);
      if (!detailed) {
        // Background buildings are read by silhouette. Keep just the lit crown
        // course as one cap: four separate rim pieces and a ground-floor
        // coping across the skyline cost vertices even when draw counts match.
        if (crown) {
          _piece(
            root,
            Vector3(volume.x, volume.top - band * 1.75, volume.z),
            Vector3(volume.width, band / 2, volume.depth),
            light,
          );
        }
        continue;
      }
      _rim(root, volume, volume.top - band, band, trim);
      // A recessed luminous course under the coping gives the stepped crown
      // a recognizable silhouette without adding an opaque roof-sized light.
      if (crown || index == 0) {
        _rim(root, volume, volume.top - band * 2, band / 2, light);
      }
      if (index == 0) continue;

      final pier = math.min(0.42, math.min(volume.width, volume.depth) / 12);
      final height = volume.height - band;
      // Four corner piers frame the sign, with their outer edge on the solid.
      for (final side in [-1.0, 1.0]) {
        for (final end in [-1.0, 1.0]) {
          _piece(
            root,
            Vector3(
              volume.x + side * (volume.width - pier) / 2,
              volume.bottom + height / 2,
              volume.z + end * (volume.depth - pier) / 2,
            ),
            Vector3(pier, height, pier),
            trim,
          );
        }
      }

      if (architecture.family == BuildingFamily.mediaTower) {
        // Side-wall spandrels give the glass family a horizontal rhythm.
        // Deliberately omit the street-facing span where the task sign lives.
        final courses = (volume.height / 9).floor().clamp(0, 6);
        for (var i = 1; i <= courses; i++) {
          _rim(
            root,
            volume,
            volume.bottom + volume.height * i / (courses + 1),
            band / 2,
            trim,
            front: crown,
          );
        }
      } else {
        // Stone/theater bays have real depth instead of a printed grid.
        // The count caps generation even for unusually wide task envelopes.
        final bays = (volume.depth / 5).floor().clamp(1, 6);
        for (var i = 1; i < bays; i++) {
          for (final side in [-1.0, 1.0]) {
            _piece(
              root,
              Vector3(
                volume.x + side * (volume.width - relief) / 2,
                volume.bottom + height / 2,
                volume.z - volume.depth / 2 + volume.depth * i / bays,
              ),
              Vector3(relief, height, pier),
              trim,
            );
          }
        }
        // Crown flutes are visible from Home; below it the sign stays clear.
        if (crown) {
          final flutes = (volume.width / 4).floor().clamp(1, 6);
          for (var i = 1; i < flutes; i++) {
            _piece(
              root,
              Vector3(
                volume.x - volume.width / 2 + volume.width * i / flutes,
                volume.bottom + height / 2,
                volume.z + (volume.depth - relief) / 2,
              ),
              Vector3(pier, height, relief),
              trim,
            );
          }
        }
      }
    }
    return root;
  }

  void _piece(Node root, Vector3 center, Vector3 size, UnlitMaterial material) {
    root.add(
      boxes.node(
        size,
        material,
        transform: Matrix4.translation(center),
        shaded: true,
      ),
    );
  }

  void _rim(
    Node root,
    BuildingVolume volume,
    double bottom,
    double height,
    UnlitMaterial material, {
    bool front = true,
  }) {
    final reach = math.min(0.35, math.min(volume.width, volume.depth) / 10);
    for (final side in [-1.0, 1.0]) {
      if (side < 0 || front) {
        _piece(
          root,
          Vector3(
            volume.x,
            bottom + height / 2,
            volume.z + side * (volume.depth - reach) / 2,
          ),
          Vector3(volume.width, height, reach),
          material,
        );
      }
      _piece(
        root,
        Vector3(
          volume.x + side * (volume.width - reach) / 2,
          bottom + height / 2,
          volume.z,
        ),
        Vector3(reach, height, volume.depth),
        material,
      );
    }
  }
}
