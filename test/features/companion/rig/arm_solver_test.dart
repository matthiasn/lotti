import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/companion/model/companion_gesture.dart';
import 'package:lotti/features/companion/rig/arm_solver.dart';

void main() {
  group('solveArm', () {
    glados.Glados3(
      glados.any.intInRange(-160, 200),
      glados.any.intInRange(-260, 40),
      glados.any.choose([-1, 1]),
      glados.ExploreConfig(numRuns: 250),
    ).test('never stretches a bone and keeps the wrist in reach', (x, y, side) {
      final sh = Offset(side * shoulderRight.dx, shoulderRight.dy);
      final r = solveArm(sh, Offset(x.toDouble(), y.toDouble()), side);
      expect((r.elbow - sh).distance, lessThanOrEqualTo(upperArm + 1e-6));
      expect((r.wrist - r.elbow).distance, lessThanOrEqualTo(forearm + 1e-3));
      expect(
        (r.wrist - sh).distance,
        lessThanOrEqualTo(upperArm + forearm),
      );
    }, tags: 'glados');

    test('every gesture target gets an allowed elbow, on both sides', () {
      final targets = [
        (CompanionGesture.readyLeft, -1),
        (CompanionGesture.readyRight, 1),
        for (final g in GestureName.values) ...[
          if (g.gesture.left != null) (g.gesture.left!, -1),
          if (g.gesture.right != null) (g.gesture.right!, 1),
        ],
      ];
      for (final (t, side) in targets) {
        final sh = Offset(side * shoulderRight.dx, shoulderRight.dy);
        final r = solveArm(sh, Offset(t.x, t.y), side);
        expect(
          elbowAllowed(sh, r.elbow, r.wrist, side),
          isTrue,
          reason: 'target (${t.x}, ${t.y})',
        );
      }
    });

    test('hands in front of the chest keep the elbows at the sides', () {
      // The X-arms case: both wrists near the middle of the chest.
      for (final side in [-1, 1]) {
        final sh = Offset(side * shoulderRight.dx, shoulderRight.dy);
        final r = solveArm(sh, Offset(side * 9.0, -92), side);
        expect(side * (r.elbow.dx - sh.dx), greaterThanOrEqualTo(-medial));
      }
    });

    test('a previous elbow keeps the choice steady', () {
      const sh = shoulderRight;
      const wrist = Offset(80, -60);
      final free = solveArm(sh, wrist, 1);
      final held = solveArm(sh, wrist, 1, previous: free.elbow);
      expect((held.elbow - free.elbow).distance, lessThan(1e-9));
    });
  });

  group('elbowAllowed', () {
    test('rejects a stretched upper arm and a hiked elbow', () {
      const sh = shoulderRight;
      expect(
        elbowAllowed(sh, sh + const Offset(0, 60), const Offset(46, -10), 1),
        isFalse,
      );
      // Elbow above the shoulder while the hand hangs below it.
      expect(
        elbowAllowed(
          sh,
          sh + const Offset(30, -30),
          sh + const Offset(30, 10),
          1,
        ),
        isFalse,
      );
    });

    test('accepts the hanging arm', () {
      const sh = shoulderRight;
      final elbow = sh + const Offset(10, 48);
      final wrist = elbow + const Offset(5, 45);
      expect(elbowAllowed(sh, elbow, wrist, 1), isTrue);
    });
  });

  test('shrug lifts the shoulder only when the hand rises above it', () {
    const sh = shoulderRight;
    expect(shrug(sh, sh + const Offset(0, 40)), 0);
    expect(shrug(sh, sh + const Offset(0, -120)), shrugHeight);
    expect(
      shrug(sh, sh + const Offset(0, -45)),
      inExclusiveRange(0, shrugHeight),
    );
  });

  test('fitElbow pulls an elbow back onto bones of a real length', () {
    const sh = shoulderRight;
    const wrist = Offset(110, -60);
    final e = fitElbow(sh, sh + const Offset(200, 200), wrist);
    expect((e - sh).distance, lessThanOrEqualTo(upperArm + 1e-6));
    expect((e - wrist).distance, lessThanOrEqualTo(forearm + 1e-3));
    // An elbow sitting on the shoulder hangs instead of dividing by zero.
    final onShoulder = fitElbow(sh, sh, sh + const Offset(0, 80));
    expect(onShoulder.dx.isFinite && onShoulder.dy.isFinite, isTrue);
  });
}
