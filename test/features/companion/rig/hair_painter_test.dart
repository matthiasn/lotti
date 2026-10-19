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
    // The bun hangs low to the left, behind the neck.
    expect(r.at(100 - 26, 110 + 30), _c.hairBack);
  });

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
}
