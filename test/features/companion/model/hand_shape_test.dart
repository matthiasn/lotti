import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';

void main() {
  test('values and fromValues round-trip', () {
    const h = HandShape(
      thumb: 0.1,
      index: 0.2,
      middle: 0.3,
      ring: 0.4,
      thumbOut: 0.6,
      spread: 0.7,
    );
    expect(HandShape.fromValues(h.values).values, h.values);
    expect(h.fingerCurls, [0.2, 0.3, 0.4, 0.5]);
  });

  test('blend runs from one shape to the other', () {
    final open = HandPose.open.shape;
    final fist = HandPose.thumbs.shape;
    expect(open.blend(fist, 0).values, open.values);
    expect(fist.blend(open, 0).values, fist.values);
    final half = open.blend(fist, 0.5);
    expect(half.index, closeTo((open.index + fist.index) / 2, 1e-12));
  });

  test('the named hands hold what their names say', () {
    expect(HandPose.point.shape.index, 0);
    expect(HandPose.point.shape.middle, greaterThan(0.9));
    expect(HandPose.horns.shape.index, 0);
    expect(HandPose.horns.shape.pinky, 0);
    expect(HandPose.horns.shape.middle, 1);
    expect(HandPose.thumbs.shape.thumbOut, 1);
    for (final pose in HandPose.values) {
      for (final v in pose.shape.values) {
        expect(v, inInclusiveRange(0, 1), reason: pose.name);
      }
    }
  });
}
