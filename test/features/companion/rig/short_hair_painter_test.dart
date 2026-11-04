import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/short_hair_painter.dart';

import '../companion_test_utils.dart';

const _c = CompanionPalette();

/// Head-local units, the face's centre at (150, 170) of a 300 × 300 canvas.
Future<Raster> _draw(void Function(Canvas canvas) draw) =>
    Raster.of(300, 300, (canvas) {
      canvas.translate(150, 170);
      draw(canvas);
    });

/// The lowest and highest canvas rows [colour] covers.
(int, int) _rows(Raster r, Color colour, {int tolerance = 6}) {
  var top = 300;
  var bottom = -1;
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 300; x++) {
      if (near(r.at(x, y), colour, tolerance: tolerance)) {
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
  }
  return (top, bottom);
}

double _meanX(List<Offset> pts) =>
    pts.map((p) => p.dx).reduce((a, b) => a + b) / pts.length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('short', () {
    test(
      'behind the head, stays close: over the crown, above the jaw',
      () async {
        final r = await _draw((c) => drawShortBack(c, _c));
        final (top, bottom) = _rows(r, _c.hairBack);
        expect(top, inInclusiveRange(170 - 70, 170 - 66));
        // Short of the jaw (y 40) and the ears' lobes.
        expect(bottom, lessThan(170 + 10));
      },
    );

    test('over the forehead, keeps the eyes and brows clear', () async {
      final r = await _draw((c) => drawShortFront(c, _c, 0));
      expect(r.count(_c.hair, tolerance: 30), greaterThan(800));
      for (final x in [150 - 20, 150 + 20]) {
        expect(r.at(x, 170 - 27), const Color(0xFF000000));
      }
    });

    test('is parted on the left, its parting line in the shade', () async {
      final r = await _draw((c) => drawShortFront(c, _c, 0));
      expect(
        near(r.at(150 - 15, 170 - 53), _c.hairShade, tolerance: 20),
        isTrue,
      );
    });

    test('turns its hairline with the head', () {
      expect(_meanX(shortFringe(1)), greaterThan(_meanX(shortFringe(0))));
    });
  });

  group('balding', () {
    test('behind the head, rings the back and leaves the crown bare', () async {
      final r = await _draw((c) => drawBaldingBack(c, _c));
      expect(r.count(_c.hairBack), greaterThan(2000));
      final (top, _) = _rows(r, _c.hairBack);
      expect(top, greaterThan(170 - 30));
    });

    test('over the face, a tuft over each ear and nothing between', () async {
      final r = await _draw((c) => drawBaldingFront(c, _c, 0));
      var left = 0;
      var right = 0;
      var middle = 0;
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 300; x++) {
          if (!near(r.at(x, y), _c.hair, tolerance: 30)) continue;
          if (x < 150 - 38) {
            left++;
          } else if (x > 150 + 38) {
            right++;
          } else {
            middle++;
          }
        }
      }
      expect(left, greaterThan(100));
      expect(right, closeTo(left, left * 0.1));
      expect(middle, 0);
    });

    test('lights the bare crown', () async {
      final r = await _draw((c) => drawBaldingFront(c, _c, 0));
      // Drawn at 70 % over the black canvas: bright at its centre, on the
      // crown above the brows, and nowhere below them.
      expect(r.at(150 - 12, 170 - 48).computeLuminance(), greaterThan(0.25));
      expect(r.at(150 - 12, 170 - 20), const Color(0xFF000000));
    });
  });
}
