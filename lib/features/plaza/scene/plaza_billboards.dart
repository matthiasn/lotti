part of 'plaza_scene.dart';

/// Builds this fixture family using the scene's shared resources.
extension _PlazaBillboardsBuilder on PlazaSceneController {
  /// Points around a panel's frame, world space, for the chase lights:
  /// evenly along the perimeter.
  List<Vector3> _frameCorners(BillboardSlot slot) {
    const perSide = 5;
    final sinF = math.sin(slot.facingRadians);
    final cosF = math.cos(slot.facingRadians);
    final hw = slot.width / 2 + 0.18;
    final hh = slot.height / 2 + 0.18;
    Vector3 at(double u, double v) => Vector3(
      slot.x + cosF * u + sinF * 0.2,
      slot.centerY + v,
      slot.z - sinF * u + cosF * 0.2,
    );
    final points = <Vector3>[];
    for (var i = 0; i < perSide; i++) {
      final t = -1 + 2 * (i + 0.5) / perSide;
      points
        ..add(at(t * hw, hh))
        ..add(at(hw, -t * hh))
        ..add(at(-t * hw, -hh))
        ..add(at(-hw, t * hh));
    }
    // Order them clockwise around the frame so the chase runs round.
    final cx = slot.x;
    final cz = slot.z;
    points.sort((a, b) {
      double angle(Vector3 v) {
        final u = (v.x - cx) * cosF - (v.z - cz) * sinF;
        return math.atan2(v.y - slot.centerY, u);
      }

      return angle(a).compareTo(angle(b));
    });
    return points;
  }

