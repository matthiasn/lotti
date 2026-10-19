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
    expect(faceHand, {
      GestureName.think,
      GestureName.listen,
      GestureName.facepalm,
    });
  });

  test('the wave wobbles the right hand', () {
    final osc = GestureName.wave.gesture.oscRight!;
    expect(osc.hz, greaterThan(0));
    expect(osc.angle, greaterThan(0));
  });

  test('hands on hips asks for the elbows out, each to its own side', () {
    final g = GestureName.handsOnHips.gesture;
    // 0 is screen-right and 90 down: the right elbow out and down to the
    // right, the left mirrored.
    expect(g.right!.elbow, inExclusiveRange(0, 90));
    expect(g.left!.elbow, inExclusiveRange(90, 180));
    expect(g.left!.x, -g.right!.x);
    // Only the hip gestures bias an elbow.
    for (final name in GestureName.values) {
      final arms = [name.gesture.left, name.gesture.right];
      final biased = arms.any((a) => a?.elbow != null);
      final onHip = arms.any(
        (a) => a != null && a.elbow != null && a.y > -70 && a.x.abs() > 40,
      );
      expect(biased, onHip, reason: name.name);
    }
  });

  test('the slow clap claps three times: together, then apart, in turn', () {
    final phases = GestureName.slowClap.gesture.then;
    final gaps = [
      for (final (_, p) in phases) p.right!.x - p.left!.x,
    ];
    expect(gaps.where((g) => g < 20), hasLength(3));
    for (var i = 1; i < gaps.length; i++) {
      expect((gaps[i] < 20) != (gaps[i - 1] < 20), isTrue, reason: 'phase $i');
    }
  });

  test('the eye roll sweeps the eyes up and across before it settles', () {
    final g = GestureName.eyeRoll.gesture;
    final gazes = [g.gaze!, for (final (_, p) in g.then) p.gaze!];
    expect(gazes.first.$2, lessThan(-0.5));
    expect(gazes[1].$2, lessThan(-0.5));
    expect(gazes[2].$1, greaterThan(gazes.first.$1));
    expect(gazes.last.$2, greaterThan(gazes[1].$2));
  });
}
