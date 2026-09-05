part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaBuildingsBuilder on PlazaSceneController {
  void _buildBuilding(PlazaTask task, PlotPlacement placement) {
    final attention = world.attentionOf(task);
    final w = placement.width;
    final h = placement.height;
    // Massing: plots vary in depth (hashed, never moving) and the box is
    // anchored to the street side, so the row is not a picket fence.
    final d = placement.depth * (0.78 + 0.32 * stableUnit(task.id, 'depth'));
    final setback = (placement.depth - d) / 2;
    final facing = placement.facingRadians;
    final normal = Vector3(math.sin(facing), 0, math.cos(facing));

    final node = _boxes.node(
      Vector3(w, h, d),
      _boxes.solid(linearColor(PlazaStyle.categoryWall(task))),
      transform: Matrix4.translation(
        Vector3(
          placement.x + normal.x * setback,
          h / 2,
          placement.z + normal.z * setback,
        ),
      )..rotateY(facing),
      shaded: true,
    );
    final parade = stableIndex(task.id, 'parade', WallTextures.paradeVariants);
    final kit = stableIndex(task.id, 'kit', WallTextures.tileFamilies);

    // A pavement apron round the plot, so the building stands on a street
    // and not on a speckled void.
    _box(
      node,
      Vector3(0, -h / 2 + 0.02, 0),
      Vector3(w + 3, 0.04, d + 3),
      PlazaSceneController._pavementMaterial,
    );
    // Side and back walls: window grids in the state's lit ratio over
    // the shopfront parade dressed for the state, tiled by the wall's
    // size; a hashed tile offset per wall so each starts at its own shop.
    final wallTint = linearColor(
      Color.lerp(PlazaStyle.categoryWall(task), const Color(0xFF0B0A14), 0.5)!,
    );
    if (_shown('walls')) {
      _windowedBox(
        node,
        id: task.id,
        w: w,
        d: d,
        height: h,
        faces: const [_Face.left, _Face.right, _Face.back],
        state: attention.lantern,
        tint: wallTint,
        variant: parade,
        family: kit,
      );
    }
    // An alarmed building spills its state colour onto the ground round
    // every wall: the coral or amber under the doors is what a walker
    // sees first.
    final alarm =
        attention.lantern == LanternState.blocked ||
        attention.lantern == LanternState.overdue;
    if (alarm) {
      final spill = PlazaStyle.lantern(attention.lantern);
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
      _boxes.solid(linearColor(const Color(0xFF0A0910))),
    );

    // Tall buildings step back to an upper storey with its own roof.
    if (h >= 14) {
      final upperH = h * 0.22;
      node.add(
        _boxes.node(
          Vector3(w * 0.68, upperH, d * 0.7),
          _boxes.solid(linearColor(PlazaStyle.categoryRoof(task))),
          transform: Matrix4.translation(
            Vector3(0, h / 2 + upperH / 2, -d * 0.12),
          ),
          shaded: true,
        ),
      );
    }

    // A tall building's screen hangs above a street-level parade, a
    // storey of windows either side of it, so the wall owns the screen
    // instead of being one; a short one is all sign, as before.
    final hasParade = h >= PlazaSceneController.paradeWallHeight;
    final facadeW = hasParade ? w * 0.8 : w * 0.92;
    final facadeH = hasParade
        ? h - PlazaSceneController.shopfrontHeight - 1
        : h * 0.9;
    final panelY = hasParade
        ? (PlazaSceneController.shopfrontHeight + 0.4 - 0.6) / 2
        : 0.0;
    if (hasParade) {
      _windowedWall(
        node,
        dx: 0,
        dz: d / 2 + 0.015,
        yaw: 0,
        width: w,
        height: h,
        state: attention.lantern,
        tint: wallTint,
        uOffset: stableUnit(task.id, 'tilefront') * 3,
        variant: stableIndex(
          task.id,
          'paradefront',
          WallTextures.paradeVariants,
        ),
        family: kit,
      );
    }

    // Roof: a darker slab so the top reads apart from the walls.
    _box(
      node,
      Vector3(0, h / 2 + 0.02, 0),
      Vector3(w + 0.04, 0.04, d + 0.04),
      _boxes.solid(
        linearColor(
          Color.lerp(
            PlazaStyle.categoryRoof(task),
            const Color(0xFF07060D),
            0.5,
          )!,
        ),
      ),
    );
    // Far-tier surface: an always-present dark plate; the lantern carries
    // the state colour, the plate only says "there is a facade here".
    // The plate, the neon glows and the widget surface stand 1–3 cm apart
    // along the wall's normal, which the depth buffer cannot separate a
    // few hundred metres out; each layer is biased toward the eye a
    // little more than the one behind it (`Material.depthBias`), so a
    // facade never flickers between its layers during a flight.
    final plate = _box(
      node,
      Vector3(0, panelY, d / 2 + 0.03),
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
      Vector3(0, plinthY, d / 2 + 0.1),
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
        Vector3(facadeW / 2 - facadeW * pct / 2, plinthY, d / 2 + 0.12),
        Vector3(facadeW * pct, 0.28, 0.12),
        _boxes.solid(linearColor(PlazaStyle.lightBar(attention))),
      );
    }
    // Quarter ticks so the bar has a scale.
    for (final q in [0.25, 0.5, 0.75]) {
      _box(
        node,
        Vector3(facadeW / 2 - facadeW * q, plinthY, d / 2 + 0.16),
        Vector3(0.06, 0.28, 0.04),
        _boxes.solid(linearColor(const Color(0xFF07060D))),
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
      const Color(0xFF0B0A14),
      categoryNeon,
      emissive,
    )!;
    // One colour rule: on an anomaly the state owns the brightest register
    // (the two verticals and their glow burn in the lantern colour); the
    // category survives on the roofline at half power.
    final stateNeon = PlazaStyle.lantern(attention.lantern);
    // Lit neon goes past white so the bloom pass carries it; a dark shop's
    // strips stay under the threshold.
    final boost = emissive >= 0.7 ? PlazaSceneController.neonBoost : 1.0;
    final vertical = UnlitMaterial()
      ..baseColorFactor = emissiveColor(alarm ? stateNeon : neonColor, boost);
    final roofline = UnlitMaterial()
      ..baseColorFactor = emissiveColor(
        alarm
            ? Color.lerp(const Color(0xFF0B0A14), categoryNeon, 0.5)!
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
        color: alarm ? stateNeon : const Color(0xFFFFC46B),
        alpha: alarm ? 0.09 : 0.07,
      );
    }
    // Roof outline: the top edge lit dimly on all four sides so height
    // reads from above.
    final roofTrim = UnlitMaterial()
      ..baseColorFactor = linearColor(
        Color.lerp(const Color(0xFF0B0A14), neonColor, 0.55)!,
      );
    _rim(
      node,
      w: w,
      d: d,
      y: h / 2 + 0.08,
      overhang: 0.2,
      thickness: 0.14,
      material: roofTrim,
    );
    _addRoofKit(node, task, w, h, d);
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
        color: PlazaStyle.lantern(attention.lantern),
        alpha: attention.lantern == LanternState.open ? 0.13 : 0.26,
      );
    }

    // Focus ring: four teal slats just outside the facade, hidden until
    // the walker faces this building.
    final ring = Node(
      localTransform: Matrix4.translation(Vector3(0, panelY, d / 2 + 0.07)),
    )..visible = false;
    // The ring burns in the state's own colour: the faced building keeps
    // the far-tier colour language on arrival.
    final ringMaterial = UnlitMaterial()
      ..baseColorFactor = emissiveColor(
        PlazaStyle.lantern(attention.lantern),
        PlazaSceneController.neonBoost,
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
      localTransform: Matrix4.translation(Vector3(0, panelY, d / 2 + 0.1)),
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
        _boxes.solid(linearColor(const Color(0xFF14161C))),
        transform: Matrix4.translation(
          Vector3(placement.x, 0.25, placement.z),
        )..rotateY(placement.facingRadians),
      ),
    );
  }

  /// Seeded roof clutter: a parapet lip, one or two plant boxes, a water
  /// tank on some, an antenna mast on a third. Hashed from the task id so
  /// it never changes under the user's feet.
  void _addRoofKit(Node node, PlazaTask task, double w, double h, double d) {
    final dark = UnlitMaterial()
      ..baseColorFactor = linearColor(const Color(0xFF14121E));
    final top = h / 2;
    // Parapet lip.
    _rim(
      node,
      w: w,
      d: d,
      y: top + 0.25,
      inset: 0.15,
      thickness: 0.3,
      height: 0.5,
      material: dark,
    );
    final plantCount = 1 + (stableUnit(task.id, 'plant') < 0.5 ? 1 : 0);
    for (var i = 0; i < plantCount; i++) {
      final bw = math.min(w * 0.3, 2.4);
      final bd = math.min<double>(d * 0.3, 2);
      final bx = (stableUnit(task.id, 'px$i') - 0.5) * (w - bw - 1);
      final bz = (stableUnit(task.id, 'pz$i') - 0.5) * (d - bd - 1);
      _box(node, Vector3(bx, top + 0.7, bz), Vector3(bw, 1.4, bd), dark);
    }
    if (stableUnit(task.id, 'tank') < 0.4 && w > 5) {
      final tx = (stableUnit(task.id, 'tx') - 0.5) * (w - 3);
      final tz = (stableUnit(task.id, 'tz') - 0.5) * (d - 3);
      node.add(
        Node(
          localTransform: Matrix4.translation(Vector3(tx, top + 1.5, tz)),
          mesh: Mesh(
            CylinderGeometry(
              bottomRadius: 0.9,
              topRadius: 0.9,
              height: 2.2,
              radialSegments: 8,
            ),
            dark,
          ),
        ),
      );
    }
    if (stableUnit(task.id, 'mast') < 0.33) {
      final mx = (stableUnit(task.id, 'mx') - 0.5) * (w - 1);
      _box(
        node,
        Vector3(mx, top + roofKitHeight / 2, 0),
        Vector3(0.12, roofKitHeight, 0.12),
        dark,
      );
    }
  }
}
