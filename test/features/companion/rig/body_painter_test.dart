import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/hand_shape.dart';
import 'package:lotti/features/companion/rig/body_painter.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

import '../companion_test_utils.dart';

/// Character space, 1:1, origin at the bottom middle of a 320 × 480 canvas.
Future<Raster> _body(
  void Function(Canvas canvas, RigFrame f) draw, {
  CompanionPose pose = const CompanionPose(),
}) => Raster.of(320, 480, (canvas) {
  canvas.translate(160, 470);
  draw(canvas, RigFrame(pose));
});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the legs stand on the floor in her shoes', () async {
    const look = CompanionLook.grandma;
    final r = await _body((c, f) => drawLegs(c, f, look));
    expect(r.count(look.palette.shoe), greaterThan(100));
    // Shoes near the floor, below the knees.
    expect(r.centroid(look.palette.shoe)!.dy, greaterThan(440));
  });

  test('the neck joins the head to the body', () async {
    const look = CompanionLook.grandma;
    final r = await _body((c, f) => drawNeck(c, f, look));
    expect(r.count(look.palette.skin), greaterThan(300));
  });

  test(
    'the dress wears a cardigan and a scarf; beads only on stage rock',
    () async {
      for (final look in CompanionLook.all) {
        final r = await _body((c, f) => drawDress(c, f, look));
        final p = look.palette;
        expect(r.count(p.dress), greaterThan(2000), reason: look.id);
        expect(r.count(p.cardigan), greaterThan(1000), reason: look.id);
        if (look.beads) {
          expect(
            r.count(p.beads, tolerance: 2),
            greaterThan(80),
            reason: look.id,
          );
        }
      }
      final everyday = await _body(
        (c, f) => drawDress(c, f, CompanionLook.grandma),
      );
      expect(everyday.count(CompanionLook.grandmaRock.palette.beads), 0);
    },
  );

  test('the hem trails the sway', () async {
    const look = CompanionLook.grandma;
    final still = await _body((c, f) => drawDress(c, f, look));
    final swung = await _body(
      (c, f) => drawDress(c, f, look),
      pose: const CompanionPose(hemLag: 5),
    );
    expect(
      swung.centroid(look.palette.dress)!.dx,
      greaterThan(still.centroid(look.palette.dress)!.dx),
    );
  });

  group('drawArm', () {
    const raised = ArmPose(
      wrist: Offset(88, -176),
      handAngle: -1.36,
      hand: HandShape(thumb: 0, index: 0, middle: 0, thumbOut: 0.75),
    );

    test('a raised arm reaches above the shoulder in its sleeve', () async {
      const look = CompanionLook.grandma;
      final r = await _body((c, f) => drawArm(c, f, look, raised, 1));
      // The pelvis sits at y -178; the wrist goes 176 above it.
      const top = 470 - 178 - 176;
      var skinAbove = 0;
      for (var y = top - 30; y < top + 10; y++) {
        for (var x = 160; x < 320; x++) {
          if (near(r.at(x, y), look.palette.skin)) skinAbove++;
        }
      }
      expect(skinAbove, greaterThan(50));
      expect(r.count(look.palette.cardigan), greaterThan(200));
    });

    test('the rock look gloves only the right hand', () async {
      const look = CompanionLook.grandmaRock;
      final right = await _body((c, f) => drawArm(c, f, look, raised, 1));
      final left = await _body(
        (c, f) => drawArm(c, f, look, const CompanionPose().left, -1),
      );
      expect(right.count(look.palette.glove, tolerance: 2), greaterThan(100));
      expect(left.count(look.palette.glove, tolerance: 2), 0);
    });
  });
}
