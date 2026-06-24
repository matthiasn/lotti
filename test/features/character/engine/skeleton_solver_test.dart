import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/skeleton_solver.dart';
import 'package:lotti/features/character/model/affine2d.dart';
import 'package:lotti/features/character/model/bone.dart';
import 'package:lotti/features/character/model/pose.dart';
import 'package:lotti/features/character/model/rig_spec.dart';

void main() {
  // A simple two-bone arm: root at origin, forearm hanging 10 units below.
  RigSpec armRig() => RigSpec(
    name: 'arm',
    bones: const [
      Bone(id: 'upper', parent: null, pivotX: 0, pivotY: 0, z: 0),
      Bone(id: 'lower', parent: 'upper', pivotX: 0, pivotY: 10, z: 1),
    ],
  );

  group('SkeletonSolver', () {
    test('rest pose places child pivot at its offset from the parent', () {
      final solver = SkeletonSolver(armRig());
      final world = solver.solve(const Pose(joints: {}));
      final lower = solver.jointWorldPosition(world, 'lower');
      expect(lower.x, closeTo(0, 1e-9));
      expect(lower.y, closeTo(10, 1e-9));
    });

    test('rotating the parent swings the child about the parent pivot', () {
      final solver = SkeletonSolver(armRig());
      final world = solver.solve(
        const Pose(joints: {'upper': JointPose(rotation: math.pi / 2)}),
      );
      // The forearm pivot (0,10) rotated 90° about the origin -> (-10,0).
      final lower = solver.jointWorldPosition(world, 'lower');
      expect(lower.x, closeTo(-10, 1e-9));
      expect(lower.y, closeTo(0, 1e-9));
    });

    test('child rotation composes on top of the parent', () {
      final solver = SkeletonSolver(armRig());
      final world = solver.solve(
        const Pose(
          joints: {
            'upper': JointPose(rotation: math.pi / 2),
            'lower': JointPose(rotation: math.pi / 2),
          },
        ),
      );
      // A point 5 units along the forearm's local +y, after both rotations.
      final tip = solver.localToWorld(world, 'lower', 0, 5);
      // Upper's 90° turn puts the forearm origin at (-10,0); the forearm's own
      // 90° turn points its local +y toward world -y, so the tip is 5 above it.
      expect(tip.x, closeTo(-10, 1e-9));
      expect(tip.y, closeTo(-5, 1e-9));
    });

    test('base transform offsets the whole skeleton', () {
      final solver = SkeletonSolver(armRig());
      final world = solver.solve(
        const Pose(joints: {}),
        base: Affine2D.translation(100, 50),
      );
      final upper = solver.jointWorldPosition(world, 'upper');
      final lower = solver.jointWorldPosition(world, 'lower');
      expect(upper.x, closeTo(100, 1e-9));
      expect(upper.y, closeTo(50, 1e-9));
      expect(lower.x, closeTo(100, 1e-9));
      expect(lower.y, closeTo(60, 1e-9));
    });

    test('root pose offset moves the whole body', () {
      final solver = SkeletonSolver(armRig());
      final world = solver.solve(const Pose(joints: {}, rootDx: 7, rootDy: -3));
      final upper = solver.jointWorldPosition(world, 'upper');
      expect(upper.x, closeTo(7, 1e-9));
      expect(upper.y, closeTo(-3, 1e-9));
    });

    test('every bone gets a world transform', () {
      final solver = SkeletonSolver(armRig());
      final world = solver.solve(const Pose(joints: {}));
      expect(world.keys, containsAll(<String>['upper', 'lower']));
    });
  });
}
