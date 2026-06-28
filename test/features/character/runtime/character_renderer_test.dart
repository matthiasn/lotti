import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/rig_spec.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

/// Renders a single-bone rig of [drawable] centred on a [w]x[h] canvas and
/// returns the RGBA bytes. The bone sits at the canvas centre with identity
/// pose, so the drawable's local geometry maps straight to pixels.
Future<Uint8List> _renderOne(
  BoneDrawable drawable, {
  int w = 120,
  int h = 160,
}) async {
  final rig = RigSpec(
    name: 't',
    bones: [
      Bone(
        id: 'b',
        parent: null,
        pivotX: 0,
        pivotY: 0,
        z: 0,
        drawable: drawable,
      ),
    ],
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final world = {'b': Affine2D.translation(w / 2, h * 0.2)};
  CharacterRenderer(
    antiAlias: false,
  ).paint(canvas, rig, world, const FaceState());
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Counts painted (non-transparent) pixels in row [y] of a [w]-wide RGBA buffer.
int _rowWidth(Uint8List px, int w, int y) {
  var n = 0;
  for (var x = 0; x < w; x++) {
    if (px[(y * w + x) * 4 + 3] != 0) n++;
  }
  return n;
}

const int _faceW = 160;
const int _faceH = 160;

/// Renders just the cat face (the body bones get no world transform, so only the
/// head-anchored face draws) with [face] applied, returning the RGBA bytes. Used
/// to assay the singing-mouth cavity by exact fill colour (anti-aliasing off, so
/// every fill is its exact colour).
Future<Uint8List> _renderFace(FaceState face) async {
  final rig = buildCatInSuitRig();
  final world = {
    rig.face!.anchorBoneId: Affine2D.translation(_faceW / 2, _faceH / 2),
  };
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  CharacterRenderer(antiAlias: false).paint(canvas, rig, world, face);
  final picture = recorder.endRecording();
  final image = await picture.toImage(_faceW, _faceH);
  final data = await image.toByteData();
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

/// Counts pixels that exactly match the opaque 0xAARRGGBB [argb].
int _countColor(Uint8List px, int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  var n = 0;
  for (var i = 0; i + 3 < px.length; i += 4) {
    if (px[i] == r && px[i + 1] == g && px[i + 2] == b && px[i + 3] == 255) n++;
  }
  return n;
}

/// The widest single row (in pixels) of an exact-[argb] fill — a cheap proxy for
/// a shape's maximum width.
int _maxRowOfColor(Uint8List px, int argb) {
  final r = (argb >> 16) & 0xFF;
  final g = (argb >> 8) & 0xFF;
  final b = argb & 0xFF;
  var best = 0;
  for (var y = 0; y < _faceH; y++) {
    var c = 0;
    for (var x = 0; x < _faceW; x++) {
      final i = (y * _faceW + x) * 4;
      if (px[i] == r && px[i + 1] == g && px[i + 2] == b && px[i + 3] == 255) {
        c++;
      }
    }
    if (c > best) best = c;
  }
  return best;
}

// The crafted singing-mouth interior and the cat's pink nose (== the tongue).
const int _cavity = 0xFF241F2E;
const int _nosePink = 0xFFC8696B;

void main() {
  const w = 120;
  const h = 160;

  testWidgets('taperedCapsule is wide at the top and narrows to the tip', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // Wide near end (40) tapering to a narrow tip (10) over 100 units, hung
      // from the bone origin at 0.2*h. So row ~origin is wide, row near the
      // bottom of the shape is narrow.
      final px = await _renderOne(
        const BoneDrawable(
          kind: BoneShapeKind.taperedCapsule,
          width: 40,
          widthTip: 10,
          height: 100,
          dy: 50,
          color: 0xFF2E3A59,
        ),
      );
      final topY = (h * 0.2).round() + 12; // just below the wide cap
      final bottomY = (h * 0.2).round() + 88; // near the narrow tip
      final topWidth = _rowWidth(px, w, topY);
      final bottomWidth = _rowWidth(px, w, bottomY);

      expect(topWidth, greaterThan(0), reason: 'shape should paint near top');
      expect(
        bottomWidth,
        greaterThan(0),
        reason: 'shape should paint near tip',
      );
      expect(
        topWidth,
        greaterThan(bottomWidth + 8),
        reason:
            'tapered: the joint end must be clearly wider than the tip '
            '(top=$topWidth, bottom=$bottomWidth)',
      );
    });
  });

  testWidgets('taperedCapsule with no widthTip falls back to a straight tube', (
    tester,
  ) async {
    await tester.runAsync(() async {
      // widthTip defaults to -1 -> uniform width; top and tip widths match.
      final px = await _renderOne(
        const BoneDrawable(
          kind: BoneShapeKind.taperedCapsule,
          width: 30,
          height: 100,
          dy: 50,
          color: 0xFF2E3A59,
        ),
      );
      final topWidth = _rowWidth(px, w, (h * 0.2).round() + 20);
      final bottomWidth = _rowWidth(px, w, (h * 0.2).round() + 80);
      expect(topWidth, greaterThan(0));
      expect(
        (topWidth - bottomWidth).abs(),
        lessThanOrEqualTo(2),
        reason:
            'no taper -> near-uniform width (top=$topWidth, '
            'bottom=$bottomWidth)',
      );
    });
  });

  testWidgets('every shape kind paints something', (tester) async {
    await tester.runAsync(() async {
      for (final kind in BoneShapeKind.values) {
        final px = await _renderOne(
          BoneDrawable(
            kind: kind,
            width: 40,
            widthTip: 12,
            height: 40,
            cornerRadius: 8,
            color: 0xFFE8A55A,
            outlineColor: 0xFF1B1B2A,
            outlineWidth: 2,
          ),
        );
        var painted = 0;
        for (var i = 3; i < px.length; i += 4) {
          if (px[i] != 0) painted++;
        }
        expect(painted, greaterThan(50), reason: '$kind should paint');
      }
    });
  });

  testWidgets('singing mouth opens wider as mouthOpen grows', (tester) async {
    await tester.runAsync(() async {
      final small = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.2),
        ),
        _cavity,
      );
      final big = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.58),
        ),
        _cavity,
      );
      expect(small, greaterThan(0), reason: 'a cracked mouth shows a cavity');
      expect(
        big,
        greaterThan(small * 1.4),
        reason:
            'the cavity grows clearly with mouthOpen (small=$small big=$big)',
      );
    });
  });

  testWidgets('singing mouth is shut below the closed threshold', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final cavity = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.08),
        ),
        _cavity,
      );
      expect(
        cavity,
        lessThan(4),
        reason:
            'below 0.12 the mouth is a thin lip line, not an open cavity '
            '(got $cavity)',
      );
    });
  });

  testWidgets('tongue appears only when the mouth opens wide', (tester) async {
    await tester.runAsync(() async {
      // The pink nose is constant, so any extra pink when open is the tongue.
      final closed = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.08),
        ),
        _nosePink,
      );
      final open = _countColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singAh, mouthOpen: 0.85),
        ),
        _nosePink,
      );
      expect(
        open,
        greaterThan(closed + 15),
        reason:
            'a wide mouth adds a pink tongue past the static nose '
            '(closed=$closed open=$open)',
      );
    });
  });

  testWidgets('the ee viseme is wider than the oh viseme', (tester) async {
    await tester.runAsync(() async {
      final ee = _maxRowOfColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singEe, mouthOpen: 0.58),
        ),
        _cavity,
      );
      final oh = _maxRowOfColor(
        await _renderFace(
          const FaceState(mouthShape: MouthShape.singOh, mouthOpen: 0.58),
        ),
        _cavity,
      );
      expect(
        ee,
        greaterThan(oh + 4),
        reason:
            'ee is the wide viseme, oh the narrow/round one (ee=$ee oh=$oh)',
      );
    });
  });
}
