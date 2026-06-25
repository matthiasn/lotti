import 'dart:math' as math;
import 'dart:typed_data';

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
    final hiddenBones = rig.ribbonHiddenBoneIds;

    // Ribbons are drawn in the same silhouette/fill two-pass style as bones.
    // They replace selected rigid upper/lower limb drawables with one continuous
    // surface, so elbows and knees bend through a curve instead of hinging like
    // separate cardboard pieces.
    for (final ribbon in rig.ribbonDrawOrder) {
      final outline = ribbon.outlineColor;
      if (outline == null || ribbon.outlineWidth <= 0) continue;
      _drawRibbonSilhouette(canvas, ribbon, world, outline);
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
    var ribbonIndex = 0;
    for (final bone in rig.drawOrder) {
      while (ribbonIndex < ribbons.length && ribbons[ribbonIndex].z <= bone.z) {
        _drawRibbonFill(canvas, ribbons[ribbonIndex], world);
        ribbonIndex++;
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
      canvas.restore();
    }
    while (ribbonIndex < ribbons.length) {
      _drawRibbonFill(canvas, ribbons[ribbonIndex], world);
      ribbonIndex++;
    }
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
    final spine = <Offset>[];
    for (final boneId in ribbon.jointBoneIds) {
      final transform = world[boneId];
      if (transform == null) return;
      final origin = transform.origin;
      spine.add(Offset(origin.x, origin.y));
    }
    final path = limbRibbonPath(
      spine,
      ribbon.halfWidths,
      samplesPerSegment: ribbon.samplesPerSegment,
    );
    canvas.drawPath(path, paint);
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
    _drawMuzzle(canvas, f);
    _drawEye(canvas, f, s, isLeft: true);
    _drawEye(canvas, f, s, isLeft: false);
    _drawBrow(canvas, f, s, isLeft: true);
    _drawBrow(canvas, f, s, isLeft: false);
    _drawWhiskers(canvas, f);
    _drawMouth(canvas, f, s);
    _drawNose(canvas, f);
  }

  void _drawMuzzle(Canvas canvas, FaceRig f) {
    if (f.muzzleWidth <= 0 || f.muzzleHeight <= 0) return;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, f.mouthOffsetY - 1),
        width: f.muzzleWidth,
        height: f.muzzleHeight,
      ),
      Paint()
        ..color = Color(f.muzzleColor)
        ..isAntiAlias = antiAlias,
    );
  }

  void _drawNose(Canvas canvas, FaceRig f) {
    if (f.noseWidth <= 0 || f.noseHeight <= 0) return;
    final cy = f.mouthOffsetY - f.muzzleHeight * 0.32;
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

  void _drawWhiskers(Canvas canvas, FaceRig f) {
    if (f.whiskerLength <= 0) return;
    final paint = Paint()
      ..color = Color(f.whiskerColor)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = antiAlias;
    final rootX = f.muzzleWidth * 0.22;
    final rootY = f.mouthOffsetY - 2;
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
        Offset(
          cx + s.eyeLookX * f.eyeRadiusX * 0.5,
          f.eyeOffsetY + s.eyeLookY * f.eyeRadiusY * 0.5,
        ),
        f.pupilRadius,
        Paint()
          ..color = Color(f.pupilColor)
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

  void _drawMouth(Canvas canvas, FaceRig f, FaceState s) {
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
    }
  }

  static const int _outlineColor = 0xFF1B1B2A;
}
