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
    final lit = _groundLight(alpha);
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(color, alpha: lit)
      ..alphaMode = AlphaMode.blend;
    _washes.add((material, lit));
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

  /// The shadow a [height]-metre volume standing on [at] throws across the
  /// paving, [width] by [depth] at its foot.
  ///
  /// There is no light in this scene and nothing casts anything: this is
  /// two soft dark quads on the ground. It is the one thing that makes an
  /// unlit daylight city read as standing on its street rather than pasted
  /// onto it, which is why the day palette carries a sun angle at all.
  /// Night has no sun, so [PlazaSky.shadowLength] returns zero and nothing
  /// is added.
  ///
  /// Two quads, not one, because they do different jobs. The **contact**
  /// pad sits on the footprint and is what says the building meets the
  /// ground — it has to be there from every camera angle, including the one
  /// looking straight down the sun. The **cast** streak runs away from the
  /// sun and is what says where the sun is. One offset quad cannot be both:
  /// its falloff peaks half a shadow-length out, leaving the wall's own
  /// foot at a third of the density, which reads as a smudge on the paving
  /// rather than as contact.
  ///
  /// Both are square to the sun rather than to the building: a facade
  /// turned off-axis gets the larger of its two footprint sides, which at
  /// this softness reads correctly and costs no solve.
  void _addShadow(
    Vector3 at, {
    required double width,
    required double depth,
    required double height,
    bool contact = true,
  }) {
    final alpha = palette.lights.shadowAlpha;
    final length = palette.sky.shadowLength(height);
    if (alpha <= 0 || length <= 0) return;
    // Away from the sun, along the ground.
    final cast = palette.sky.sunAzimuth + math.pi;
    final lateral = math.max(width, depth);
    // A sign on two thin posts meets the ground at two thin posts: it
    // gets the streak its panel throws and no pad, or the pad would read
    // as a slab of shade the structure does not have.
    if (contact) {
      _shadowQuad(
        at,
        width: lateral * 1.25,
        length: lateral * 1.25,
        yaw: 0,
        alpha: alpha,
      );
    }
    _shadowQuad(
      Vector3(
        at.x + math.sin(cast) * length / 2,
        0,
        at.z + math.cos(cast) * length / 2,
      ),
      width: lateral * 1.1,
      length: lateral + length,
      yaw: cast,
      alpha: alpha * castShare,
    );
  }

  /// How much of the contact pad's density the cast streak carries. A
  /// shadow thrown across open paving is lighter than the dark under the
  /// wall itself, and the two overlap where they meet.
  static const castShare = 0.7;

  void _shadowQuad(
    Vector3 at, {
    required double width,
    required double length,
    required double yaw,
    required double alpha,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = linearColor(palette.lights.shadow, alpha: alpha)
      ..alphaMode = AlphaMode.blend;
    _shadows.add(material);
    scene.add(
      Node(
        localTransform:
            Matrix4.translation(
                Vector3(at.x, PlazaSceneController._groundTop, at.z),
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
