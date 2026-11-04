import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/rig/hair_painter.dart';

import '../companion_test_utils.dart';

const _c = CompanionPalette();

Future<Raster> _draw(void Function(Canvas canvas) draw) =>
    Raster.of(200, 200, (canvas) {
      canvas.translate(100, 110);
      draw(canvas);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the outlines close over the crown, the fringe off the forehead', () {
    final cap = capOutline();
    final fringe = fringeOutline();
    expect(cap.map((p) => p.dy).reduce((a, b) => a < b ? a : b), -90);
    // The hairline stays above the eyes (y -6).
    for (final p in fringe) {
      expect(p.dy, lessThan(-6));
    }
  });

  test('the back of the head is the bun and the cap', () async {
    final r = await _draw((c) => drawBunBack(c, _c, Offset.zero));
    expect(r.count(_c.hairBack), greaterThan(2000));
  });

  test(
    'the bun shows beside the jaw, past the face, low on the left',
    () async {
      final r = await _draw((c) => drawBunBack(c, _c, Offset.zero));
      // The face's edge is x -45; the knot reaches well beyond it.
      var beyond = 0;
      for (var y = 110; y < 110 + 30; y++) {
        for (var x = 0; x < 100 - 48; x++) {
          if (!near(r.at(x, y), const Color(0xFF000000))) beyond++;
        }
      }
      expect(beyond, greaterThan(150));
      expect(bunCentre.dx, lessThan(-40));
      expect(bunCentre.dy, greaterThan(0));
    },
  );

  test(
    'the front hair covers the crown, its strands swing with the lag',
    () async {
      final still = await _draw(
        (c) => drawBunFront(c, _c, Offset.zero, 0),
      );
      final swung = await _draw(
        (c) => drawBunFront(c, _c, const Offset(7, 0), 0),
      );
      expect(still.count(_c.hair), greaterThan(100));
      expect(
        swung.centroid(_c.hair)!.dx,
        greaterThan(still.centroid(_c.hair)!.dx),
      );
    },
  );

  group('the front, in a dark colour', () {
    const black = CompanionPalette(
      hair: Color(0xFF2E2A28),
      hairBack: Color(0xFF1F1C1A),
      hairShade: Color(0xFF141210),
      hairLight: Color(0xFF4A4542),
    );

    test('keeps every wave and strand inside the hair', () async {
      final r = await _draw((c) => drawBunFront(c, black, Offset.zero, 0));
      // Above the crown's top (-91) there is nothing at all: the wave arcs
      // used to stand off it like wires.
      for (var y = 0; y < 110 - 93; y++) {
        for (var x = 0; x < 200; x++) {
          expect(r.at(x, y), const Color(0xFF000000), reason: 'x $x y $y');
        }
      }
    });

    test('stays dark: no broad grey band over the crown', () async {
      final r = await _draw((c) => drawBunFront(c, black, Offset.zero, 0));
      var bright = 0;
      var hair = 0;
      for (var y = 110 - 90; y < 110 - 50; y++) {
        for (var x = 40; x < 160; x++) {
          final px = r.at(x, y);
          if (px == const Color(0xFF000000)) continue;
          hair++;
          if (px.computeLuminance() > black.hairLight.computeLuminance()) {
            bright++;
          }
        }
      }
      expect(hair, greaterThan(2000));
      expect(bright / hair, lessThan(0.05));
    });
  });
}
