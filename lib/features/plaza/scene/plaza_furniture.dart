part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaFurnitureBuilder on PlazaSceneController {
  /// Benches, planters and the kiosk from `Scenery.furniture`: the boxes
  /// are the collider's, the dressing is here.
  void _buildPlazaFurniture() {
    final seat = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF4A3A2E));
    final soil = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF1E1A1C));
    final leaves = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF1F3A28));
    for (final f in world.scenery.furniture) {
      final root = Node(
        localTransform: Matrix4.translation(Vector3(f.x, 0, f.z))
          ..rotateY(f.yawRadians),
      );
      switch (f.kind) {
        case FurnitureKind.bench:
          // Three slats on a dark frame, a back rail, two end frames.
          for (final dx in [-f.width * 0.34, 0.0, f.width * 0.34]) {
            _box(
              root,
              Vector3(dx, f.height * 0.5, 0),
              Vector3(f.width * 0.28, 0.06, f.depth),
              seat,
            );
          }
          _box(
            root,
            Vector3(0, f.height * 0.46, 0),
            Vector3(f.width * 0.9, 0.04, f.depth * 0.9),
            PlazaSceneController._postMaterial,
          );
          _box(
            root,
            Vector3(-f.width * 0.55, f.height * 0.75, 0),
            Vector3(0.06, f.height * 0.5, f.depth),
            seat,
          );
          for (final dz in [-f.depth * 0.4, f.depth * 0.4]) {
            _box(
              root,
              Vector3(0, f.height * 0.25, dz),
              Vector3(f.width * 0.9, f.height * 0.5, 0.08),
              PlazaSceneController._postMaterial,
            );
          }
        case FurnitureKind.planter:
          root.add(
            _boxes.node(
              Vector3(f.width, f.height, f.depth),
              PlazaSceneController._postMaterial,
              transform: Matrix4.translation(Vector3(0, f.height / 2, 0)),
              shaded: true,
            ),
          );
          _box(
            root,
            Vector3(0, f.height + 0.02, 0),
            Vector3(f.width - 0.2, 0.04, f.depth - 0.2),
            soil,
          );
          root.add(
            _boxes.node(
              Vector3(f.width * 0.72, 0.5, f.depth * 0.72),
              leaves,
              transform: Matrix4.translation(
                Vector3(0, f.height + 0.25, 0),
              ),
              shaded: true,
            ),
          );
          // A lit rim along the planter's top edge, in the parade's warm.
          _box(
            root,
            Vector3(0, f.height + 0.01, 0),
            Vector3(f.width + 0.06, 0.03, f.depth + 0.06),
            _boxes.solid(
              linearColor(
                const Color(0xFFFFC46B),
                alpha: 0.8,
              ),
            ),
          );
        case FurnitureKind.kiosk:
          final sign = UnlitMaterial()
            ..baseColorFactor = linearColor(const Color(0xFFFFC46B));
          final window = UnlitMaterial()
            ..baseColorFactor = linearColor(
              const Color(0xFFFFD08A),
              alpha: 0.75,
            )
            ..alphaMode = AlphaMode.blend;
          _pools.add((window, 0.75));
          root.add(
            _boxes.node(
              Vector3(f.width, f.height, f.depth),
              PlazaSceneController._towerMaterial,
              transform: Matrix4.translation(Vector3(0, f.height / 2, 0)),
              shaded: true,
            ),
          );
          // The lit sign along the front's top edge, and the hatch.
          _box(
            root,
            Vector3(0, f.height - 0.3, f.depth / 2 + 0.03),
            Vector3(f.width - 0.3, 0.4, 0.06),
            sign,
          );
          root.add(
            Node(
              localTransform: Matrix4.translation(
                Vector3(0, f.height * 0.5, f.depth / 2 + 0.02),
              ),
              mesh: Mesh(ccwQuad(f.width - 0.8, f.height * 0.42), window),
            ),
          );
          _box(
            root,
            Vector3(0, f.height + 0.05, 0),
            Vector3(f.width + 0.4, 0.1, f.depth + 0.4),
            PlazaSceneController._postMaterial,
          );
          _addPool(
            Vector3(
              f.x + math.sin(f.yawRadians) * 2,
              0,
              f.z + math.cos(f.yawRadians) * 2,
            ),
            radius: 3,
            color: const Color(0xFFFFD08A),
            alpha: 0.16,
          );
      }
      scene.add(root);
    }
  }

  /// Lamp posts, the gantry over the street mouth, the jumbotron tower,
  /// banner anchors and spires: the set dressing that makes a street a
  /// place.
  void _buildStreetFurniture() {
    for (final (x, z) in world.lampPosts) {
      final pole = _box(
        scene.root,
        Vector3(x, lampPostHeight / 2, z),
        Vector3(lampPostSize, lampPostHeight, lampPostSize),
        PlazaSceneController._postMaterial,
      );
      // Housing: a small dark head the bulb hangs under.
      _box(
        pole,
        Vector3(0, 2.7, 0),
        Vector3(0.7, 0.28, 0.7),
        PlazaSceneController._postMaterial,
      );
      final lantern = Node(
        localTransform: Matrix4.translation(Vector3(0, 2.45, 0)),
      );
      pole.add(lantern);
      bindings.lampAnchors.add(lantern);
      _addPool(
        Vector3(x, 0, z),
        radius: 5,
        color: const Color(0xFFFFE2B8),
        alpha: 0.3,
      );
    }
    // Every beacon dot stands on a slim post over a small pool in its own
    // colour, so a marker is a fixture in the street and not a stray orb.
    for (final beacon in world.beacons) {
      final colour = PlazaStyle.beaconColor(beacon, world);
      _box(
        scene.root,
        Vector3(beacon.markerX, beacon.markerY / 2, beacon.markerZ),
        Vector3(0.08, beacon.markerY, 0.08),
        PlazaSceneController._postMaterial,
      );
      _addPool(
        Vector3(beacon.markerX, 0, beacon.markerZ),
        radius: 1.6,
        color: colour,
        alpha: 0.18,
      );
    }

    // Week signs hang from the block-head lamp post: one fixture, not a
    // sign, a lamp and a screen crowding the same kerb.
    for (final (bucket, x, z, facing) in world.weekSigns) {
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(
            x + math.sin(facing) * 0.14,
            3.2,
            z + math.cos(facing) * 0.14,
          ),
        )..rotateY(facing),
      );
      scene.add(anchor);
      bindings.weekSignAnchors[bucket] = anchor;
    }

    final gantry = world.gantry;
    if (gantry != null && _shown('gantry')) {
      final root = Node(
        localTransform: Matrix4.translation(Vector3(gantry.x, 0, gantry.z))
          ..rotateY(gantry.facingRadians),
      );
      final top = gantryTopFor(gantry);
      for (final side in [-1.0, 1.0]) {
        _box(
          root,
          Vector3(side * gantry.width / 2, top / 2, 0),
          Vector3(gantryLegSize, top, gantryLegSize),
          PlazaSceneController._postMaterial,
        );
      }
      _box(
        root,
        Vector3(0, top - gantryBeamThickness / 2, 0),
        Vector3(
          gantry.width + gantryLegSize,
          gantryBeamThickness,
          gantryBeamDepth,
        ),
        PlazaSceneController._postMaterial,
      );
      root.add(
        _glowQuad(gantry.width + 2, gantry.height + 2.5, PlazaStyle.teal, 0.2)
          ..localTransform = Matrix4.translation(
            Vector3(0, gantry.bottom + gantry.height / 2, -0.3),
          ),
      );
      scene.add(root);
      _addPool(
        Vector3(gantry.x, 0, gantry.z),
        radius: gantry.width * 0.3,
        color: PlazaStyle.teal,
        alpha: 0.05,
      );
    }

    final jumbotron = world.jumbotron;
    if (jumbotron != null && _shown('jumbotron')) {
      final root = Node(
        localTransform: Matrix4.translation(
          Vector3(jumbotron.x, 0, jumbotron.z),
        )..rotateY(jumbotron.facingRadians),
      );
      final box = world.scenery.jumbotronTower!;
      final towerH = box.height;
      final towerW = box.width;
      final towerD = box.depth;
      // The tower is a building, not a slab: windowed on every face, a
      // lit crown, neon on its front corners. Its box is the scenery's,
      // so the collider knows it.
      final tower = _boxes.node(
        Vector3(towerW, towerH, towerD),
        PlazaSceneController._towerMaterial,
        transform: Matrix4.translation(
          Vector3(0, towerH / 2, -jumbotronTowerSetback),
        ),
        shaded: true,
      );
      _windowedBox(
        tower,
        id: 'jumbotron',
        w: towerW,
        d: towerD,
        height: towerH,
        state: LanternState.inProgress,
        tint: PlazaSceneController._tower,
      );
      // The corner strips and crown at a quarter, so the screen's own
      // border is the one teal frame on the tower.
      final corner = UnlitMaterial()
        ..baseColorFactor = linearColor(
          Color.lerp(const Color(0xFF0B0A14), PlazaStyle.teal, 0.3)!,
        );
      for (final side in [-1.0, 1.0]) {
        _box(
          tower,
          Vector3(side * (towerW / 2 + 0.1), 0, towerD / 2 + 0.1),
          Vector3(0.25, towerH, 0.25),
          corner,
        );
      }
      // The crown is four rim strips, not a lid.
      _rim(
        tower,
        w: towerW,
        d: towerD,
        y: towerH / 2 + 0.1,
        inset: -0.1,
        overhang: 0.4,
        thickness: 0.22,
        material: corner,
      );
      root.add(tower);
      final backing = _box(
        root,
        Vector3(0, jumbotron.centerY, -0.2),
        Vector3(jumbotron.width + 0.6, jumbotron.height + 0.6, 0.4),
        _boxes.solid(linearColor(PlazaStyle.teal)),
      );
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(0, jumbotron.centerY, 0.06),
        ),
      );
      root.add(anchor);
      bindings.jumbotronAnchor = anchor;
      root.add(
        _glowQuad(
            jumbotron.width + 8,
            jumbotron.height + 8,
            PlazaStyle.teal,
            0.22,
          )
          ..localTransform = Matrix4.translation(
            Vector3(0, jumbotron.centerY, -0.5),
          ),
      );
      final jsin = math.sin(jumbotron.facingRadians);
      final jcos = math.cos(jumbotron.facingRadians);
      _addPool(
        Vector3(jumbotron.x + jsin * 9, 0, jumbotron.z + jcos * 9),
        radius: jumbotron.width * 0.3,
        color: PlazaStyle.teal,
        alpha: 0.12,
      );
      _addWash(
        Vector3(jumbotron.x + jsin * 4, 0, jumbotron.z + jcos * 4),
        width: jumbotron.width * 0.7,
        length: jumbotron.width * 0.9,
        yaw: jumbotron.facingRadians,
        color: PlazaStyle.teal,
        alpha: 0.06,
      );
      // The tower's own spire.
      _spire(
        root,
        Vector3(0, towerH, -jumbotronTowerSetback),
        size: SpireStyle.jumbotron.size,
        height: SpireStyle.jumbotron.height,
        lightAbove: 0.4,
      );
      scene.add(root);
      final billboard = PlazaBillboard(
        slot: jumbotron,
        attention: world.billboards.isEmpty
            ? world.attention.values.first
            : world.billboards.first,
        backing: backing,
        anchor: anchor,
      );
      bindings.chaseLightPoints[billboard] = _frameCorners(jumbotron);
    }

    for (final banner in world.banners) {
      final anchor = Node(
        localTransform: Matrix4.translation(
          Vector3(banner.x, banner.centerY, banner.z),
        )..rotateY(banner.facingRadians),
      );
      scene.add(anchor);
      bindings.bannerAnchors[banner.taskId] = anchor;
    }

    for (final p in world.spires) {
      _spire(
        scene.root,
        Vector3(p.x, p.height, p.z),
        size: SpireStyle.plot.size,
        height: SpireStyle.plot.height,
        lightAbove: 0.3,
      );
    }
  }
}
