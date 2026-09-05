part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaSkylineBuilder on PlazaSceneController {
  void _buildSky() {
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: linearColor(const Color(0xFF03030B)).xyz,
        horizonColor: linearColor(const Color(0xFF2A2446)).xyz,
        groundColor: linearColor(const Color(0xFF090A16)).xyz,
        sunColor: Vector3.zero(),
      ),
    );
    // Ground-hugging haze in the horizon's own colour: the street dissolves
    // into the sky instead of hitting a seam, and it thins with altitude
    // so the overview still sees the district. The night is a desaturated
    // indigo so amber signage sits warm against it; the magenta lives in
    // the hero towers' domes alone.
    // Real bloom: the emitters (neon, screens, chase heads, rooflines)
    // bleed into the night the way a lightbox does, and a soft vignette
    // pulls the eye to the centre of every frame.
    scene.postProcess.bloom
      ..enabled = true
      ..threshold = PlazaSceneController.bloomThreshold
      ..intensity = PlazaSceneController.bloomIntensity
      ..scatter = 0.6;
    scene.postProcess.vignette
      ..enabled = true
      ..intensity = 0.32
      ..radius = 0.82
      ..smoothness = 0.6;
    scene.fog
      ..enabled = true
      ..mode = FogMode.exponential
      ..density = PlazaSceneController.fogDensityLow
      ..start = 8
      ..height = 0
      ..heightFalloff = 0.028
      ..maxOpacity = PlazaSceneController.fogOpacityLow
      // Between the ground and the horizon: the haze never outshines the
      // paving the walker stands on.
      ..color = linearColor(const Color(0xFF181727)).xyz;
  }

  /// City fabric behind the plots (`Scenery.fillers`): dark windowed
  /// blocks with alleys between them, so the street has a back and the
  /// overview has texture between the plots and the skyline.
  void _buildFillerBlocks() {
    for (final block in world.scenery.fillers) {
      final id = block.id;
      final side = block.side;
      final bw = block.depth; // frontage along the road
      final bd = block.width; // reach away from it
      final bh = block.height;
      // Local x is lateral, local z runs along the road: the block is
      // bw long along the street and bd deep away from it.
      final node = _boxes.node(
        Vector3(bd, bh, bw),
        PlazaSceneController._towerMaterial,
        transform: Matrix4.translation(Vector3(block.x, bh / 2, block.z))
          ..rotateY(block.yawRadians),
        shaded: true,
      );
      final parade = stableIndex(id, 'parade', WallTextures.paradeVariants);
      final kit = stableIndex(id, 'kit', WallTextures.tileFamilies);
      // Windows on every face: a filler is seen from the street, from
      // the plaza and from above.
      _windowedBox(
        node,
        id: id,
        w: bd,
        d: bw,
        height: bh,
        faces: const [_Face.right, _Face.left, _Face.front, _Face.back],
        state: LanternState.open,
        tint: PlazaSceneController._tower,
        // The fabric trades all night, whatever its flats are doing.
        shops: LanternState.inProgress,
        variant: parade,
        family: kit,
      );
      // The parade's light on the pavement, on the street side.
      {
        final yaw = block.yawRadians + (side < 0 ? math.pi / 2 : -math.pi / 2);
        _addWash(
          Vector3(
            block.x + math.sin(yaw) * bd / 2,
            0,
            block.z + math.cos(yaw) * bd / 2,
          ),
          width: bw,
          length: 2.5,
          yaw: yaw,
          color: const Color(0xFFFFC46B),
          alpha: 0.06,
        );
      }
      if (stableUnit(id, 'sign') < 0.34) {
        // A neon sign down the street-facing corner, named after one
        // of the week's own tasks' category.
        final weekTasks =
            plan.placements.values
                .where((p) => p.bucketIndex == block.bucketIndex)
                .map((p) => p.taskId)
                .toList()
              ..sort();
        if (weekTasks.isNotEmpty) {
          final pick = stableIndex(id, 'pick', weekTasks.length);
          final anchor = Node(
            localTransform: Matrix4.translation(
              Vector3(-side * (bd / 2 + 0.08), bh * 0.15, -bw / 2 + 1.2),
            )..rotateY(side < 0 ? math.pi / 2 : -math.pi / 2),
          );
          node.add(anchor);
          bindings.fillerSigns.add((anchor, 1.6, bh * 0.6, weekTasks[pick]));
        }
      }
      scene.add(node);
    }
  }

  /// One hero tower past the far end of every row that folds
  /// (`Scenery.heroTowers`), on the row's axis, with a screen toward the
  /// street and a warm light dome behind it: the horizon a walker walks
  /// toward. The last row's far end has the jumbotron instead.
  void _buildHeroTowers() {
    for (final tower in world.scenery.heroTowers) {
      final id = tower.id;
      final w = tower.width;
      final bd = tower.depth;
      final height = tower.height;
      // The root faces back down the row.
      final root = Node(
        localTransform: Matrix4.translation(Vector3(tower.x, 0, tower.z))
          ..rotateY(tower.yawRadians),
      );
      final box = _boxes.node(
        Vector3(w, height, bd),
        PlazaSceneController._towerMaterial,
        transform: Matrix4.translation(Vector3(0, height / 2, 0)),
        shaded: true,
      );
      final parade = stableIndex(id, 'parade', WallTextures.paradeVariants);
      root.add(box);
      _windowedBox(
        box,
        id: id,
        w: w,
        d: bd,
        height: height,
        state: LanternState.inProgress,
        tint: PlazaSceneController._tower,
        variant: parade,
      );
      // Crown: a lit trim and a spire with a blinking light.
      _box(
        root,
        Vector3(0, height + 0.1, 0),
        Vector3(w + 0.3, 0.2, bd + 0.3),
        _boxes.solid(linearColor(PlazaStyle.teal, alpha: 0.9)),
      );
      _spire(
        root,
        Vector3(0, height, 0),
        size: SpireStyle.hero.size,
        height: SpireStyle.hero.height,
        lightAbove: 0.4,
      );
      // The screen, toward the street, and the dome of light behind the
      // tower that the row's vanishing point sits in.
      if (world.anomalies.isNotEmpty) {
        final sw = w * 0.9;
        final sh = sw * 0.62;
        final frame = PlazaStyle.lantern(world.anomalies.first.lantern);
        _towerScreen(
          root,
          width: sw,
          height: sh,
          y: height * 0.62,
          front: bd / 2,
          frame: frame,
          glowMargin: 8,
          glowAlpha: 0.28,
          rank: 0,
        );
        // The screen's wash on the ground before the tower.
        _addPool(
          Vector3(
            tower.x + math.sin(tower.yawRadians) * (bd / 2 + sw * 0.6),
            0,
            tower.z + math.cos(tower.yawRadians) * (bd / 2 + sw * 0.6),
          ),
          radius: sw * 1.2,
          color: frame,
          alpha: 0.06,
        );
      }
      root.add(
        _glowQuad(w * 9, height * 1.4, const Color(0xFFFF7A4A), 0.11)
          ..localTransform = Matrix4.translation(
            Vector3(0, height * 0.35, -bd / 2 - 24),
          ),
      );
      scene.add(root);
    }
  }

  /// A ring of dark towers around the district (`Scenery.skyline`) so the
  /// street dissolves into a city instead of a black table. Seeded, never
  /// data.
  void _buildSkyline() {
    for (final tower in world.scenery.skyline) {
      final id = tower.id;
      final i = tower.index;
      final w = tower.width;
      final h = tower.height;
      final node = _boxes.node(
        Vector3(w, h, tower.depth),
        _boxes.solid(PlazaSceneController._skyline),
        transform: Matrix4.translation(Vector3(tower.x, h / 2, tower.z))
          ..rotateY(tower.yawRadians),
        shaded: true,
      );
      // A lit roofline along the district-facing edge, warm and teal by
      // turns, so the ring is a glowing horizon and not a row of dots.
      final roofline = i.isEven ? const Color(0xFFFFC46B) : PlazaStyle.teal;
      _box(
        node,
        Vector3(0, h / 2 + 0.1, tower.depth / 2 - 0.1),
        Vector3(w + 0.2, 0.25, 0.25),
        _boxes.solid(
          emissiveColor(roofline, PlazaSceneController.neonBoost, alpha: 0.95),
        ),
      );
      node.add(
        _glowQuad(w + 4, 3, roofline, 0.16)
          ..localTransform = Matrix4.translation(
            Vector3(0, h / 2 + 0.6, tower.depth / 2 + 0.05),
          ),
      );
      // Every fourth tower carries a big screen on its district-facing
      // face: the hi-rises behind Times Square are where the screens are.
      if (i % 4 == 1 && world.anomalies.isNotEmpty) {
        final sw = w * 0.82;
        final sh = sw * 0.5;
        final sy = h * 0.55;
        final rank = (i ~/ 4) % world.anomalies.length;
        _towerScreen(
          node,
          width: sw,
          height: sh,
          y: sy - h / 2,
          front: tower.depth / 2,
          frame: PlazaStyle.lantern(world.anomalies[rank].lantern),
          glowMargin: 6,
          glowAlpha: 0.25,
          rank: rank,
        );
      }
      // Two windowed faces toward the district, tiled from one offset.
      _windowedBox(
        node,
        id: id,
        w: w,
        d: tower.depth,
        height: h,
        faces: const [_Face.front, _Face.left],
        state: LanternState.off,
        tint: PlazaSceneController._tower,
        perFaceOffset: false,
      );
      scene.add(node);
    }
  }
}
