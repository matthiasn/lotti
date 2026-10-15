import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';
import 'package:lotti/features/companion/rig/hand_painter.dart';

import '../companion_test_utils.dart';

const _skin = Color(0xFFF1D2BD);
const _deep = Color(0xFFC0957C);

Future<Raster> _hand(HandShape h) => Raster.of(120, 120, (canvas) {
  canvas
    ..translate(30, 60)
    ..scale(4);
  drawHand(canvas, h, skin: _skin, deep: _deep);
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('thumbSpine', () {
    test('grows from inside the palm through four joints', () {
      final spine = thumbSpine(const HandShape());
      expect(spine, hasLength(4));
      expect(spine.first, const Offset(6, -1.2));
    });

    test('swings further out to the thumb side with thumbOut', () {
      final tucked = thumbSpine(const HandShape(thumbOut: 0)).last;
      final out = thumbSpine(const HandShape(thumbOut: 1)).last;
      expect(out.dy, lessThan(tucked.dy));
    });

    test('folds shorter as it curls', () {
      final straight = thumbSpine(const HandShape(thumb: 0));
      final curled = thumbSpine(const HandShape(thumb: 1));
      expect(
        (curled[2] - curled[1]).distance,
        lessThan((straight[2] - straight[1]).distance),
      );
    });
  });

  test('an open hand reaches further than a fist', () async {
    final open = await _hand(HandPose.open.shape);
    final fist = await _hand(HandPose.thumbs.shape);
    double reach(Raster r) {
      for (var x = 119; x >= 0; x--) {
        for (var y = 0; y < 120; y++) {
          if (near(r.at(x, y), _skin)) return x.toDouble();
        }
      }
      return 0;
    }

    expect(reach(open), greaterThan(reach(fist) + 8));
  });

  test('the hand is one body: skin fills over a dark rim', () async {
    final r = await _hand(HandPose.relaxed.shape);
    expect(r.count(_skin), greaterThan(400));
    expect(r.count(_deep, tolerance: 20), greaterThan(30));
    expect(r.count(_skin), greaterThan(r.count(_deep, tolerance: 20)));
  });
}
