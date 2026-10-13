import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';

void main() {
  test('every gesture moves at least one arm and holds for a while', () {
    for (final g in GestureName.values) {
      final gesture = g.gesture;
      expect(
        gesture.left != null || gesture.right != null,
        isTrue,
        reason: g.name,
      );
      expect(gesture.hold, greaterThan(0), reason: g.name);
    }
  });

  test('later phases start in order, before the gesture lets go', () {
    for (final g in GestureName.values) {
      var last = 0.0;
      for (final (delay, _) in g.gesture.then) {
        expect(delay, greaterThan(last), reason: g.name);
        expect(delay, lessThan(g.gesture.hold), reason: g.name);
        last = delay;
      }
    }
  });

  test('ready keeps both hands relaxed at the waist', () {
    const ready = CompanionGesture.ready;
    expect(ready.left, CompanionGesture.readyLeft);
    expect(ready.right, CompanionGesture.readyRight);
    expect(ready.left!.hand, HandPose.relaxed);
    expect(ready.left!.x, lessThan(0));
    expect(ready.right!.x, greaterThan(0));
  });

  test('the hand-to-face gestures say so, so the arm draws over the head', () {
    final faceHand = {
      for (final g in GestureName.values)
        if (g.gesture.faceHand) g,
    };
    expect(faceHand, {GestureName.think, GestureName.listen});
  });

  test('the wave wobbles the right hand', () {
    final osc = GestureName.wave.gesture.oscRight!;
    expect(osc.hz, greaterThan(0));
    expect(osc.angle, greaterThan(0));
  });
}
