import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/rig_spec.dart';
import 'package:lotti/features/character/runtime/limb_ribbon.dart';

/// Draws a posed [RigSpec] onto a [Canvas]. Stateless and Flutter-only at the
/// `dart:ui` level — shared by the live [CustomPainter] and the offline
/// film-strip renderer so what you review is exactly what ships.
///
/// Phase 1 draws each bone as a vector shape (capsule/ellipse/rounded rect);
/// the planned low-end runtime swaps these for a single batched `drawAtlas`,
/// but the geometry, transforms and face are identical.
class CharacterRenderer {
  CharacterRenderer({this.antiAlias = true});

  final bool antiAlias;

  // Reused per-bone matrix storage and paint to keep the hot path allocation-
  // light (the plan's §6.1). `Canvas.draw*` reads the paint synchronously, so a
  // single mutated instance is safe to share across the bone passes.
  final Float64List _matrix = Float64List(16);
  final Paint _paint = Paint();

  /// Paints [rig] using precomputed [world] transforms and a [face] state.
  ///
  /// Bones are drawn in two passes so overlapping pieces read as one body
  /// instead of a stack of separately-outlined parts:
  ///
  /// 1. **Silhouette** — every outlined bone is painted as a slightly inflated
  ///    shape in the outline colour. Because they all share one colour, the
  ///    overlapping pieces union into a single continuous dark blob, so no
  ///    outline ever crosses *into* the body at a joint.
  /// 2. **Fill** — the bone fills are painted in z-order on top, covering the
  ///    interior of that blob and leaving only its outer rim showing. The
  ///    result is a clean outer outline with seam-free joints.
  void paint(
    Canvas canvas,
    RigSpec rig,
    Map<String, Affine2D> world,
    FaceState face,
  ) {
    final hiddenBones = rig.hiddenDrawableBoneIds;

    // Ribbons are drawn in the same silhouette/fill two-pass style as bones.
    // They replace selected rigid upper/lower limb drawables with one continuous
    // surface, so elbows and knees bend through a curve instead of hinging like
    // separate cardboard pieces.
    for (final ribbon in rig.ribbonDrawOrder) {
      final outline = ribbon.outlineColor;
      if (outline == null || ribbon.outlineWidth <= 0) continue;
      _drawRibbonSilhouette(canvas, ribbon, world, outline);
    }
    for (final mesh in rig.meshDrawOrder) {
      final outline = mesh.outlineColor;
      if (outline == null || mesh.outlineWidth <= 0) continue;
      _drawMeshSilhouette(canvas, mesh, world, outline);
    }

    // Pass 1: the unified dark silhouette (outer outline, no internal seams).
    for (final bone in rig.drawOrder) {
      if (hiddenBones.contains(bone.id)) continue;
      final drawable = bone.drawable;
      if (drawable == null) continue;
      final outline = drawable.outlineColor;
      if (outline == null || drawable.outlineWidth <= 0) continue;
      final transform = world[bone.id];
      if (transform == null) continue;
      canvas
        ..save()
        ..transform(transform.toMatrix4Storage(_matrix));
      _drawSilhouette(canvas, drawable, outline);
      canvas.restore();
    }

    // Pass 2: ribbons + bone fills, painted back-to-front over the silhouette.
    _drawFills(canvas, rig, world, hiddenBones);

    final faceRig = rig.face;
    if (faceRig != null) {
      final headWorld = world[faceRig.anchorBoneId];
      if (headWorld != null) {
        canvas
          ..save()
          ..transform(headWorld.toMatrix4Storage(_matrix));
        _drawFace(canvas, faceRig, face);
        canvas.restore();
      }
    }
  }

  void _drawFills(
    Canvas canvas,
    RigSpec rig,
    Map<String, Affine2D> world,
    Set<String> hiddenBones,
  ) {
    final ribbons = rig.ribbonDrawOrder;
    final meshes = rig.meshDrawOrder;
    final celShade = rig.celShade;
    var ribbonIndex = 0;
    var meshIndex = 0;
    for (final bone in rig.drawOrder) {
      while (ribbonIndex < ribbons.length && ribbons[ribbonIndex].z <= bone.z) {
        _drawRibbonFill(canvas, ribbons[ribbonIndex], world);
        if (celShade != null) {
          _celShadeRibbon(canvas, ribbons[ribbonIndex], world, celShade);
        }
        ribbonIndex++;
      }
      while (meshIndex < meshes.length && meshes[meshIndex].z <= bone.z) {
        _drawMeshFill(canvas, meshes[meshIndex], world);
        if (celShade != null) {
          _celShadeMesh(canvas, meshes[meshIndex], world, celShade);
        }
        meshIndex++;
      }
      if (hiddenBones.contains(bone.id)) continue;
      final drawable = bone.drawable;
      if (drawable == null) continue;
      final transform = world[bone.id];
      if (transform == null) continue;
      canvas
        ..save()
        ..transform(transform.toMatrix4Storage(_matrix));
      _drawFill(canvas, drawable);
      if (celShade != null && drawable.celShade) {
        _celShadeKind(canvas, drawable, celShade);
      }
      canvas.restore();
    }
    while (ribbonIndex < ribbons.length) {
      _drawRibbonFill(canvas, ribbons[ribbonIndex], world);
      if (celShade != null) {
        _celShadeRibbon(canvas, ribbons[ribbonIndex], world, celShade);
      }
      ribbonIndex++;
    }
    while (meshIndex < meshes.length) {
      _drawMeshFill(canvas, meshes[meshIndex], world);
      if (celShade != null) {
        _celShadeMesh(canvas, meshes[meshIndex], world, celShade);
      }
      meshIndex++;
    }
  }

