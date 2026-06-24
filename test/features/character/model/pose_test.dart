import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/pose.dart';

void main() {
  group('Pose', () {
    test('jointOf returns the stored joint pose', () {
      const pose = Pose(joints: {'a': JointPose(rotation: 1.5)});
      expect(pose.jointOf('a').rotation, 1.5);
    });

    test('jointOf falls back to the identity for unknown bones', () {
      const pose = Pose(joints: {});
      final jp = pose.jointOf('missing');
      expect(jp.rotation, 0);
      expect(jp.scaleX, 1);
      expect(jp.scaleY, 1);
      expect(identical(jp, JointPose.identity), isTrue);
    });

    test('root offsets default to zero', () {
      const pose = Pose(joints: {});
      expect(pose.rootDx, 0);
      expect(pose.rootDy, 0);
      expect(pose.rootRotation, 0);
    });
  });
}
