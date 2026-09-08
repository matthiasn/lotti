import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/domain/character_gait.dart';
import 'package:lotti/features/plaza/scene/character_limb.dart';
import 'package:vector_math/vector_math.dart';

void main() {
  test(
    'keeps the sole at its contact through parent tilt and scaled turns',
    () {
      for (final scale in [0.6, 0.72, 0.85, 1.0]) {
        final root = Node()
          ..position = Vector3(3, 0.08, -2)
          ..scale = Vector3.all(scale);
        final hip = Node()..position = Vector3(0, 0.62, 0);
        final knee = Node()..position = Vector3(0, -0.29, 0.16);
        final ankle = Node()..position = Vector3(0, -0.255, -0.12);
        root.add(hip);
        hip.add(knee);
        knee.add(ankle);
        final limb = CharacterLimb(hip, knee, ankle);
        for (var step = 0; step < 120; step++) {
          final yaw = step / 120 * math.pi * 2;
          root.rotation =
              Quaternion.axisAngle(Vector3(0, 1, 0), yaw) *
              Quaternion.axisAngle(Vector3(1, 0, 0), 0.12 * math.sin(yaw));
          final foot = CharacterFootPose(
            x: 3 + math.sin(yaw) * 0.1 * scale,
            y: 0.08 + CharacterGait.ankleHeight * scale,
            z: -2 + math.cos(yaw) * 0.1 * scale,
            yaw: yaw,
            pitch: 0,
            planted: true,
          );
          limb.solve(
            foot,
            forward: Vector3(math.sin(yaw), 0, math.cos(yaw)),
            scale: scale,
          );
          final actual = ankle.globalTransform.getTranslation();
          expect(actual.x, closeTo(foot.x, 1e-5));
          expect(actual.y, closeTo(foot.y, 1e-5));
          expect(actual.z, closeTo(foot.z, 1e-5));
          final up =
              ankle.globalTransform.transform3(Vector3(0, 1, 0)) - actual;
          expect(up.normalized().dot(Vector3(0, 1, 0)), closeTo(1, 1e-6));
        }
      }
    },
  );
}