  // ---- Cel-shading: a per-shape form shadow clipped to each volume ----------

  /// Blends [baseArgb]'s RGB toward [tint] by [amount], after first scaling the
  /// base by [scale] (used to darken for the shade side; 1 for the highlight).
  Color _celTint(int baseArgb, int tint, double amount, double scale) {
    final a = (baseArgb >> 24) & 0xFF;
    double chan(int shift) {
      final base = (((baseArgb >> shift) & 0xFF) * scale).clamp(0.0, 255.0);
      final t = (tint >> shift) & 0xFF;
      return base + (t - base) * amount;
    }

    return Color.fromARGB(
      a,
      chan(16).round().clamp(0, 255),
      chan(8).round().clamp(0, 255),
      chan(0).round().clamp(0, 255),
    );
  }

  /// A paint whose shader runs, across [rect] along the light axis, from full
  /// **shade** on the side away from the light, through the untouched base in the
  /// middle, to a lifted **highlight** on the lit side — a three-tone cel ramp.
  /// The highlight is what makes the ramp READ on near-black fills (a navy suit
  /// shows no darker shade, but a lifted lit side gives it form). Drawn clipped
  /// to the shape so it models that volume alone.
  Paint _celShadePaint(Rect rect, int baseArgb, CelShadeSpec s) {
    final len = math.sqrt(s.lightDx * s.lightDx + s.lightDy * s.lightDy);
    final dx = len == 0 ? 0.0 : s.lightDx / len;
    final dy = len == 0 ? -1.0 : s.lightDy / len;
    final shade = _celTint(baseArgb, s.coolTint, s.coolAmount, s.shadowFactor);
    final mid = shade.withValues(alpha: 0); // base shows through
    final highlight = _celTint(baseArgb, s.highlightTint, s.highlightAmount, 1);
    final soft = s.softness.clamp(0.0, 0.2);
    // Ascending stops from the shade corner (0) to the lit corner (1).
    final s1 = (s.coverage - soft).clamp(0.0, 1.0);
    final s2 = (s.coverage + soft).clamp(s1, 1.0);
    final hi = (1 - s.highlightCoverage).clamp(0.0, 1.0);
    final s3 = (hi - soft).clamp(s2, 1.0);
    final s4 = (hi + soft).clamp(s3, 1.0);
    return Paint()
      ..isAntiAlias = antiAlias
      ..shader = LinearGradient(
        begin: Alignment(-dx, -dy), // shade side (away from the light)
        end: Alignment(dx, dy), // lit side (toward the light)
        colors: [shade, shade, mid, mid, highlight, highlight],
        stops: [0, s1, s2, s3, s4, 1],
      ).createShader(rect);
  }

  void _celShadeKind(Canvas canvas, BoneDrawable d, CelShadeSpec s) {
    final rect = Rect.fromCenter(
      center: Offset(d.dx, d.dy),
      width: d.width,
      height: d.height,
    );
    canvas.save();
    _clipKind(canvas, d);
    canvas.drawRect(rect, _celShadePaint(rect, d.color, s));
    // Form-rounding is opt-out per shape: the head/neck darken into a detached
    // seam rather than volume, so they keep the flat terminator only.
    final round = d.formRound ? _formRoundPaint(rect, d.color, s) : null;
    if (round != null) canvas.drawRect(rect, round);
    canvas.restore();
  }

