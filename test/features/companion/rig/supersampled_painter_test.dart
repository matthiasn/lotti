import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/companion_painter.dart';
import 'package:lotti/features/companion/rig/supersampled_painter.dart';

import '../companion_test_utils.dart';

/// A white disc on black, aliased: drawn with anti-aliasing off, as a
/// renderer without multisampling draws every path.
class _HardDisc extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) => canvas.drawCircle(
    size.center(Offset.zero),
    size.shortestSide * 0.4,
    Paint()
      ..color = const Color(0xFFFFFFFF)
      ..isAntiAlias = false,
  );

  @override
  bool shouldRepaint(_HardDisc oldDelegate) => false;
}

/// How many pixels are neither black nor white: the edge's soft steps.
int _greys(Raster r) {
  var n = 0;
  for (var y = 0; y < r.height; y++) {
    for (var x = 0; x < r.width; x++) {
      final c = r.at(x, y);
      if (c != const Color(0xFF000000) && c != const Color(0xFFFFFFFF)) n++;
    }
  }
  return n;
}

Future<Raster> _paint(CustomPainter p) =>
    Raster.of(64, 64, (canvas) => p.paint(canvas, const Size(64, 64)));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an aliased edge comes out anti-aliased', () async {
    final hard = await _paint(_HardDisc());
    final smooth = await _paint(
      SupersampledPainter(inner: _HardDisc(), devicePixelRatio: 1),
    );
    expect(_greys(hard), 0);
    expect(_greys(smooth), greaterThan(60));
    // The inside stays solid, the outside clear.
    expect(smooth.at(32, 32), const Color(0xFFFFFFFF));
    expect(smooth.at(1, 1), const Color(0xFF000000));
  });

  test('more samples give finer steps along the edge', () async {
    Future<int> levels(int factor) async {
      final r = await _paint(
        SupersampledPainter(
          inner: _HardDisc(),
          devicePixelRatio: 1,
          factor: factor,
        ),
      );
      final seen = <int>{};
      for (var y = 0; y < 64; y++) {
        for (var x = 0; x < 64; x++) {
          seen.add((r.at(x, y).r * 255).round());
        }
      }
      return seen.length;
    }

    expect(await levels(4), greaterThan(await levels(2)));
  });

  test('factor 1 paints the inner painter directly', () async {
    final direct = await _paint(
      SupersampledPainter(inner: _HardDisc(), devicePixelRatio: 1, factor: 1),
    );
    expect(_greys(direct), 0);
  });

  test('a big view takes a smaller factor, never a texture over the cap', () {
    expect(SupersampledPainter.effectiveFactor(const Size(500, 800), 4), 4);
    expect(SupersampledPainter.effectiveFactor(const Size(1200, 1800), 4), 2);
    expect(SupersampledPainter.effectiveFactor(const Size(5000, 100), 4), 1);
  });

  test('repaints when its inner painter or its sampling changes', () {
    final a = SupersampledPainter(
      inner: CompanionPainter(
        pose: const CompanionPose(),
        look: CompanionLook.grandma,
      ),
      devicePixelRatio: 2,
    );
    SupersampledPainter withInner(CompanionPose pose) => SupersampledPainter(
      inner: CompanionPainter(pose: pose, look: CompanionLook.grandma),
      devicePixelRatio: 2,
    );
    expect(a.shouldRepaint(withInner(const CompanionPose())), isFalse);
    expect(a.shouldRepaint(withInner(const CompanionPose(blink: 1))), isTrue);
    expect(
      a.shouldRepaint(
        SupersampledPainter(
          inner: a.inner,
          devicePixelRatio: 1,
        ),
      ),
      isTrue,
    );
    expect(
      a.shouldRepaint(
        SupersampledPainter(inner: a.inner, devicePixelRatio: 2, factor: 2),
      ),
      isTrue,
    );
  });

  test('an empty size paints nothing', () async {
    final r = await Raster.of(4, 4, (canvas) {
      SupersampledPainter(
        inner: _HardDisc(),
        devicePixelRatio: 1,
      ).paint(canvas, Size.zero);
    });
    expect(r.at(2, 2), const Color(0xFF000000));
  });
}
