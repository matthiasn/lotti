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
    // Every pool passes through the hour's ground-light scale, so daylight
    // takes them all out at once rather than each caller remembering to.
    final lit = _groundLight(alpha);
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: lit)
      ..alphaMode = AlphaMode.blend;
    _pools.add((material, lit));
    scene.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(at.x, PlazaSceneController.groundTop, at.z),
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
    Node? parent,
  }) {
    final lit = _groundLight(alpha);
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: lit)
      ..alphaMode = AlphaMode.blend;
    _washes.add((material, lit));
    (parent ?? scene.root).add(
      Node(
        localTransform:
            Matrix4.translation(
                Vector3(
                  at.x + math.sin(yaw) * length / 2,
                  PlazaSceneController.groundTop,
                  at.z + math.cos(yaw) * length / 2,
                ),
              )
              ..rotateY(yaw)
              ..rotateX(-math.pi / 2),
        mesh: Mesh(ccwQuad(width, length), material),
      ),
    );
  }

  /// The shade a [height]-metre volume standing on [at] throws across the
  /// paving, [width] by [depth] at its foot: the quads [shadeQuadsFor] plans
  /// for this hour, laid on the decal plane. Night plans none.
  ///
  /// [parent] is where the quads hang — the scene root unless the caster
  /// itself lives in a group that hides, in which case its shade must hide
  /// with it: a filler block that leaves the map view must not leave its
  /// shadow on the ground behind it.
  void _addShadow(
    Vector3 at, {
    required double width,
    required double depth,
    required double height,
    bool contact = true,
    Node? parent,
  }) {
    final quads = shadeQuadsFor(
      palette,
      x: at.x,
      z: at.z,
      width: width,
      depth: depth,
      height: height,
      contact: contact,
    );
    for (final quad in quads) {
      _shadowQuad(quad, parent: parent);
    }
  }

  void _shadowQuad(ShadeQuad quad, {Node? parent}) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(palette.lights.shadow, alpha: quad.alpha)
      ..alphaMode = AlphaMode.blend;
    _shadows.add(material);
    (parent ?? scene.root).add(
      Node(
        localTransform:
            Matrix4.translation(
                Vector3(quad.x, PlazaSceneController.groundTop, quad.z),
              )
              ..rotateY(quad.yaw)
              ..rotateX(-math.pi / 2),
        mesh: Mesh(ccwQuad(quad.width, quad.length), material),
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
    // The faux bloom behind an emitter. Daylight leaves a quarter of it:
    // enough that a lit sign still separates from its wall, not so much
    // that a haze hangs on a facade the sun is already on.
    final lit = alpha * glowScale;
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: lit)
      ..alphaMode = AlphaMode.blend
      ..depthBias = depthBias;
    _pools.add((material, lit));
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
      _postMaterial,
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
