import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/long_hair_painter.dart';

import '../companion_test_utils.dart';

const _c = CompanionPalette();
const _black = Color(0xFF000000);

/// Head-local units, the face's centre at (150, 130) of a 300 × 300 canvas:
/// room below for hair past the shoulders.
Future<Raster> _draw(void Function(Canvas canvas) draw) =>
    Raster.of(300, 300, (canvas) {
      canvas.translate(150, 130);
      draw(canvas);
    });

/// The lowest canvas row [colour] covers.
int _bottom(Raster r, Color colour) {
  for (var y = 299; y >= 0; y--) {
    for (var x = 0; x < 300; x++) {
      if (near(r.at(x, y), colour)) return y;
    }
  }
  return -1;
}

double _meanX(List<Offset> pts) =>
    pts.map((p) => p.dx).reduce((a, b) => a + b) / pts.length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('long', () {
    test('falls past the shoulders behind the head', () async {
      final r = await _draw((c) => drawLongBack(c, _c, Offset.zero));
      expect(_bottom(r, _c.hairBack), greaterThan(130 + 100));
    });

    test('in front, a curtain down each side, the face left clear', () async {
      final r = await _draw((c) => drawLongFront(c, _c, Offset.zero, 0));
      for (final x in [150 - 52, 150 + 52]) {
        expect(r.at(x, 130 + 20), isNot(_black), reason: 'x $x');
      }
      for (final x in [150 - 19, 150 + 19]) {
        expect(r.at(x, 130 - 6), _black, reason: 'eye at $x');
      }
    });

    test('is parted in the middle', () async {
      final r = await _draw((c) => drawLongFront(c, _c, Offset.zero, 0));
      final parting = r.at(150, 130 - 70);
      expect(parting.computeLuminance(), lessThan(_c.hair.computeLuminance()));
    });

    test('its hairline turns with the head', () {
      expect(
        _meanX(longFringe(Offset.zero, 1)),
        greaterThan(_meanX(longFringe(Offset.zero, 0))),
      );
    });
  });

  group('waves', () {
    test('reach the shoulders, not past them', () async {
      final r = await _draw((c) => drawWavesBack(c, _c, Offset.zero));
      expect(_bottom(r, _c.hairBack), inInclusiveRange(130 + 55, 130 + 80));
    });

    test('have a wavy edge, in and out down each side', () {
      final xs = [
        for (final p in wavesFringe(Offset.zero, 0))
          if (p.dx > 55 && p.dy > -10 && p.dy < 60) p.dx,
      ];
      expect(xs.toSet().length, greaterThan(1));
    });

    test(
      'sweep a fringe over the right of the forehead, parted on the left',
      () async {
        final r = await _draw((c) => drawWavesFront(c, _c, Offset.zero, 0));
        expect(r.at(150 + 20, 130 - 42), isNot(_black));
        // The parting's dip leaves the hairline highest on the left.
        final hairline = wavesFringe(
          Offset.zero,
          0,
        ).where((p) => p.dy > -55 && p.dy < -35 && p.dx.abs() < 30).toList();
        final highest = hairline.reduce((a, b) => a.dy < b.dy ? a : b);
        expect(highest.dx, lessThan(0));
      },
    );
  });

  group('ponytail', () {
    test('the tail hangs behind on the right, past the jaw', () async {
      final r = await _draw((c) => drawPonytailBack(c, _c, Offset.zero));
      var right = 0;
      var left = 0;
      for (var y = 130 + 20; y < 130 + 70; y++) {
        for (var x = 0; x < 300; x++) {
          if (!near(r.at(x, y), _c.hairBack)) continue;
          x > 150 ? right++ : left++;
        }
      }
      expect(right, greaterThan(200));
      expect(left, 0);
    });

    test('its tie sits at the tail root', () async {
      final r = await _draw((c) => drawPonytailBack(c, _c, Offset.zero));
      expect(near(r.at(150 + 36, 130 - 60), _c.hairShade), isTrue);
    });

    test('the front is pulled back clear of the forehead', () async {
      final r = await _draw((c) => drawPonytailFront(c, _c, 0));
      expect(r.at(150, 130 - 40), _black);
      expect(r.at(150, 130 - 70), isNot(_black));
    });

    test('its hairline turns with the head', () {
      expect(
        _meanX(ponytailFringe(1)),
        greaterThan(_meanX(ponytailFringe(0))),
      );
    });
  });
}
