part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaWallsBuilder on PlazaSceneController {
  /// A blended tiled overlay just above a ground slab, one texture tile
  /// every [tileMeters]: the asphalt grain on a road, the paving joints
  /// on the plaza. [materials] collects it for [attachWallTextures]; a
  /// [fading] overlay dims with altitude like a pool.
  void _addTiledOverlay(
    Node parent, {
    required double width,
    required double depth,
    required double y,
    required double tileMeters,
    required List<UnlitMaterial> materials,
    bool fading = false,
  }) {
    final material = UnlitMaterial()
      ..baseColorFactor = Vector4(1, 1, 1, 0.4)
      ..alphaMode = AlphaMode.blend;
    materials.add(material);
    if (fading) _pools.add((material, 0.4));
    parent.add(
      Node(
        localTransform: Matrix4.translation(Vector3(0, y, 0))
          ..rotateX(-math.pi / 2),
        mesh: Mesh(
          tiledQuad(
            width,
            depth,
            uRepeat: width / tileMeters,
            vRepeat: depth / tileMeters,
          ),
          material,
        ),
      ),
    );
  }

  /// A wall face: a shopfront band at the foot (the parade of shops,
  /// dressed for [shops], which defaults to [state]: trading, late,
  /// fitting out, shuttered, closed; [variant] picks the parade order;
  /// [family] the window tile's occupancy)
  /// under the window grid of [state]'s lit ratio, stacked in whole
  /// storeys from the band up with the remainder as a dark cornice, so no
  /// cut row ever sits on the fascia. The quad's face is +Z before [yaw];
  /// [dx], [dz] place it on the parent's box, whose centre sits at half
  /// [height].
  void _windowedWall(
    Node parent, {
    required double dx,
    required double dz,
    required double yaw,
    required double width,
    required double height,
    required LanternState state,
    required Vector4 tint,
    required double uOffset,
    LanternState? shops,
    int variant = 0,
    int family = 0,
  }) {
    final ground = math.min(
      PlazaSceneController.shopfrontHeight,
      height * 0.45,
    );
    final shop = UnlitMaterial()..baseColorFactor = tint;
    _shopfrontMaterials
        .putIfAbsent((shops ?? state, variant), () => [])
        .add(shop);
    parent.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(dx, -height / 2 + ground / 2, dz),
        )..rotateY(yaw),
        mesh: Mesh(
          tiledQuad(
            width,
            ground,
            uRepeat: width / WallTextures.shopfrontWidth,
            vRepeat: ground / WallTextures.shopfrontHeight,
            uOffset: uOffset,
          ),
          shop,
        ),
      ),
    );
    final upper = height - ground;
    if (upper <= 0.1) return;
    final floors = (upper / WallTextures.storeyHeight).floor();
    final storeys = floors * WallTextures.storeyHeight;
    final cornice = upper - storeys;
    if (floors > 0) {
      final windows = UnlitMaterial()..baseColorFactor = tint;
      _wallMaterials.putIfAbsent((state, family), () => []).add(windows);
      parent.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(dx, -height / 2 + ground + storeys / 2, dz),
          )..rotateY(yaw),
          mesh: Mesh(
            tiledQuad(
              width,
              storeys,
              uRepeat: width / WallTextures.tileWidth,
              vRepeat: floors / WallTextures.floors,
              uOffset: uOffset,
              // The tile's floor slabs sit at its own storey lines; start
              // at a whole tile so the first slab lands on the fascia.
              vOffset: 1 - floors / WallTextures.floors,
            ),
            windows,
          ),
        ),
      );
    }
    if (cornice > 0.05) {
      parent.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(dx, height / 2 - cornice / 2, dz),
          )..rotateY(yaw),
          mesh: Mesh(
            ccwQuad(width, cornice),
            PlazaSceneController._corniceMaterial,
          ),
        ),
      );
    }
  }

  /// Windowed walls ([_windowedWall]) on [faces] of the [w] × [d] box
  /// under [parent], in that order, whose centre sits at half [height].
  /// Each face tiles from its own hashed offset so it starts at its own
  /// shop, unless [perFaceOffset] is off and every face shares one.
  void _windowedBox(
    Node parent, {
    required String id,
    required double w,
    required double d,
    required double height,
    required LanternState state,
    required Vector4 tint,
    List<_Face> faces = _Face.values,
    bool perFaceOffset = true,
    LanternState? shops,
    int variant = 0,
    int family = 0,
  }) {
    for (final face in faces) {
      // A quad's face is +Z before rotation: rotateY(-π/2) turns it to -X
      // for the left wall, rotateY(π/2) to +X for the right, π for the
      // back.
      final (dx, dz, yaw, width) = switch (face) {
        _Face.front => (0.0, d / 2 + 0.02, 0.0, w),
        _Face.back => (0.0, -d / 2 - 0.02, math.pi, w),
        _Face.right => (w / 2 + 0.02, 0.0, math.pi / 2, d),
        _Face.left => (-w / 2 - 0.02, 0.0, -math.pi / 2, d),
      };
      _windowedWall(
        parent,
        dx: dx,
        dz: dz,
        yaw: yaw,
        width: width,
        height: height,
        state: state,
        tint: tint,
        uOffset: stableUnit(id, perFaceOffset ? 'tile$yaw' : 'tile') * 3,
        shops: shops,
        variant: variant,
        family: family,
      );
    }
  }
}