  /// The painterly **form-rounding** pass (null when [CelShadeSpec.roundAmount]
  /// is 0): a squashed radial — transparent at the shape's centre, deepening to a
  /// cool occlusion at its contour — drawn (clipped to the shape, on top of the
  /// directional cel ramp) so the volume bulges in the middle and falls into
  /// shadow at its edges. The radial is fitted to the shape's bounding ellipse via
  /// a column-major scale-about-centre matrix, so an elongated limb darkens along
  /// its long edges (rounding the tube) instead of getting a centred circle.
  Paint? _formRoundPaint(Rect rect, int baseArgb, CelShadeSpec s) {
    if (s.roundAmount <= 0 || rect.isEmpty) return null;
    final halfW = rect.width / 2;
    final halfH = rect.height / 2;
    final radius = math.max(halfW, halfH);
    if (radius <= 0) return null;
    final sx = halfW >= halfH ? 1.0 : halfW / halfH;
    final sy = halfH >= halfW ? 1.0 : halfH / halfW;
    final c = rect.center;
    final squash = Float64List(16)
      ..[0] = sx
      ..[5] = sy
      ..[10] = 1
      ..[15] = 1
      ..[12] = c.dx * (1 - sx)
      ..[13] = c.dy * (1 - sy);
    // The occlusion edge is a readable COOL blue-hour fill, NOT a crush to black:
    // the base pulled hard (0.6) toward the cool tint at a moderate (0.62) value
    // floor, so the shadow side of each volume carries plate colour and turns
    // gradually (a film panel's "lift the core shadow off black, wrap the cool
    // ambient in" note) rather than reading as a flat dark hole.
    final edge = _celTint(
      baseArgb,
      s.coolTint,
      0.6,
      0.62,
    ).withValues(alpha: s.roundAmount.clamp(0.0, 1.0));
    final inner = edge.withValues(alpha: 0);
    final start = (1 - s.roundCoverage).clamp(0.0, 1.0);
    return Paint()
      ..isAntiAlias = antiAlias
      ..shader = ui.Gradient.radial(
        c,
        radius,
        [inner, inner, edge],
        [0.0, start, 1.0],
        TileMode.clamp,
        squash,
      );
  }