  void _buildBillboard(BillboardSlot slot, TaskAttention attention) {
    final root = Node(
      localTransform: Matrix4.translation(Vector3(slot.x, 0, slot.z))
        ..rotateY(slot.facingRadians),
    );
    final frame = PlazaStyle.lantern(attention.lantern);
    if (slot.mount == BillboardMount.roof) {
      // Two short struts on the roof.
      for (final side in [-1.0, 1.0]) {
        _box(
          root,
          Vector3(side * slot.width * 0.4, slot.bottom - 0.25, -0.3),
          Vector3(0.25, 0.5, 0.25),
          PlazaSceneController._postMaterial,
        );
      }
    }
    if (slot.onPylon) {
      // Heavy steel: two braced posts on footings, a catwalk under the
      // panel.
      for (final side in [-1.0, 1.0]) {
        final px = side * slot.width * pylonPostSpread;
        _box(
          root,
          Vector3(px, slot.bottom / 2, -pylonPostSetback),
          Vector3(pylonPostSize, slot.bottom, pylonPostSize),
          PlazaSceneController._postMaterial,
        );
        _box(
          root,
          Vector3(px, 0.3, -pylonPostSetback),
          Vector3(pylonFootingSize, 0.6, pylonFootingSize),
          PlazaSceneController._postMaterial,
        );
      }
      _box(
        root,
        Vector3(0, slot.bottom * 0.55, -0.6),
        Vector3(slot.width * 0.8, 0.25, 0.25),
        PlazaSceneController._postMaterial,
      );
      _box(
        root,
        Vector3(0, slot.bottom - 0.3, 0.5),
        Vector3(slot.width + 0.8, 0.12, 1.2),
        PlazaSceneController._postMaterial,
      );
      // Light pool on the ground in the state colour, and a wide faint
      // wash in front of it so the panel connects to the paving.
      final sinF = math.sin(slot.facingRadians);
      final cosF = math.cos(slot.facingRadians);
      _addPool(
        Vector3(slot.x + sinF * 2.5, 0, slot.z + cosF * 2.5),
        radius: math.max(slot.width, 8) * 0.45,
        color: frame,
        alpha: 0.34,
      );
      _addPool(
        Vector3(
          slot.x + sinF * slot.width * 0.5,
          0,
          slot.z + cosF * slot.width * 0.5,
        ),
        radius: slot.width * 1.5,
        color: frame,
        alpha: 0.07,
      );
      // The panel's reflection: a streak on the paving toward the walker.
      _addWash(
        Vector3(slot.x + sinF * 1.2, 0, slot.z + cosF * 1.2),
        width: slot.width * 0.8,
        length: slot.height * 1.6,
        yaw: slot.facingRadians,
        color: frame,
        alpha: 0.09,
      );
    }
    // Backing box: a real lightbox with depth, dark body and a rim in the
    // state colour at its front edge, so the billboard reads from the
    // skyline before its widget surface exists and the chase lights have a
    // bezel to sit on.
    final depth = slot.mount == BillboardMount.roof ? 0.4 : 0.7;
    final backing = _box(
      root,
      Vector3(0, slot.centerY, -depth / 2 - 0.02),
      Vector3(slot.width + 0.5, slot.height + 0.5, depth),
      PlazaSceneController._towerMaterial,
    );
    // A pylon's or a roof panel's back is open to the street: the same
    // capture shows through, mirrored ([backQuad] keeps the front's UVs
    // and faces the other way, so the eye reads them backwards) and
    // dimmed, inside the box's rim.
    UnlitMaterial? back;
    if (slot.mount != BillboardMount.wall) {
      back = UnlitMaterial()
        ..baseColorFactor = Vector4(
          PlazaBillboard.backTint,
          PlazaBillboard.backTint,
          PlazaBillboard.backTint,
          1,
        )
        ..alphaMode = AlphaMode.opaque;
      root.add(
        Node(
          localTransform: Matrix4.translation(
            Vector3(0, slot.centerY, -depth - 0.03),
          ),
          mesh: Mesh(backQuad(slot.width, slot.height), back),
        ),
      );
    }
    // Faux bloom: a wide soft glow behind the lightbox. Not a pool: the
    // surfaces breathe it and fade it with [poolFade] themselves.
    final glow = UnlitMaterial()
      ..baseColorFactor = linearColor(frame, alpha: PlazaBillboard.glowAlpha)
      ..alphaMode = AlphaMode.blend;
    root.add(
      Node(
        localTransform: Matrix4.translation(
          Vector3(0, slot.centerY, -depth - 0.06),
        ),
        mesh: Mesh(ccwQuad(slot.width + 3, slot.height + 3), glow),
      ),
    );
    // The panel's own border is the one frame; the lightbox bezel and the
    // chase lights sit behind it.
    final anchor = Node(
      localTransform: Matrix4.translation(Vector3(0, slot.centerY, 0.06)),
    );
    root.add(anchor);
    scene.add(root);
    final billboard = PlazaBillboard(
      slot: slot,
      attention: attention,
      backing: backing,
      anchor: anchor,
      glow: glow,
      back: back,
    );
    bindings.billboards.add(billboard);
    bindings.pickableBillboards[backing] = billboard;
    bindings.chaseLightPoints[billboard] = _frameCorners(slot);
  }

  /// A big screen on a tower's district-facing wall under [parent]: a
  /// [width] × [height] backing in the [frame] colour at [y], standing
  /// [front] out from the parent's centre, a glow [glowMargin] wider
  /// behind it at [glowAlpha], and the anchor the widget for anomaly
  /// [rank] hangs on, appended to [skylineScreens].
  void _towerScreen(
    Node parent, {
    required double width,
    required double height,
    required double y,
    required double front,
    required Color frame,
    required double glowMargin,
    required double glowAlpha,
    required int rank,
  }) {
    _box(
      parent,
      Vector3(0, y, front + 0.3),
      Vector3(width + 0.8, height + 0.8, 0.6),
      _boxes.solid(linearColor(frame)),
    );
    parent.add(
      _glowQuad(width + glowMargin, height + glowMargin, frame, glowAlpha)
        ..localTransform = Matrix4.translation(Vector3(0, y, front + 0.2)),
    );
    final anchor = Node(
      localTransform: Matrix4.translation(Vector3(0, y, front + 0.66)),
    );
    parent.add(anchor);
    bindings.skylineScreens.add((anchor, width, height, rank));
  }
}
