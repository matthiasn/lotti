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
}
