import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/rig/hair_styles_painter.dart';

import '../companion_test_utils.dart';

const _c = CompanionPalette();

/// The head's origin at (150, 170) of a 300 × 300 canvas: room above for an
/// afro and below for locs.
Future<Raster> _draw(void Function(Canvas canvas) draw) =>
    Raster.of(300, 300, (canvas) {
      canvas.translate(150, 170);
      draw(canvas);
    });

/// The rows and columns [colour] covers, as a rectangle.
Rect _extent(Raster r, Color colour) {
  var top = r.height.toDouble();
  var bottom = 0.0;
  var left = r.width.toDouble();
  var right = 0.0;
  for (var y = 0; y < r.height; y++) {
    for (var x = 0; x < r.width; x++) {
      if (near(r.at(x, y), colour)) {
        top = y < top ? y.toDouble() : top;
        bottom = y > bottom ? y.toDouble() : bottom;
        left = x < left ? x.toDouble() : left;
        right = x > right ? x.toDouble() : right;
      }
    }
  }
  return Rect.fromLTRB(left, top, right, bottom);
}

typedef Range = ({int from, int to});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Rect> back(
    CompanionHairStyle style, [
    Offset lag = Offset.zero,
  ]) async => _extent(
    await _draw((c) => drawBackHair(c, _c, lag, style)),
    _c.hairBack,
  );

  Future<Raster> front(CompanionHairStyle style, [Offset lag = Offset.zero]) =>
      _draw((c) => drawFrontHair(c, _c, lag, 0, style));

  test(
    'every style draws hair behind the head and over the forehead',
    () async {
      for (final style in CompanionHairStyle.values) {
        final behind = await _draw(
          (c) => drawBackHair(c, _c, Offset.zero, style),
        );
        expect(
          behind.count(_c.hairBack),
          greaterThan(2000),
          reason: style.name,
        );
        final over = await front(style);
        expect(
          over.count(_c.hair, tolerance: 30),
          greaterThan(800),
          reason: style.name,
        );
        // Never over the eyes: the face's middle stays clear.
        expect(
          near(over.at(150 - 19, 170 - 6), const Color(0xFF000000)),
          isTrue,
          reason: style.name,
        );
      }
    },
  );

  test('each style has its own silhouette', () async {
    final bun = await back(CompanionHairStyle.bun);
    final afro = await back(CompanionHairStyle.afro);
    final locs = await back(CompanionHairStyle.locs);
    final bob = await back(CompanionHairStyle.bob);
    final curls = await back(CompanionHairStyle.curls);
    // The afro is the biggest: higher and wider than the bun's cap.
    expect(afro.top, lessThan(bun.top - 5));
    expect(afro.width, greaterThan(bun.width + 20));
    // Locs hang well below the chin (y 40), past the bun's knot.
    expect(locs.bottom, greaterThan(170 + 80));
    expect(locs.bottom, greaterThan(bun.bottom + 30));
    // The bob reaches the chin all round; curls stay close to the head.
    expect(bob.bottom, greaterThan(170 + 35));
    expect(curls.bottom, lessThan(170 + 35));
    expect(curls.width, lessThan(afro.width - 20));
  });

  test("the bob's fringe falls lower on the forehead than the bun's", () async {
    double fringeBottom(Raster r) {
      // Straight down the middle: the lowest hair pixel above the eyes.
      for (var y = 170 - 10; y > 0; y--) {
        if (near(r.at(150, y), _c.hair, tolerance: 40)) return y.toDouble();
      }
      return 0;
    }

    final bun = await front(CompanionHairStyle.bun);
    final bob = await front(CompanionHairStyle.bob);
    expect(fringeBottom(bob), greaterThan(fringeBottom(bun) + 6));
  });

  test('what hangs swings with the hair lag; the crown stays', () async {
    /// The mean x of the hair in [rows] (canvas y), behind the head.
    Future<double> meanX(
      CompanionHairStyle style,
      Offset lag,
      Range rows,
    ) async {
      final r = await _draw((c) => drawBackHair(c, _c, lag, style));
      var sum = 0.0;
      var n = 0;
      for (var y = rows.from; y < rows.to; y++) {
        for (var x = 0; x < 300; x++) {
          if (near(r.at(x, y), _c.hairBack)) {
            sum += x;
            n++;
          }
        }
      }
      return sum / n;
    }

    const lag = Offset(7, 0);
    for (final (style, ends) in [
      // The locs below the shoulders, the bob's ends at the chin.
      (CompanionHairStyle.locs, (from: 170 + 70, to: 170 + 95)),
      (CompanionHairStyle.bob, (from: 170 + 28, to: 170 + 40)),
    ]) {
      const crown = (from: 170 - 90, to: 170 - 75);
      expect(
        await meanX(style, lag, ends),
        greaterThan(await meanX(style, Offset.zero, ends) + 2),
        reason: style.name,
      );
      expect(
        await meanX(style, lag, crown),
        closeTo(await meanX(style, Offset.zero, crown), 0.5),
        reason: style.name,
      );
    }
  });

  test('the hairline, and the shadow under it, turns with the head', () {
    for (final style in CompanionHairStyle.values) {
      final ahead = fringeFor(style, Offset.zero, 0);
      final turned = fringeFor(style, Offset.zero, 1);
      double meanX(List<Offset> pts) =>
          pts.map((p) => p.dx).reduce((a, b) => a + b) / pts.length;
      expect(
        meanX(turned),
        greaterThan(meanX(ahead) + 0.5),
        reason: style.name,
      );
    }
  });

  test(
    'the forehead shadow is drawn under the fringe, on the forehead',
    () async {
      for (final style in CompanionHairStyle.values) {
        final r = await _draw(
          (c) => drawForeheadShadow(c, _c, Offset.zero, 0, style),
        );
        // Drawn at 30 % alpha over black: any non-black pixel is shadow.
        var n = 0;
        for (var y = 0; y < 300; y++) {
          for (var x = 0; x < 300; x++) {
            if (r.at(x, y) != const Color(0xFF000000)) n++;
          }
        }
        expect(n, greaterThan(1000), reason: style.name);
      }
    },
  );
}
