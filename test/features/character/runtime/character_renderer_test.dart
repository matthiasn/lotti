import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/face.dart';
import 'package:lotti/features/character/model/rig_spec.dart';
import 'package:lotti/features/character/runtime/character_renderer.dart';

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
}
