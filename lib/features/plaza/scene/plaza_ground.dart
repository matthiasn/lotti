part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaGroundBuilder on PlazaSceneController {
  void _build() {
    _buildSky();

    final (centerX, centerZ) = planCenterOf(plan);
    final buildSkyline = _shown('skyline');
    _box(
      scene.root,
      Vector3(centerX, -0.06, centerZ),
      Vector3(6000, 0.1, 6000),
      _boxes.solid(PlazaSceneController._ground),
    );
    if (buildSkyline) {
      _buildSkyline();
      _buildHeroTowers();
    }

    for (final segment in plan.segments) {
      final midAlong = segment.length / 2;
      final mid = Vector3(
        segment.startX + math.sin(segment.headingRadians) * midAlong,
        0,
        segment.startZ + math.cos(segment.headingRadians) * midAlong,
      );
      final roadNode = _boxes.node(
        Vector3(layout.roadWidth, 0.08, segment.length + 0.4),
        _boxes.solid(
          segment.isGap
              ? PlazaSceneController._gap
              : PlazaSceneController._road,
        ),
        transform: Matrix4.translation(mid)..rotateY(segment.headingRadians),
      );
      // Pavements with a kerb step on both sides, and a dashed centre
      // line: the street section that makes a slab read as a road.
      for (final side in [-1.0, 1.0]) {
        _box(
          roadNode,
          Vector3(side * (layout.roadWidth / 2 - 1.5), 0.05, 0),
          Vector3(3, 0.1, segment.length + 0.4),
          PlazaSceneController._pavementMaterial,
        );
        // A kerb you could stub a toe on: a raised stone edge between the
        // road and the pavement.
        _box(
          roadNode,
          Vector3(side * (layout.roadWidth / 2 - 3), 0.09, 0),
          Vector3(0.35, 0.18, segment.length + 0.4),
          PlazaSceneController._kerbMaterial,
        );
      }
      // The map layer: a teal ribbon down the axis of every segment,
      // connectors included, shown from the air so the overview reads
      // as a route and not a dark render.
      final ribbon = _box(
        roadNode,
        Vector3(0, 0.1, 0),
        Vector3(0.9, 0.02, segment.length + 0.4),
        _boxes.solid(PlazaSceneController._ribbon),
      )..visible = false;
      _mapRibbons.add(ribbon);
      if (!segment.isGap) {
        for (
          var along = -segment.length / 2 + 3;
          along < segment.length / 2 - 2;
          along += 6
        ) {
          _box(
            roadNode,
            Vector3(0, 0.045, along),
            Vector3(0.18, 0.01, 2.2),
            _boxes.solid(PlazaSceneController._centreLine),
          );
        }
      }
      _addTiledOverlay(
        roadNode,
        width: layout.roadWidth,
        depth: segment.length + 0.4,
        y: 0.045,
        tileMeters: 2,
        materials: _grainMaterials,
      );
      scene.add(roadNode);
      if (!segment.isGap) {
        const along = 9.0;
        final anchor = Node(
          localTransform:
              Matrix4.translation(
                  Vector3(
                    segment.startX + math.sin(segment.headingRadians) * along,
                    PlazaSceneController._groundTop + 0.02,
                    segment.startZ + math.cos(segment.headingRadians) * along,
                  ),
                )
                // Oriented to the map shot (the last row's heading), not
                // the row's own: on a folded row the label would be
                // upside down from the air, and the air is where it is
                // read.
                ..rotateY(
                  (plan.last?.headingRadians ?? segment.headingRadians) +
                      math.pi,
                )
                ..rotateX(-math.pi / 2),
        );
        scene.add(anchor);
        bindings.markerAnchors[segment.bucketIndex] = anchor;
      }
    }

    final plaza = world.plaza;
    if (plaza != null) {
      final slab = _boxes.node(
        Vector3(plaza.width, 0.1, plaza.depth),
        _boxes.solid(PlazaSceneController._ground),
        transform: Matrix4.translation(
          Vector3(plaza.centerX, 0.01, plaza.centerZ),
        )..rotateY(plaza.headingRadians),
      );
      _addTiledOverlay(
        slab,
        width: plaza.width,
        depth: plaza.depth,
        y: 0.06,
        tileMeters: 2,
        materials: _grainMaterials,
      );
      _addTiledOverlay(
        slab,
        width: plaza.width,
        depth: plaza.depth,
        y: 0.07,
        tileMeters: WallTextures.pavingMeters,
        materials: _pavingMaterials,
        fading: true,
      );
      // Home marker ring on the ground.
      scene
        ..add(slab)
        ..add(
          Node(
            localTransform: Matrix4.translation(
              Vector3(plaza.home.x, 0.08, plaza.home.z),
            ),
            mesh: Mesh(
              RingGeometry(innerRadius: 3.2, outerRadius: 3.8),
              UnlitMaterial()
                ..baseColorFactor = linearColor(PlazaStyle.teal, alpha: 0.4)
                ..alphaMode = AlphaMode.blend,
            ),
          ),
        );
      // A soft warm pool under home, so the landing is a lit spot on a
      // square rather than a ring on a car park.
      _addPool(
        Vector3(plaza.home.x, 0, plaza.home.z),
        radius: 7,
        color: const Color(0xFFFFE2B8),
        alpha: 0.14,
      );
      _buildPlazaKerb(plaza);
      _buildPlazaFurniture();
    }

    final byId = {for (final t in world.tasks) t.id: t};
    for (final placement in plan.placements.values) {
      final task = byId[placement.taskId];
      if (task == null) continue;
      if (task.deleted) {
        _buildEmptyLot(placement);
      } else {
        _buildBuilding(task, placement);
      }
    }

    for (final (:slot, :attention) in world.builtBillboards) {
      if (slot.onPylon && !_shown('pylons')) continue;
      _buildBillboard(slot, attention);
    }
    for (final (:slot, :attention) in world.roofPanels) {
      _buildBillboard(slot, attention);
    }
    if (_shown('fillers')) _buildFillerBlocks();
    _buildStreetFurniture();
  }

  /// A raised kerb round the plaza's edge, open at the street mouth: a
  /// square with an edge, not a slab. Low enough to step over, so it is
  /// not a solid.
  void _buildPlazaKerb(FrontierPlaza plaza) {
    const kerbW = 0.35;
    const kerbH = 0.16;
    const mouth = 26.0;
    final root = Node(
      localTransform: Matrix4.translation(
        Vector3(plaza.centerX, kerbH / 2, plaza.centerZ),
      )..rotateY(plaza.headingRadians),
    );
    final hw = plaza.width / 2;
    final hd = plaza.depth / 2;
    for (final (dx, dz, sx, sz) in [
      (hw - kerbW / 2, 0.0, kerbW, plaza.depth),
      (-hw + kerbW / 2, 0.0, kerbW, plaza.depth),
      (0.0, hd - kerbW / 2, plaza.width, kerbW),
      // The mouth side, in two runs either side of the opening.
      ((hw + mouth / 2) / 2, -hd + kerbW / 2, hw - mouth / 2, kerbW),
      (-(hw + mouth / 2) / 2, -hd + kerbW / 2, hw - mouth / 2, kerbW),
    ]) {
      _box(
        root,
        Vector3(dx, 0, dz),
        Vector3(sx, kerbH, sz),
        PlazaSceneController._kerbMaterial,
      );
    }
    // The threshold: a flush band across the opening, so the step from
    // street to square is a line on the ground you cross.
    _box(
      root,
      Vector3(0, -kerbH / 2 + 0.05, -hd),
      Vector3(mouth, 0.02, 0.7),
      PlazaSceneController._kerbMaterial,
    );
    scene.add(root);
  }
}
