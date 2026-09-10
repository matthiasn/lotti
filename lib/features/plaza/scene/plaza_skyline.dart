part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaSkylineBuilder on PlazaSceneController {
  void _buildSky() {
    final sky = palette.sky;
    final air = palette.air;
    final sun = sky.sunDirection;
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: linearColor(sky.zenith).xyz,
        horizonColor: linearColor(sky.horizon).xyz,
        groundColor: linearColor(sky.ground).xyz,
        // The disk's HDR value: hue times intensity, so a daylight sun sits
        // well past white and blooms while night's stays at zero.
        sunColor: linearColor(sky.sun).xyz * sky.sunIntensity,
        sunDirection: Vector3(sun.x, sun.y, sun.z),
        sunSharpness: sky.sunSharpness,
      ),
    );
    // Ground-hugging haze in the horizon's own colour: the street dissolves
    // into the sky instead of hitting a seam, and it thins with altitude
    // so the overview still sees the district. At night the haze is a
    // desaturated indigo so amber signage sits warm against it; by day it
    // is the sky's own pale blue, and distance reads as aerial perspective
    // rather than as a wall two blocks out.
    //
    // Bloom is real: at night the emitters (neon, screens, chase heads,
    // rooflines) bleed into the dark the way a lightbox does, and a soft
    // vignette pulls the eye to the centre of every frame. Daylight raises
    // the threshold above the sky's own brightness — only the sun disk is
    // left to bloom — and drops the vignette, which would read as a dirty
    // lens rather than as night closing in.
    scene.postProcess.bloom
      ..enabled = air.hasBloom
      ..threshold = air.bloomThreshold
      ..intensity = air.bloomIntensity
      ..scatter = air.bloomScatter;
    scene.postProcess.vignette
      ..enabled = air.hasVignette
      ..intensity = air.vignetteIntensity
      ..radius = air.vignetteRadius
      ..smoothness = air.vignetteSmoothness;
    scene.fog
      ..enabled = true
      ..mode = FogMode.exponential
      ..density = air.fogDensityLow
      ..start = 8
      ..height = 0
      ..heightFalloff = 0.028
      ..maxOpacity = air.fogOpacityLow
      // Between the ground and the horizon: the haze never outshines the
      // paving the walker stands on.
      ..color = linearColor(air.fog).xyz;
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
      final node =
          _sceneryArchitecture(
              block,
              state: LanternState.open,
              light: PlazaStyle.lamp,
              detailed: false,
            )
            ..localTransform = (Matrix4.translation(
              Vector3(block.x, 0, block.z),
            )..rotateY(block.yawRadians));
      _addShadow(
        Vector3(block.x, 0, block.z),
        width: bw,
        depth: bd,
        height: bh,
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
          color: palette.lights.parade,
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
              Vector3(-side * (bd / 2 + 0.08), bh * 0.65, -bw / 2 + 1.2),
            )..rotateY(side < 0 ? math.pi / 2 : -math.pi / 2),
          );
          node.add(anchor);
          bindings.fillerSigns.add((anchor, 1.6, bh * 0.6, weekTasks[pick]));
        }
      }
      _cityContext.add(node);
    }
  }

  /// One hero tower past the far end of every row that folds
  /// (`Scenery.heroTowers`), on the row's axis, with a screen toward the
  /// street and a warm light dome behind it: the horizon a walker walks
  /// toward. The last row's far end has the jumbotron instead.
  void _buildHeroTowers() {
    for (final tower in world.scenery.heroTowers) {
      final w = tower.width;
      final bd = tower.depth;
      final height = tower.height;
      // The root faces back down the row.
      final root =
          Node(
            localTransform: Matrix4.translation(Vector3(tower.x, 0, tower.z))
              ..rotateY(tower.yawRadians),
          )..add(
            _sceneryArchitecture(
              tower,
              state: LanternState.inProgress,
              light: PlazaStyle.teal,
              landmark: true,
              minimumFrontageHeight: height * 0.62 + w * 0.9 * 0.62 / 2,
            ),
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
        _glowQuad(w * 9, height * 1.4, palette.lights.skyGlow, 0.11)
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
      final i = tower.index;
      final w = tower.width;
      final h = tower.height;
      final node =
          _sceneryArchitecture(
              tower,
              state: LanternState.off,
              light: i.isEven ? PlazaStyle.lamp : PlazaStyle.teal,
              detailed: false,
              shops: false,
              minimumFrontageHeight: math.min(h, h * 0.55 + w * 0.82 * 0.5 / 2),
            )
            ..localTransform = (Matrix4.translation(
              Vector3(tower.x, 0, tower.z),
            )..rotateY(tower.yawRadians));
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
          y: sy,
          front: tower.depth / 2,
          frame: PlazaStyle.lantern(world.anomalies[rank].lantern),
          glowMargin: 6,
          glowAlpha: 0.25,
          rank: rank,
        );
      }
      _cityContext.add(node);
    }
  }

  /// Shared recipes for supporting city fabric and avenue landmarks. A distant
  /// tower keeps its massing and crown with no column grid or shopfront capture.
  Node _sceneryArchitecture(
    SceneryBox box, {
    required LanternState state,
    required Color light,
    bool landmark = false,
    bool detailed = true,
    bool shops = true,
    double minimumFrontageHeight = 0,
  }) {
    final architecture = BuildingArchitecture.forEnvelope(
      id: box.id,
      width: box.width,
      depth: box.depth,
      height: box.height,
      config: world.architecture,
      family: landmark ? BuildingFamily.steppedTower : null,
      minimumFrontageHeight: minimumFrontageHeight,
    );
    final colors = dsTokensDark.colors;
    final glow = landmark
        ? light
        : Color.lerp(colors.background.level02, light, SurfaceAlphas.muted)!;
    final variant = stableIndex(box.id, 'parade', WallTextures.paradeVariants);
    final family = switch (architecture.family) {
      BuildingFamily.mediaTower => 2,
      BuildingFamily.theater => 1,
      BuildingFamily.steppedTower => 0,
    };
    return PlazaArchitecture(_boxes).build(
      architecture,
      wall: _towerMaterial,
      trim: _boxes.solid(
        linearColor(
          landmark ? colors.background.level03 : colors.background.level02,
        ),
      ),
      light: _boxes.solid(
        emissiveColor(glow, landmark ? neonBoost : 1),
      ),
      detailed: detailed,
      onVolume: (tier, volume, {required groundFloor}) {
        _windowedBox(
          tier,
          id: '${box.id}-${volume.bottom}',
          w: volume.width,
          d: volume.depth,
          height: volume.height,
          state: state,
          tint: _tower,
          groundFloor: shops && groundFloor,
          shops: LanternState.inProgress,
          variant: variant,
          family: family,
          faces: shops ? _Face.values : const [_Face.front, _Face.left],
        );
      },
    );
  }
}
