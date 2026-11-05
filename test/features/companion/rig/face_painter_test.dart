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

    test(
      'a skew lifts the right corner and lowers the left: a smirk',
      () async {
        // Lips only on one half of the canvas, so each half's centroid is
        // that corner's height.
        Future<(double, double)> corners(double skew) async {
          Future<double> half(double clipX) async {
            final r = await _draw((c) {
              c
                ..save()
                ..clipRect(Rect.fromLTWH(clipX, -20, 16, 40));
              drawMouth(c, _c, 0, 0, Viseme.x.shape, 0, skew: skew);
              c.restore();
            });
            return r.centroid(_c.lips)!.dy;
          }

          return (await half(-16), await half(0));
        }

        final (flatLeft, flatRight) = await corners(0);
        final (smirkLeft, smirkRight) = await corners(1);
        expect(smirkRight, lessThan(flatRight - 1));
        expect(smirkLeft, greaterThan(flatLeft + 1));
      },
    );

    test('a negative smile turns the corners down', () async {
      final flat = await _draw(
        (c) => drawMouth(c, _c, 0, 0, Viseme.x.shape, 0),
      );
      final frown = await _draw(
        (c) => drawMouth(c, _c, 0, 0, Viseme.x.shape, -1),
      );
      expect(
        frown.centroid(_c.lips)!.dy,
        greaterThan(flat.centroid(_c.lips)!.dy),
      );
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

  test('a fuller brow is thicker, grown downwards from the same top', () async {
    final plain = await _draw((c) => drawBrow(c, _c, Offset.zero, 1, 0, 0));
    final full = await _draw(
      (c) => drawBrow(c, _c, Offset.zero, 1, 0, 0, fullness: 1.5),
    );
    expect(full.count(_c.brow), greaterThan(plain.count(_c.brow) * 1.15));
    // Its centre sits lower: the extra is below, not above.
    expect(
      full.centroid(_c.brow)!.dy,
      greaterThan(plain.centroid(_c.brow)!.dy),
    );
  });

  test('drawNose paints the nostril shade', () async {
    final r = await _draw((c) => drawNose(c, _c, 0, 0));
    expect(r.count(_c.skinDeep), greaterThan(10));
  });

  group('how far a brow can go', () {
    test('a small raise passes almost as it is', () {
      expect(browLift(0), 0);
      expect(browLift(0.3), closeTo(0.3, 0.03));
      expect(browLift(-0.5), -0.5);
    });

    test('rising saturates, falling stops, and both keep their order', () {
      var last = browLift(-5);
      for (var r = -5.0; r <= 5; r += 0.25) {
        final lift = browLift(r);
        expect(lift, greaterThanOrEqualTo(last), reason: 'raise $r');
        expect(lift, inInclusiveRange(-browMaxFall, browMaxRise));
        last = lift;
      }
      expect(browLift(5), closeTo(browMaxRise, 0.01));
      expect(browLift(-5), -browMaxFall);
    });

    // The regression: the "one brow" flourish at its spring's overshoot, on
    // a skeptical face, hooked the brow far off the eye.
    test('no raise and tilt lifts a brow off the eye or hooks it', () {
      const eyeTop = -6.0 - 8;
      for (var r = -4.0; r <= 4; r += 0.5) {
        for (var t = -3.0; t <= 3; t += 0.5) {
          for (final side in [-1, 1]) {
            final b = browShape(const Offset(20, -27), side, r, t);
            final why = 'raise $r, tilt $t, side $side';
            // Never more than a brow's travel above where it rests.
            expect(
              b.peak.dy,
              greaterThan(-27 - 3.2 - 4.1 * browMaxRise - 0.01),
              reason: why,
            );
            // Never down into the eye.
            expect(b.inner.dy, lessThan(eyeTop + 4), reason: why);
            // Never a hook: the inner end at most a few units below the peak.
            expect(b.inner.dy - b.peak.dy, lessThan(10.5), reason: why);
          }
        }
      }
    });

    test('a brow raised high gives way on its tilt', () {
      double slant(double raise, double tilt) {
        final b = browShape(Offset.zero, 1, raise, tilt);
        return (b.inner.dy - b.outer.dy).abs();
      }

      for (final tilt in [-1.2, 1.2]) {
        expect(slant(3, tilt), lessThan(slant(0, tilt) * 0.6), reason: '$tilt');
      }
    });
  });

  test("a man's straighter brow stands its peak lower over the same ends", () {
    final arched = browShape(Offset.zero, 1, 0, 0);
    final straight = browShape(Offset.zero, 1, 0, 0, arch: 0.4);
    expect(straight.peak.dy, greaterThan(arched.peak.dy + 1.5));
    expect(straight.inner, arched.inner);
    expect(straight.outer, arched.outer);
  });

  group("a man's features", () {
    test(
      'a narrower eye shows less of its white, its lash line lighter',
      () async {
        // The same iris on both, so only the opening differs.
        final hers = await _draw(
          (c) => drawEye(
            c,
            _c,
            Offset.zero,
            1,
            0,
            0,
            Offset.zero,
            irisRadius: 6.4,
          ),
        );
        final his = await _draw(
          (c) => drawEye(
            c,
            _c,
            Offset.zero,
            1,
            0,
            0,
            Offset.zero,
            open: 0.68,
            irisRadius: 6.4,
            lashLine: 1.3,
          ),
        );
        expect(
          his.count(_c.eyeWhite),
          lessThan(hers.count(_c.eyeWhite) * 0.75),
        );
        expect(his.count(_c.ink), lessThan(hers.count(_c.ink)));
      },
    );

    test('thin lips cover less than full ones on the same mouth', () async {
      Future<int> lips(double weight) async {
        final r = await _draw(
          (c) => drawMouth(
            c,
            _c,
            0,
            0,
            const MouthShape(),
            0,
            lipWeight: weight,
          ),
        );
        return r.count(_c.lips, tolerance: 12) +
            r.count(_c.lipsUpper, tolerance: 12);
      }

      expect(await lips(0.4), lessThan(await lips(1) * 0.7));
    });

    test('a broad nose is wider, with a shaded bridge down one side', () async {
      int width(Raster r) {
        var left = 100;
        var right = 0;
        for (var y = 0; y < 100; y++) {
          for (var x = 0; x < 100; x++) {
            if (!near(r.at(x, y), _c.skinDeep, tolerance: 20)) continue;
            if (x < left) left = x;
            if (x > right) right = x;
          }
        }
        return right - left;
      }

      final small = await _draw((c) => drawNose(c, _c, 0, 0));
      final broad = await _draw((c) => drawNose(c, _c, 0, 0, broad: true));
      expect(width(broad), greaterThan(width(small) + 2));
      // The bridge's shadow, well above the tip.
      // At three times the size: head-local x 2..5, y -14..-4.
      int bridge(Raster r) {
        var n = 0;
        for (var y = 50 - 42; y < 50 - 12; y++) {
          for (var x = 50 + 6; x < 50 + 16; x++) {
            if (!near(r.at(x, y), const Color(0xFF808080), tolerance: 4)) n++;
          }
        }
        return n;
      }

      expect(bridge(broad), greaterThan(bridge(small) + 20));
    });
  });
}
