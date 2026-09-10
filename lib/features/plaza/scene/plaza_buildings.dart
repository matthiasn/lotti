part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaBuildingsBuilder on PlazaSceneController {
  void _buildBuilding(PlazaTask task, PlotPlacement placement) {
    final attention = world.attentionOf(task);
    final w = placement.width;
    final h = placement.height;
    final architecture = world.architectureByTaskId[task.id]!;
    final d = placement.depth;
    const setback = 0.0;
    final facing = placement.facingRadians;
    final normal = Vector3(math.sin(facing), 0, math.cos(facing));
    // Keep the original plot frame for picking and widget surfaces. Separate
    // volumes reveal the setbacks; no full-height cuboid fills them back in.
    final node = Node(
      name: '${architecture.family.name}-${task.id}',
      localTransform: Matrix4.translation(
        Vector3(placement.x, h / 2, placement.z),
      )..rotateY(facing),
    );
    final parade = stableIndex(task.id, 'parade', WallTextures.paradeVariants);
    final kit = stableIndex(task.id, 'kit', WallTextures.tileFamilies);
    final wallTint = linearColor(palette.categoryWall(task));
    final stone = _boxes.solid(wallTint);
    final cornice = _boxes.solid(linearColor(palette.surfaces.cornice));
    final structure = PlazaArchitecture(_boxes).build(
      architecture,
      wall: stone,
      trim: cornice,
      light: _boxes.solid(linearColor(palette.taskColor(attention))),
      onVolume: (tier, volume, {required groundFloor}) {
        if (!_shown('walls')) return;
        _windowedBox(
          tier,
          id: '${task.id}-${volume.bottom}',
          w: volume.width,
          d: volume.depth,
          height: volume.height,
          state: attention.lantern,
          groundFloor: groundFloor,
          tint: wallTint,
          variant: parade,
          family: kit,
        );
      },
    )..localTransform = Matrix4.translation(Vector3(0, -h / 2, 0));
    node.add(structure);
    _addShadow(
      Vector3(placement.x, 0, placement.z),
      width: w,
      depth: d,
      height: h,
    );
    _box(
      node,
      Vector3(0, -h / 2 + 0.02, 0),
      Vector3(w + 3, 0.04, d + 3),
      _pavementMaterial,
    );
    // A canopy shadows the recessed entrances without entering the street.
    _box(
      node,
      Vector3(0, architecture.entranceHeight - h / 2, d / 2 - 0.4),
      Vector3(w, 0.25, 0.8),
      cornice,
    );

    // An alarmed building spills its state colour onto the ground round
    // every wall: the coral or amber under the doors is what a walker
    // sees first.
    final alarm =
        attention.lantern == LanternState.blocked ||
        attention.lantern == LanternState.overdue;
    if (alarm) {
      final spill = palette.taskColor(attention);
      final sinF = math.sin(facing);
      final cosF = math.cos(facing);
      final cx = placement.x + normal.x * setback;
      final cz = placement.z + normal.z * setback;
      for (final (lx, lz, r) in [
        (0.0, d / 2 + 1.5, w * 0.45),
        (0.0, -d / 2 - 1.5, w * 0.45),
        (w / 2 + 1.5, 0.0, d * 0.45),
        (-w / 2 - 1.5, 0.0, d * 0.45),
      ]) {
        _addPool(
          Vector3(cx + lx * cosF + lz * sinF, 0, cz - lx * sinF + lz * cosF),
          radius: math.max(r, 3),
          color: spill,
          alpha: 0.14,
        );
      }
    }

    // Contact band: a dark plinth so the box sits on the ground.
    _box(
      node,
      Vector3(0, -h / 2 + 0.35, 0),
      Vector3(w + 0.1, 0.7, d + 0.1),
      _boxes.solid(linearColor(palette.surfaces.plotBase)),
    );

    final facadeW = architecture.facadeWidth;
    final facadeH = architecture.facadeHeight;
    final panelY = architecture.facadeCenterY - h / 2;

    // Far-tier surface: an always-present dark plate; the lantern carries
    // the state colour, the plate only says "there is a facade here".
    // The plate, the neon glows and the widget surface stand 1–3 cm apart
    // along the wall's normal, which the depth buffer cannot separate a
    // few hundred metres out; each layer is biased toward the eye a
    // little more than the one behind it (`Material.depthBias`), so a
    // facade never flickers between its layers during a flight.
    final plate = _box(
      node,
      Vector3(0, panelY, architecture.front + 0.03),
      Vector3(facadeW, facadeH, 0.02),
      _boxes.solid(
        PlazaSceneController._panelBack,
        depthBias: PlazaSceneController.plateDepthBias,
      ),
    );

    // Progress light bar along the base, visible at every tier.
    final pct = task.state == PlazaTaskState.done
        ? 1.0
        : task.checklistItems > 0
        ? task.progress
        : task.state == PlazaTaskState.inProgress
        ? 0.35
        : 0.0;
    // On the plinth, not the panel: a full-width track that reads against
    // the dark band, filled from the left, so the lit part is progress
    // along something rather than an orphan block on the wall.
    final plinthY = -h / 2 + 0.35;
    _box(
      node,
      Vector3(0, plinthY, architecture.front + 0.1),
      Vector3(facadeW, 0.28, 0.1),
      _boxes.solid(
        linearColor(
          Color.lerp(PlazaStyle.panel, PlazaStyle.textDim, 0.25)!,
        ),
      ),
    );
    // Seen from the street a +Z face's +X is the viewer's left (the
    // widget quads map their texture left edge to +X), so the bar fills
    // from +X toward -X: left to right for the walker.
    if (pct > 0) {
      _box(
        node,
        Vector3(
          facadeW / 2 - facadeW * pct / 2,
          plinthY,
          architecture.front + 0.12,
        ),
        Vector3(facadeW * pct, 0.28, 0.12),
        _boxes.solid(linearColor(palette.taskColor(attention))),
      );
    }
    // Quarter ticks so the bar has a scale.
    for (final q in [0.25, 0.5, 0.75]) {
      _box(
        node,
        Vector3(facadeW / 2 - facadeW * q, plinthY, architecture.front + 0.16),
        Vector3(0.06, 0.28, 0.04),
        _boxes.solid(linearColor(palette.surfaces.plotRim)),
      );
    }

    // Neon edge strips in the category's neon: two verticals and the
    // roofline, the Blade Runner outline that reads at every range.
    // Emissive level follows state: a finished shop is dark, an open one
    // glows, an anomaly burns; the category neon stays a secondary
    // register under the state colour. Each strip gets a soft glow quad
    // behind it — the faux bloom.
    final emissive = switch (attention.lantern) {
      LanternState.off => 0.22,
      LanternState.open => 0.7,
      _ => 1.0,
    };
    final categoryNeon = PlazaStyle.neon(PlazaStyle.categoryBright(task));
    final neonColor = Color.lerp(
      palette.surfaces.unlitNeon,
      categoryNeon,
      emissive,
    )!;
    // One colour rule: on an anomaly the state owns the brightest register
    // (the two verticals and their glow burn in the lantern colour); the
    // category survives on the roofline at half power.
    final stateNeon = palette.taskColor(attention);
    // Lit neon goes past white so the bloom pass carries it; a dark shop's
    // strips stay under the threshold.
    final boost = emissive >= 0.7 ? neonBoost : 1.0;
    final vertical = UnlitMaterial()
      ..baseColorFactor = emissiveColor(alarm ? stateNeon : neonColor, boost);
    final roofline = UnlitMaterial()
      ..baseColorFactor = emissiveColor(
        alarm
            ? Color.lerp(palette.surfaces.unlitNeon, categoryNeon, 0.5)!
            : neonColor,
        boost,
      );
    // The strips and their glow live in one group, hidden while the
    // focus ring is up: one frame per facade at a time.
    final neon = Node();
    node.add(neon);
    const strip = 0.2;
    for (final (dx, dy, sw, sh, isRoofline) in [
      (-facadeW / 2 - 0.12, 0.0, strip, facadeH, false),
      (facadeW / 2 + 0.12, 0.0, strip, facadeH, false),
      (0.0, facadeH / 2 + 0.12, facadeW + 0.4, strip, true),
    ]) {
      _box(
        neon,
        Vector3(dx, dy + panelY, d / 2 + 0.05),
        Vector3(sw, sh, strip),
        isRoofline ? roofline : vertical,
      );
      if (emissive > 0.3) {
        neon.add(
          _glowQuad(
              sw + 1.1,
              sh + 1.1,
              alarm && !isRoofline ? stateNeon : categoryNeon,
              (alarm && isRoofline ? 0.08 : 0.16) * emissive,
              depthBias: PlazaSceneController.glowDepthBias,
            )
            ..localTransform = Matrix4.translation(
              Vector3(dx, dy + panelY, d / 2 + 0.04),
            ),
        );
      }
    }
    // What the lit facade throws on the street: a warm strip under a
    // trading parade, a streak of the state colour on an alarm.
    final trading = attention.lantern == LanternState.inProgress;
    if (trading || alarm) {
      _addWash(
        Vector3(
          placement.x + normal.x * (d / 2 + setback),
          0,
          placement.z + normal.z * (d / 2 + setback),
        ),
        width: facadeW * (alarm ? 0.8 : 1),
        length: alarm ? facadeH * 1.2 : 3,
        yaw: facing,
        color: alarm ? stateNeon : palette.lights.parade,
        alpha: alarm ? 0.09 : 0.07,
      );
    }
    // The topmost crown is also the map's status tile. Its entire roof reads
    // green for done, red for blocked, and amber for overdue; the lantern
    // remains above it and supplies a second, screen-sized status cue.
    final crown = architecture.volumes.last;
    final statusRoof = _boxes.solid(
      linearColor(palette.taskColor(attention)),
    );
    _box(
      node,
      Vector3(crown.x, h / 2 + 0.02, crown.z),
      Vector3(crown.width, 0.04, crown.depth),
      statusRoof,
    );
    // Light pool on the street in front of a lit facade: the wet-street
    // reflection, without a reflection. Sits above the pavement so it
    // never fights the slab.
    if (attention.lantern != LanternState.off) {
      _addPool(
        Vector3(
          placement.x + normal.x * (placement.depth / 2 + facadeW * 0.3),
          0,
          placement.z + normal.z * (placement.depth / 2 + facadeW * 0.3),
        ),
        radius: facadeW * 0.55,
        color: palette.taskColor(attention),
        alpha: attention.lantern == LanternState.open ? 0.13 : 0.26,
      );
    }

    // Focus ring: four teal slats just outside the facade, hidden until
    // the walker faces this building.
    final ring = Node(
      localTransform: Matrix4.translation(
        Vector3(0, panelY, architecture.front + 0.07),
      ),
    )..visible = false;
    // The ring burns in the state's own colour: the faced building keeps
    // the far-tier colour language on arrival.
    final ringMaterial = UnlitMaterial()
      ..baseColorFactor = emissiveColor(
        palette.taskColor(attention),
        neonBoost,
      )
      ..depthBias = PlazaSceneController.glowDepthBias;
    const t = 0.12;
    const off = 0.25;
    for (final (dx, dy, sw, sh) in [
      (0.0, facadeH / 2 + off, facadeW + 2 * off + t, t),
      (0.0, -facadeH / 2 - off, facadeW + 2 * off + t, t),
      (-facadeW / 2 - off, 0.0, t, facadeH + 2 * off),
      (facadeW / 2 + off, 0.0, t, facadeH + 2 * off),
    ]) {
      _box(ring, Vector3(dx, dy, 0), Vector3(sw, sh, t), ringMaterial);
    }
    node.add(ring);

    // Anchor for the live/sign widget surface, in front of the plate.
    final facadeAnchor = Node(
      localTransform: Matrix4.translation(
        Vector3(0, panelY, architecture.front + 0.1),
      ),
    );
    node.add(facadeAnchor);

    final lanternAnchor = Node(
      localTransform: Matrix4.translation(Vector3(0, h / 2 + 0.7, 0)),
    );
    node.add(lanternAnchor);

    scene.add(node);

    final building = PlazaBuilding(
      task: task,
      attention: attention,
      placement: placement,
      node: node,
      facadeAnchor: facadeAnchor,
      ring: ring,
      neon: neon,
      lanternAnchor: lanternAnchor,
      facadeCenter: Vector3(
        placement.x + normal.x * (d / 2),
        h / 2 + panelY,
        placement.z + normal.z * (d / 2),
      ),
      facadeNormal: normal,
      facadeWorldWidth: facadeW,
      facadeWorldHeight: facadeH,
      liveRange: taskStandOffFor(placement) + 2,
      pxPerMeter: pxPerMeter,
    );
    bindings.buildings.add(building);
    bindings.pickableBuildings[plate] = building;
  }

  void _buildEmptyLot(PlotPlacement placement) {
    // Fenced empty lot: foundations visible, street never closes up.
    scene.add(
      _boxes.node(
        Vector3(placement.width, 0.5, placement.depth),
        _boxes.solid(linearColor(palette.surfaces.riser)),
        transform: Matrix4.translation(
          Vector3(placement.x, 0.25, placement.z),
        )..rotateY(placement.facingRadians),
      ),
    );
  }
}
