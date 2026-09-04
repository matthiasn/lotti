import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart';

/// Scene-owned unit boxes and immutable solid materials. Sharing geometry
/// and material identity lets flutter_scene instance compatible opaque draws.
/// The caller supplies GPU geometry; node transforms and material reuse can
/// therefore be tested without uploading any vertices.
class PlazaBoxes {
  PlazaBoxes({required this.cube, required this.shadedCube});

  final Geometry cube;
  final Geometry shadedCube;
  final Map<(double, double, double, double, double), UnlitMaterial> _solids =
      {};

  /// Reuses an untextured solid colour, including its depth bias. Returned
  /// materials must not be mutated: animated or textured materials belong
  /// to their individual surfaces instead. The colour is copied so later
  /// writes to the caller's vector cannot change an already shared material.
  UnlitMaterial solid(Vector4 color, {double depthBias = 0}) =>
      _solids.putIfAbsent(
        (color.x, color.y, color.z, color.w, depthBias),
        () => UnlitMaterial()
          ..baseColorFactor = Vector4.copy(color)
          ..depthBias = depthBias,
      );

  /// Builds an unscaled anchor with a scaled unit mesh underneath it.
  /// Children added to the anchor retain their original local coordinates;
  /// ray hits on the mesh can still resolve a pick target on the anchor.
  /// Only unlit materials are accepted: nonuniform scale must not change
  /// lighting through the renderer's normal transform.
  Node node(
    Vector3 size,
    UnlitMaterial material, {
    Matrix4? transform,
    bool shaded = false,
  }) => Node(localTransform: transform)
    ..add(
      Node(
        localTransform: Matrix4.diagonal3(size),
        mesh: Mesh(shaded ? shadedCube : cube, material),
      ),
    );
}
