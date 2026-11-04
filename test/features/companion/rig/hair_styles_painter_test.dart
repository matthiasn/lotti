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

  /// The styles with hair over the forehead: all but the bare crown.
  final fringed = [
    for (final style in CompanionHairStyle.values)
      if (style != CompanionHairStyle.balding) style,
  ];

  test(
    'every style but the bare crown draws hair behind the head and over the '
    'forehead',
    () async {
      for (final style in fringed) {
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
    for (final style in fringed) {
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
        // A bare crown has no fringe to cast one.
        expect(
          n,
          style == CompanionHairStyle.balding ? 0 : greaterThan(1000),
          reason: style.name,
        );
      }
    },
  );

  test(
    'the bare crown has no hairline, but hair behind and over the ears',
    () async {
      expect(fringeFor(CompanionHairStyle.balding, Offset.zero, 0), isEmpty);
      expect(
        (await _draw(
          (c) => drawBackHair(c, _c, Offset.zero, CompanionHairStyle.balding),
        )).count(_c.hairBack),
        greaterThan(2000),
      );
      expect(
        (await front(CompanionHairStyle.balding)).count(_c.hair, tolerance: 30),
        greaterThan(200),
      );
    },
  );

  group('textured styles', () {
    const white = Color(0xFFFFFFFF);

    /// [draw] on white, head origin as in [_draw]: edges blend towards white,
    /// so only shading reads darker than a fill.
    Future<Raster> onWhite(void Function(Canvas canvas) draw) => Raster.of(
      300,
      300,
      (canvas) {
        canvas.translate(150, 170);
        draw(canvas);
      },
      background: white,
    );

    double luminance(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;

    /// The pixel at head-local ([x], [y]).
    Color local(Raster r, double x, double y) => r.at(150 + x, 170 + y);

    test('every style draws the same picture on every frame: the coils and '
        "locs' jitter is fixed, never random", () async {
      for (final style in CompanionHairStyle.values) {
        for (final layer in <void Function(Canvas)>[
          (c) => drawBackHair(c, _c, const Offset(3, 1), style),
          (c) => drawFrontHair(c, _c, const Offset(3, 1), 0.4, style),
        ]) {
          final a = await _draw(layer);
          final b = await _draw(layer);
          var differ = 0;
          for (var y = 0; y < 300; y++) {
            for (var x = 0; x < 300; x++) {
              if (a.at(x, y) != b.at(x, y)) differ++;
            }
          }
          expect(differ, 0, reason: style.name);
        }
      }
    });

    test('the curls and the afro are textured behind the head too, not a '
        'flat fill', () async {
      final flat = luminance(_c.hairBack);
      for (final style in [CompanionHairStyle.curls, CompanionHairStyle.afro]) {
        final r = await onWhite((c) => drawBackHair(c, _c, Offset.zero, style));
        var shaded = 0;
        for (var y = 0; y < 300; y++) {
          for (var x = 0; x < 300; x++) {
            if (luminance(r.at(x, y)) < flat - 0.04) shaded++;
          }
        }
        expect(shaded, greaterThan(800), reason: style.name);
      }
    });

    test("the afro's front comes down beside her face to her ears, so its "
        'underside is all that is left dark', () async {
      final r = await front(CompanionHairStyle.afro);
      for (final x in [-58.0, 58.0]) {
        expect(
          near(local(r, x, -10), const Color(0xFF000000)),
          isFalse,
          reason: 'x $x',
        );
      }
    });

    test('the curls are rounded under at the jaw, never square', () async {
      final r = await _draw(
        (c) => drawBackHair(c, _c, Offset.zero, CompanionHairStyle.curls),
      );
      for (final x in [-44.0, 44.0]) {
        expect(
          near(local(r, x, 17), const Color(0xFF000000)),
          isTrue,
          reason: 'x $x',
        );
      }
    });

    test("the locs' strands sweep back side by side over the crown, never "
        'meeting in one point', () async {
      final r = await onWhite(
        (c) => drawFrontHair(c, _c, Offset.zero, 0, CompanionHairStyle.locs),
      );
      final hair = luminance(_c.hair);
      // The grooves between the strands just under the top of the crown,
      // where strands that met in a point would all still be bunched.
      final grooves = [
        for (var x = -50; x <= 50; x++)
          if (luminance(local(r, x.toDouble(), -88)) < hair - 0.08) x,
      ];
      expect(grooves, isNotEmpty);
      expect(grooves.last - grooves.first, greaterThan(40));
    });
  });
}
