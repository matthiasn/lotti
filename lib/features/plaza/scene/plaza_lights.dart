part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaLightsBuilder on PlazaSceneController {
  /// A light pool on the ground: one quad with a radial-falloff texture
  /// (hot core, long feathered skirt) in the light's colour, above the
  /// pavement top; fades with camera altitude in [updateForCamera].
  void _addPool(
    Vector3 at, {
    required double radius,
    required Color color,
    required double alpha,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: alpha)
      ..alphaMode = AlphaMode.blend;
    _pools.add((material, alpha));
    scene.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(at.x, PlazaSceneController._groundTop, at.z),
        )..rotateX(-math.pi / 2),
        mesh: Mesh(ccwQuad(radius * 2, radius * 2), material),
      ),
    );
  }

  /// A rectangular pool: the radial falloff stretched over [width] by
  /// [length] on the ground, its far edge at [at] and its length running
  /// out along [yaw]. The streak a lit panel leaves on wet paving, or the
  /// strip of light a parade throws on the pavement.
  void _addWash(
    Vector3 at, {
    required double width,
    required double length,
    required double yaw,
    required Color color,
    required double alpha,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: alpha)
      ..alphaMode = AlphaMode.blend;
    _washes.add((material, alpha));
    scene.add(
      Node(
        localTransform:
            Matrix4.translation(
                Vector3(
                  at.x + math.sin(yaw) * length / 2,
                  PlazaSceneController._groundTop,
                  at.z + math.cos(yaw) * length / 2,
                ),
              )
              ..rotateY(yaw)
              ..rotateX(-math.pi / 2),
        mesh: Mesh(ccwQuad(width, length), material),
      ),
    );
  }

  Node _glowQuad(
    double width,
    double height,
    Color color,
    double alpha, {
    double depthBias = 0,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: alpha)
      ..alphaMode = AlphaMode.blend
      ..depthBias = depthBias;
    _pools.add((material, alpha));
    return Node(mesh: Mesh(ccwQuad(width, height), material));
  }

  /// A spire [size] square and [height] tall standing on [base] under
  /// [parent], with the anchor for its blinking light [lightAbove] the
  /// tip. The jumbotron and hero towers hang theirs 0.4 up, a plot 0.3.
  void _spire(
    Node parent,
    Vector3 base, {
    required double size,
    required double height,
    required double lightAbove,
  }) {
    _box(
      parent,
      Vector3(base.x, base.y + height / 2, base.z),
      Vector3(size, height, size),
      PlazaSceneController._postMaterial,
    );
    final light = Node(
      localTransform: Matrix4.translation(
        Vector3(base.x, base.y + height + lightAbove, base.z),
      ),
    );
    parent.add(light);
    bindings.spireAnchors.add(light);
  }
}
