import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/face_painter.dart';

import '../companion_test_utils.dart';

const _c = CompanionPalette();

/// On mid grey, so anti-aliased edges never pass for the dark pupil.
Future<Raster> _draw(void Function(Canvas canvas) draw) => Raster.of(
  100,
  100,
  background: const Color(0xFF808080),
  (canvas) {
    canvas
      ..translate(50, 50)
      ..scale(3);
    draw(canvas);
  },
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('drawMouth', () {
    test('an open mouth shows its inside, teeth and tongue', () async {
      final open = await _draw(
        (c) => drawMouth(c, _c, 0, 0, Viseme.d.shape, 0),
      );
      expect(open.at(50, 50 + 3 * 3), _c.mouthIn);
      expect(open.count(_c.teeth), greaterThan(20));
      expect(open.count(_c.tongue), greaterThan(20));
    });

    test('a closed mouth shows lips and only the seam', () async {
      final closed = await _draw(
        (c) => drawMouth(c, _c, 0, 0, Viseme.x.shape, 0),
      );
      final open = await _draw(
        (c) => drawMouth(c, _c, 0, 0, Viseme.d.shape, 0),
      );
      expect(closed.count(_c.lips), greaterThan(50));
      expect(closed.count(_c.teeth), 0);
      expect(closed.count(_c.mouthIn), lessThan(open.count(_c.mouthIn) ~/ 4));
    });

    test('the F/V bite shows the upper teeth on a closed mouth', () async {
      final bite = await _draw(
        (c) => drawMouth(
          c,
          _c,
          0,
          0,
          const MouthShape(bite: 1),
          0,
        ),
      );
      expect(bite.count(_c.teeth), greaterThan(10));
    });

    test('a smile lifts the corners', () async {
      final flat = await _draw(
        (c) => drawMouth(c, _c, 0, 0, Viseme.x.shape, 0),
      );
      final smile = await _draw(
        (c) => drawMouth(c, _c, 0, 0, Viseme.x.shape, 1),
      );
      expect(smile.centroid(_c.lips)!.dy, lessThan(flat.centroid(_c.lips)!.dy));
    });
  });

  group('drawEye', () {
    test('open, the iris follows the gaze', () async {
      final ahead = await _draw(
        (c) => drawEye(c, _c, Offset.zero, 1, 0, 0, Offset.zero),
      );
      final right = await _draw(
        (c) => drawEye(c, _c, Offset.zero, 1, 0, 0, const Offset(1, 0)),
      );
      expect(ahead.count(_c.pupil), greaterThan(20));
      expect(
        right.centroid(_c.pupil)!.dx,
        greaterThan(ahead.centroid(_c.pupil)!.dx + 5),
      );
    });

    test('shut, no eye shows at all', () async {
      final shut = await _draw(
        (c) => drawEye(c, _c, Offset.zero, 1, 1, 0, Offset.zero),
      );
      expect(shut.count(_c.pupil), 0);
      expect(shut.count(_c.eyeWhite), 0);
      expect(shut.count(_c.ink), greaterThan(10));
    });

    test("an animal's eye: a bigger iris, a cat's slit pupil", () async {
      final human = await _draw(
        (c) => drawEye(c, _c, Offset.zero, 1, 0, 0, Offset.zero),
      );
      final round = await _draw(
        (c) => drawEye(
          c,
          _c,
          Offset.zero,
          1,
          0,
          0,
          Offset.zero,
          irisRadius: 8.6,
        ),
      );
      final slit = await _draw(
        (c) => drawEye(
          c,
          _c,
          Offset.zero,
          1,
          0,
          0,
          Offset.zero,
          irisRadius: 8.6,
          slit: true,
        ),
      );
      expect(round.count(_c.pupil), greaterThan(human.count(_c.pupil)));
      expect(slit.count(_c.pupil), lessThan(round.count(_c.pupil) * 0.75));
      expect(slit.count(_c.pupil), greaterThan(10));
    });

    test('without lashes, less ink at the outer corner', () async {
      final lashed = await _draw(
        (c) => drawEye(c, _c, Offset.zero, 1, 1, 0, Offset.zero),
      );
      final bare = await _draw(
        (c) => drawEye(c, _c, Offset.zero, 1, 1, 0, Offset.zero, lashes: false),
      );
      expect(bare.count(_c.ink), lessThan(lashed.count(_c.ink)));
      expect(bare.count(_c.ink), greaterThan(10));
    });
  });

  test('drawBrow rises with raise', () async {
    final rest = await _draw((c) => drawBrow(c, _c, Offset.zero, 1, 0, 0));
    final up = await _draw((c) => drawBrow(c, _c, Offset.zero, 1, 1, 0));
    expect(up.centroid(_c.brow)!.dy, lessThan(rest.centroid(_c.brow)!.dy - 5));
  });

  test('drawNose paints the nostril shade', () async {
    final r = await _draw((c) => drawNose(c, _c, 0, 0));
    expect(r.count(_c.skinDeep), greaterThan(10));
  });
}