  /// Clips the canvas to the shape geometry of [d] (so a cel-shade fill stays
  /// inside that volume).
  void _clipKind(Canvas canvas, BoneDrawable d) {
    final rect = Rect.fromCenter(
      center: Offset(d.dx, d.dy),
      width: d.width,
      height: d.height,
    );
    switch (d.kind) {
      case BoneShapeKind.capsule:
        final r = Radius.circular(
          (d.width < d.height ? d.width : d.height) / 2,
        );
        canvas.clipRRect(RRect.fromRectAndRadius(rect, r));
      case BoneShapeKind.ellipse:
        canvas.clipPath(Path()..addOval(rect));
      case BoneShapeKind.roundedRect:
        canvas.clipRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(d.cornerRadius)),
        );
      case BoneShapeKind.triangle:
        canvas.clipPath(_trianglePath(rect));
      case BoneShapeKind.taperedCapsule:
        canvas.clipPath(_taperedCapsulePath(d));
    }
  }

  void _celShadeRibbon(
    Canvas canvas,
    LimbRibbonSpec ribbon,
    Map<String, Affine2D> world,
    CelShadeSpec s,
  ) {
    final path = _ribbonPath(ribbon, world);
    if (path == null) return;
    _celShadePath(canvas, path, ribbon.color, s);
  }

  void _celShadeMesh(
    Canvas canvas,
    SkinnedMeshSpec mesh,
    Map<String, Affine2D> world,
    CelShadeSpec s,
  ) {
    final path = _meshPath(mesh, world);
    if (path == null) return;
    _celShadePath(canvas, path, mesh.color, s, formRound: mesh.formRound);
  }

  /// Cel-shades an arbitrary world-space [path] (ribbon/mesh): clip to it and
  /// paint the form-shadow gradient across its bounds.
  void _celShadePath(
    Canvas canvas,
    Path path,
    int baseArgb,
    CelShadeSpec s, {
    bool formRound = true,
  }) {
    final bounds = path.getBounds();
    if (bounds.isEmpty) return;
    canvas
      ..save()
      ..clipPath(path)
      ..drawRect(bounds, _celShadePaint(bounds, baseArgb, s));
    final round = formRound ? _formRoundPaint(bounds, baseArgb, s) : null;
    if (round != null) canvas.drawRect(bounds, round);
    canvas.restore();
  }

  /// Paints the fill of [d] in its own colour (no per-bone outline — the
  /// silhouette pass owns the outline).
  void _drawFill(Canvas canvas, BoneDrawable d) {
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..color = Color(d.color)
      ..isAntiAlias = antiAlias;
    _drawKind(canvas, d, _paint);
  }

  /// Paints [d] inflated by its `outlineWidth` in [outlineColor], forming part
  /// of the shared body silhouette. A filled shape plus a centred stroke of
  /// twice the outline width grows the shape outward by exactly `outlineWidth`
  /// (the stroke's inner half overlaps the fill), with a round join that softens
  /// triangle corners — no per-shape geometry inflation needed.
  void _drawSilhouette(Canvas canvas, BoneDrawable d, int outlineColor) {
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..color = Color(outlineColor)
      ..isAntiAlias = antiAlias;
    _drawKind(canvas, d, _paint);

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = d.outlineWidth * 2
      ..strokeJoin = StrokeJoin.round
      ..color = Color(outlineColor)
      ..isAntiAlias = antiAlias;
    _drawKind(canvas, d, _paint);
  }

  void _drawRibbonFill(
    Canvas canvas,
    LimbRibbonSpec ribbon,
    Map<String, Affine2D> world,
  ) {
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..color = Color(ribbon.color)
      ..isAntiAlias = antiAlias;
    _drawRibbon(canvas, ribbon, world, _paint);
  }

  void _drawRibbonSilhouette(
    Canvas canvas,
    LimbRibbonSpec ribbon,
    Map<String, Affine2D> world,
    int outlineColor,
  ) {
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..color = Color(outlineColor)
      ..isAntiAlias = antiAlias;
    _drawRibbon(canvas, ribbon, world, _paint);

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = ribbon.outlineWidth * 2
      ..strokeJoin = StrokeJoin.round
      ..color = Color(outlineColor)
      ..isAntiAlias = antiAlias;
    _drawRibbon(canvas, ribbon, world, _paint);
  }

  void _drawRibbon(
    Canvas canvas,
    LimbRibbonSpec ribbon,
    Map<String, Affine2D> world,
    Paint paint,
  ) {
    final path = _ribbonPath(ribbon, world);
    if (path == null) return;
    canvas.drawPath(path, paint);
  }

  /// The world-space outline of [ribbon], or null if a joint bone is missing.
  Path? _ribbonPath(LimbRibbonSpec ribbon, Map<String, Affine2D> world) {
    final spine = <Offset>[];
    for (final boneId in ribbon.jointBoneIds) {
      final transform = world[boneId];
      if (transform == null) return null;
      final origin = transform.origin;
      spine.add(Offset(origin.x, origin.y));
    }
    return limbRibbonPath(
      spine,
      ribbon.halfWidths,
      samplesPerSegment: ribbon.samplesPerSegment,
    );
  }

  void _drawMeshFill(
    Canvas canvas,
    SkinnedMeshSpec mesh,
    Map<String, Affine2D> world,
  ) {
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..color = Color(mesh.color)
      ..isAntiAlias = antiAlias;
    _drawMesh(canvas, mesh, world, _paint);
  }

  void _drawMeshSilhouette(
    Canvas canvas,
    SkinnedMeshSpec mesh,
    Map<String, Affine2D> world,
    int outlineColor,
  ) {
    _paint
      ..style = PaintingStyle.fill
      ..strokeWidth = 0
      ..color = Color(outlineColor)
      ..isAntiAlias = antiAlias;
    _drawMesh(canvas, mesh, world, _paint);

    _paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = mesh.outlineWidth * 2
      ..strokeJoin = StrokeJoin.round
      ..color = Color(outlineColor)
      ..isAntiAlias = antiAlias;
    _drawMesh(canvas, mesh, world, _paint);
  }

  void _drawMesh(
    Canvas canvas,
    SkinnedMeshSpec mesh,
    Map<String, Affine2D> world,
    Paint paint,
  ) {
    final path = _meshPath(mesh, world);
    if (path == null) return;
    canvas.drawPath(path, paint);
  }

  /// The world-space contour of [mesh], or null if an influence bone is missing.
  Path? _meshPath(SkinnedMeshSpec mesh, Map<String, Affine2D> world) {
    final points = <Offset>[];
    for (final vertex in mesh.vertices) {
      var x = 0.0;
      var y = 0.0;
      for (final influence in vertex.influences) {
        final transform = world[influence.boneId];
        if (transform == null) return null;
        final p = transform.transformPoint(influence.x, influence.y);
        x += p.x * influence.weight;
        y += p.y * influence.weight;
      }
      points.add(Offset(x, y));
    }
    return _smoothClosedPath(points, mesh.boundary);
  }

  /// Builds a soft closed contour through a mesh boundary.
  ///
  /// The mesh primitive is used for organic character surfaces (jacket, pelvis,
  /// shoulder mass), where hard polygon corners immediately read as cardboard.
  /// Quadratic midpoint smoothing keeps every authored boundary vertex on the
  /// curve while rounding the transitions between them.
  Path _smoothClosedPath(List<Offset> points, List<int> boundary) {
    final path = Path();
    Offset pointAt(int i) => points[boundary[i % boundary.length]];
    Offset midpoint(Offset a, Offset b) => Offset(
      (a.dx + b.dx) * 0.5,
      (a.dy + b.dy) * 0.5,
    );

    final last = pointAt(boundary.length - 1);
    final first = pointAt(0);
    path.moveTo(midpoint(last, first).dx, midpoint(last, first).dy);
    for (var i = 0; i < boundary.length; i++) {
      final current = pointAt(i);
      final next = pointAt(i + 1);
      final mid = midpoint(current, next);
      path.quadraticBezierTo(current.dx, current.dy, mid.dx, mid.dy);
    }
    path.close();
    return path;
  }

  /// Draws the shape geometry of [d] with [paint] (fill or stroke).
  void _drawKind(Canvas canvas, BoneDrawable d, Paint paint) {
    final rect = Rect.fromCenter(
      center: Offset(d.dx, d.dy),
      width: d.width,
      height: d.height,
    );
    switch (d.kind) {
      case BoneShapeKind.capsule:
        final r = Radius.circular(
          (d.width < d.height ? d.width : d.height) / 2,
        );
        canvas.drawRRect(RRect.fromRectAndRadius(rect, r), paint);
      case BoneShapeKind.ellipse:
        canvas.drawOval(rect, paint);
      case BoneShapeKind.roundedRect:
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(d.cornerRadius)),
          paint,
        );
      case BoneShapeKind.triangle:
        canvas.drawPath(_trianglePath(rect), paint);
      case BoneShapeKind.taperedCapsule:
        canvas.drawPath(_taperedCapsulePath(d), paint);
    }
  }

  /// A capsule with different end radii — `width` at the near (top) end,
  /// `widthTip` at the far (bottom) end — joined by straight sides with rounded
  /// caps. Drawn along local +y (limbs hang from their pivot). This is the
  /// shape that turns "sausage" limbs into tapered arms/legs with real joints.
  Path _taperedCapsulePath(BoneDrawable d) {
    final r0 = d.width / 2; // near end (joint side, wide)
    final r1 = (d.widthTip < 0 ? d.width : d.widthTip) / 2; // far end (narrow)
    final cx = d.dx;
    final y0 = d.dy - d.height / 2 + r0; // near cap centre
    final y1 = d.dy + d.height / 2 - r1; // far cap centre
    return Path()
      ..moveTo(cx + r0, y0)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, y0), radius: r0),
        0,
        -math.pi, // near cap: right → top → left
        false,
      )
      ..lineTo(cx - r1, y1)
      ..arcTo(
        Rect.fromCircle(center: Offset(cx, y1), radius: r1),
        math.pi,
        -math.pi, // far cap: left → bottom → right
        false,
      )
      ..close();
  }

  /// An upward-pointing triangle inscribed in [rect] (apex at top-centre).
  Path _trianglePath(Rect rect) => Path()
    ..moveTo(rect.center.dx, rect.top)
    ..lineTo(rect.right, rect.bottom)
    ..lineTo(rect.left, rect.bottom)
    ..close();

  void _drawFace(Canvas canvas, FaceRig f, FaceState s) {
    // A singing mouth drops the jaw: the lower snout (muzzle, nose, whiskers,
    // mouth) translates down with the opening so the face articulates instead of
    // punching a hole in a rigid mask. Zero for the static expressions.
    final jaw = _jawDrop(f, s);
    _drawMuzzle(canvas, f, jaw);
    _drawEye(canvas, f, s, isLeft: true);
    _drawEye(canvas, f, s, isLeft: false);
    _drawBrow(canvas, f, s, isLeft: true);
    _drawBrow(canvas, f, s, isLeft: false);
    _drawWhiskers(canvas, f, jaw);
    _drawMouth(canvas, f, s, jaw);
    _drawNose(canvas, f, jaw);
  }

  /// How far the lower face drops for a singing viseme (0 for static shapes).
  double _jawDrop(FaceRig f, FaceState s) {
    if (!_singingShapes.contains(s.mouthShape)) return 0;
    var o = s.mouthOpen;
    if (o < 0) o = 0;
    if (o > 1) o = 1;
    return f.mouthHeight * 0.42 * o;
  }

  static const Set<MouthShape> _singingShapes = {
    MouthShape.singAh,
    MouthShape.singOh,
    MouthShape.singEe,
    MouthShape.teethOnLip,
  };

  void _drawMuzzle(Canvas canvas, FaceRig f, double jaw) {
    if (f.muzzleWidth <= 0 || f.muzzleHeight <= 0) return;
    // Lengthen the snout downward as the jaw drops (centre shifts half as far).
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, f.mouthOffsetY - 1 + jaw * 0.5),
        width: f.muzzleWidth,
        height: f.muzzleHeight + jaw,
      ),
      Paint()
        ..color = Color(f.muzzleColor)
        ..isAntiAlias = antiAlias,
    );
  }

  void _drawNose(Canvas canvas, FaceRig f, double jaw) {
    if (f.noseWidth <= 0 || f.noseHeight <= 0) return;
    final cy = f.mouthOffsetY - f.muzzleHeight * 0.32 + jaw * 0.3;
    final hw = f.noseWidth / 2;
    // Downward-pointing nose triangle with a softly rounded join.
    final path = Path()
      ..moveTo(-hw, cy - f.noseHeight / 2)
      ..lineTo(hw, cy - f.noseHeight / 2)
      ..lineTo(0, cy + f.noseHeight / 2)
      ..close();
    canvas
      ..drawPath(
        path,
        Paint()
          ..color = Color(f.noseColor)
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = antiAlias,
      )
      ..drawPath(
        path,
        Paint()
          ..color = const Color(_outlineColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeJoin = StrokeJoin.round
          ..isAntiAlias = antiAlias,
      );
  }

  void _drawWhiskers(Canvas canvas, FaceRig f, double jaw) {
    if (f.whiskerLength <= 0) return;
    final paint = Paint()
      ..color = Color(f.whiskerColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = antiAlias;
    final rootX = f.muzzleWidth * 0.22;
    final rootY = f.mouthOffsetY - 2 + jaw * 0.5;
    final len = f.whiskerLength;
    for (final sign in const [-1.0, 1.0]) {
      for (final tilt in const [-0.32, 0.0, 0.32]) {
        canvas.drawLine(
          Offset(sign * rootX, rootY),
          Offset(sign * (rootX + len), rootY + len * tilt),
          paint,
        );
      }
    }
  }

  void _drawEye(Canvas canvas, FaceRig f, FaceState s, {required bool isLeft}) {
    final cx = isLeft ? -f.eyeOffsetX : f.eyeOffsetX;
    final open = (isLeft ? s.eyeOpenLeft : s.eyeOpenRight).clamp(0.0, 1.0);
    final center = Offset(cx, f.eyeOffsetY);
    final halfH = f.eyeRadiusY * open;

    // Eye white (or a closed lid line when nearly shut).
    if (open <= 0.08) {
      final lid = Paint()
        ..color = Color(f.pupilColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = antiAlias;
      canvas.drawLine(
        Offset(cx - f.eyeRadiusX, f.eyeOffsetY),
        Offset(cx + f.eyeRadiusX, f.eyeOffsetY),
        lid,
      );
      return;
    }

    final whiteRect = Rect.fromCenter(
      center: center,
      width: f.eyeRadiusX * 2,
      height: halfH * 2,
    );
    // A large iris that fills most of the eye (set by [FaceRig.pupilRadius]),
    // tracking gaze, with a specular catchlight up toward the key light. The big
    // iris + the catchlight read as a designed, alive eye instead of a small
    // pupil floating in a blank white "googly" sclera. Both are clipped to the
    // open eye so the lid crops them when blinking.
    final iris = Offset(
      cx + s.eyeLookX * f.eyeRadiusX * 0.5,
      f.eyeOffsetY + s.eyeLookY * f.eyeRadiusY * 0.5,
    );
    final catchR = (f.pupilRadius * 0.34).clamp(1.3, 3.2);
    canvas
      ..drawOval(
        whiteRect,
        Paint()
          ..color = Color(f.eyeColor)
          ..isAntiAlias = antiAlias,
      )
      ..save()
      ..clipRect(whiteRect)
      ..drawCircle(
        iris,
        f.pupilRadius,
        Paint()
          ..color = Color(f.pupilColor)
          ..isAntiAlias = antiAlias,
      )
      ..drawCircle(
        iris + Offset(-f.pupilRadius * 0.38, -f.pupilRadius * 0.44),
        catchR,
        Paint()
          ..color = const Color(0xFFF6F8FF)
          ..isAntiAlias = antiAlias,
      )
      ..restore()
      ..drawOval(
        whiteRect,
        Paint()
          ..color = const Color(_outlineColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..isAntiAlias = antiAlias,
      );
  }

  void _drawBrow(
    Canvas canvas,
    FaceRig f,
    FaceState s, {
    required bool isLeft,
  }) {
    final cx = isLeft ? -f.eyeOffsetX : f.eyeOffsetX;
    final raise = isLeft ? s.browRaiseLeft : s.browRaiseRight;
    final angle = isLeft ? s.browAngleLeft : s.browAngleRight;
    final cy = f.browOffsetY - raise * 6;
    // Inner-brow tilt. Positive `angle` raises the *inner* end of each brow
    // (the worried "/\" of a sad face); negative lowers it into the furrowed
    // "\/" of an angry one. The left/right signs mirror so the tilt stays
    // symmetric about the face centre. (Canvas rotation is clockwise-positive,
    // so the inner end — +x on the left brow, -x on the right — needs opposite
    // signs to move the same way.)
    final rot = (isLeft ? -angle : angle) * 0.5;

    canvas
      ..save()
      ..translate(cx, cy)
      ..rotate(rot)
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: f.browWidth, height: 5),
          const Radius.circular(2.5),
        ),
        Paint()
          ..color = Color(f.browColor)
          ..isAntiAlias = antiAlias,
      )
      ..restore();
  }

  void _drawMouth(Canvas canvas, FaceRig f, FaceState s, double jaw) {
    final cy = f.mouthOffsetY;
    final hw = f.mouthWidth / 2;
    final hh = f.mouthHeight / 2 * (1 + s.mouthOpen);
    final stroke = Paint()
      ..color = Color(f.mouthColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = antiAlias;
    final fill = Paint()
      ..color = Color(f.mouthColor)
      ..isAntiAlias = antiAlias;

    final path = Path();
    switch (s.mouthShape) {
      case MouthShape.neutral:
        path
          ..moveTo(-hw, cy)
          ..quadraticBezierTo(0, cy + hh * 0.4, hw, cy);
        canvas.drawPath(path, stroke);
      case MouthShape.smileClosed:
        path
          ..moveTo(-hw, cy - hh * 0.2)
          ..quadraticBezierTo(0, cy + hh * 1.1, hw, cy - hh * 0.2);
        canvas.drawPath(path, stroke);
      case MouthShape.smileOpen:
        path
          ..moveTo(-hw, cy - hh * 0.1)
          ..quadraticBezierTo(0, cy + hh * 0.2, hw, cy - hh * 0.1)
          ..quadraticBezierTo(0, cy + hh * 1.5, -hw, cy - hh * 0.1)
          ..close();
        canvas.drawPath(path, fill);
      case MouthShape.sad:
        path
          ..moveTo(-hw, cy + hh * 0.4)
          ..quadraticBezierTo(0, cy - hh * 0.7, hw, cy + hh * 0.4);
        canvas.drawPath(path, stroke);
      case MouthShape.surprised:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, cy + hh * 0.3),
            width: f.mouthWidth * 0.6,
            height: hh * 2,
          ),
          fill,
        );
      case MouthShape.angry:
        path
          ..moveTo(-hw, cy + hh * 0.5)
          ..lineTo(0, cy - hh * 0.3)
          ..lineTo(hw, cy + hh * 0.5);
        canvas.drawPath(path, stroke);
      case MouthShape.singAh:
        // Tall open cavity with a tongue — the open vowel.
        _drawSingingMouth(canvas, f, s, jaw, widthFactor: 1, heightFactor: 1);
      case MouthShape.singOh:
        // A rounder "oh" ring — width nearer height (not a tall slot), no tongue.
        _drawSingingMouth(
          canvas,
          f,
          s,
          jaw,
          widthFactor: 0.58,
          heightFactor: 1,
          topBow: -1,
          tongue: false,
        );
      case MouthShape.singEe:
        // Wide + flat with a bared-teeth band = a stretched "ee".
        _drawSingingMouth(
          canvas,
          f,
          s,
          jaw,
          widthFactor: 1.5,
          heightFactor: 0.46,
          topBow: 0.4,
          tongue: false,
          teethBand: true,
        );
      case MouthShape.teethOnLip:
        _drawTeethOnLip(canvas, f, jaw);
    }
  }

  /// The "F/V" viseme: lips barely parted with the upper teeth resting on the
  /// lower lip — a shallow dark slot with a *slim* light teeth line along its top
  /// and a navy rim. Deliberately restrained so it reads as a consonant, not a
  /// white plaque, at the small scale the trio is drawn.
  void _drawTeethOnLip(Canvas canvas, FaceRig f, double jaw) {
    final cy = f.mouthOffsetY + jaw * 0.45;
    final hw = f.mouthWidth / 2 * 0.55;
    final hh = f.mouthHeight * 0.17; // very shallow — a near-closed consonant
    final lip = Paint()
      ..color = Color(f.mouthColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = antiAlias;
    // Shallow dark slot: a near-flat top lip over a softly rounded lower lip.
    final slot = Path()
      ..moveTo(-hw, cy)
      ..quadraticBezierTo(0, cy - hh * 0.25, hw, cy)
      ..quadraticBezierTo(0, cy + hh, -hw, cy)
      ..close();
    canvas
      ..drawPath(
        slot,
        Paint()
          ..color = const Color(_cavityColor)
          ..isAntiAlias = antiAlias,
      )
      // Slim upper-teeth edge resting along the top of the slot.
      ..drawPath(
        Path()
          ..moveTo(-hw * 0.78, cy - hh * 0.02)
          ..lineTo(hw * 0.78, cy - hh * 0.02),
        Paint()
          ..color = const Color(_teethColor)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = antiAlias,
      )
      ..drawPath(slot, lip);
  }

  /// A crafted singing mouth: a "D"-shaped cavity that opens by dropping its jaw
  /// (the top lip stays put, the bottom descends) so it reads as a real jaw drop
  /// rather than a ballooning smile. [FaceState.mouthOpen] drives the drop with a
  /// gentle gamma so quiet syllables still register; below [_singClosed] it
  /// collapses to a thin lip line so consecutive words read as separate
  /// movements. Depth comes from a dark cavity, a pink tongue that rises in past
  /// [_singTongue], and a crisp lip outline on top.
  ///
  /// [widthFactor] / [heightFactor] scale the aperture for vowel variety (wide
  /// "ah", round "oh", flat "ee"); [topBow] bows the top lip (+ down = a faint
  /// smile, − up = a rounder "oh").
  void _drawSingingMouth(
    Canvas canvas,
    FaceRig f,
    FaceState s,
    double jaw, {
    required double widthFactor,
    required double heightFactor,
    double topBow = 0.8,
    bool tongue = true,
    bool teethBand = false,
  }) {
    final cy = f.mouthOffsetY + jaw * 0.45;
    final hw = f.mouthWidth / 2 * widthFactor;
    var open = s.mouthOpen;
    if (open < 0) open = 0;
    if (open > 1) open = 1;

    final lip = Paint()
      ..color = Color(f.mouthColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = antiAlias;

    // Near-closed: a thin resting smile line, so each word starts/ends visibly shut.
    if (open < _singClosed) {
      final closedW = f.mouthWidth / 2;
      canvas.drawPath(
        Path()
          ..moveTo(-closedW, cy)
          ..quadraticBezierTo(0, cy + f.mouthHeight * 0.35, closedW, cy),
        lip,
      );
      return;
    }

    // Aperture above the closed threshold, eased so low openings still show.
    final a = math
        .pow((open - _singClosed) / (1 - _singClosed), 0.85)
        .toDouble();
    final topY = cy - f.mouthHeight * 0.15; // top lip ~fixed, slightly raised
    // A small dark cavity the instant the mouth cracks open (so quiet syllables
    // read as a gap), then a generous jaw drop with the aperture — a sung vowel
    // needs a real drop to read at the composition's small scale. The muzzle (24
    // tall) gives the bottom room to travel.
    final botY = topY + f.mouthHeight * heightFactor * (0.32 + 1.3 * a);

    // "D" cavity: a near-flat (gently bowed) top lip, rounded walls, and a wide
    // flat floor (rather than a single bottom point) so the tongue has somewhere
    // to sit and the open mouth reads as a chamber, not a wedge.
    final bw = hw * 0.62; // floor half-width
    final cavity = Path()
      ..moveTo(-hw, topY)
      ..quadraticBezierTo(0, topY + topBow, hw, topY)
      ..quadraticBezierTo(hw, botY, bw, botY)
      ..lineTo(-bw, botY)
      ..quadraticBezierTo(-hw, botY, -hw, topY)
      ..close();
    canvas.drawPath(
      cavity,
      Paint()
        ..color = const Color(_cavityColor)
        ..isAntiAlias = antiAlias,
    );

    // Upper-teeth band (the "ee" tell): a slim off-white line across the top of
    // the cavity so a wide flat mouth reads as bared teeth, not a small "ah".
    if (teethBand) {
      canvas
        ..save()
        ..clipPath(cavity)
        ..drawPath(
          Path()
            ..moveTo(-hw * 0.82, topY + 1.6)
            ..lineTo(hw * 0.82, topY + 1.6),
          Paint()
            ..color = const Color(_teethColor)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeCap = StrokeCap.round
            ..isAntiAlias = antiAlias,
        )
        ..restore();
    }

    // Tongue (the "ah" tell, exclusive to it): a pink mound filling the lower
    // cavity, clipped to it so a sliver of dark rim is left and it reads as the
    // mouth floor. It rises a little as the mouth opens wider.
    if (tongue && open > _singTongue) {
      final t = (open - _singTongue) / (1 - _singTongue);
      final span = botY - topY;
      final centerY = topY + span * (0.82 - 0.1 * t);
      canvas
        ..save()
        ..clipPath(cavity)
        ..drawOval(
          Rect.fromCenter(
            center: Offset(0, centerY),
            width: bw * 2.1,
            height: span * 0.55,
          ),
          Paint()
            ..color = Color(f.noseColor)
            ..isAntiAlias = antiAlias,
        )
        ..restore();
    }

    canvas.drawPath(cavity, lip); // crisp lip rim over cavity + tongue
  }

  static const int _outlineColor = 0xFF1B1B2A;

  /// Below this [FaceState.mouthOpen] the singing mouth is drawn shut (lip line).
  static const double _singClosed = 0.12;

  /// Above this opening the tongue rises into the singing cavity.
  static const double _singTongue = 0.4;

  /// Warm near-black for the open-mouth interior — harmonizes with the navy
  /// outline ([_outlineColor]) instead of a cold pure black.
  static const int _cavityColor = 0xFF241F2E;

  /// Off-white upper teeth for the [MouthShape.teethOnLip] (F/V) viseme.
  static const int _teethColor = 0xFFF3EFE6;
}
