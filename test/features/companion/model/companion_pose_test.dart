import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';

void main() {
  test('the default pose stands still, hands low, mouth at rest', () {
    const p = CompanionPose();
    expect(p.pelvis, Offset.zero);
    expect(p.lean, 0);
    expect(p.blink, 0);
    expect(p.wink, 0);
    expect(p.handInFrontOfFace, isFalse);
    expect(p.left.wrist.dx, lessThan(0));
    expect(p.right.wrist.dx, greaterThan(0));
    expect(p.left.elbow, isNull);
    expect(p.mouth.open, const MouthShape().open);
    expect(p.tail, 0);
    expect(p.earFlick, 0);
  });

  test('the default hands point down and inward, mirrored', () {
    const p = CompanionPose();
    expect(p.left.handAngle + p.right.handAngle, closeTo(math.pi, 1e-9));
  });

  group('blinkOf', () {
    test('without a wink, both eyes blink alike', () {
      const pose = CompanionPose(blink: 0.3);
      expect(pose.blinkOf(-1), 0.3);
      expect(pose.blinkOf(1), 0.3);
    });

    test('a wink shuts only its own eye', () {
      expect(const CompanionPose(wink: 1).blinkOf(1), 1);
      expect(const CompanionPose(wink: 1).blinkOf(-1), 0);
      expect(const CompanionPose(wink: -1).blinkOf(-1), 1);
      expect(const CompanionPose(wink: -1).blinkOf(1), 0);
    });

    test('a half wink closes the rest of the way from the blink', () {
      // Lids at rest half shut, a half wink: halfway from there to shut.
      expect(
        const CompanionPose(blink: 0.5, wink: 0.5).blinkOf(1),
        closeTo(0.75, 1e-9),
      );
      expect(const CompanionPose(blink: 0.5, wink: 0.5).blinkOf(-1), 0.5);
    });
  });
}
