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

  test("an animal stands on paws, in its limbs' colour, without shoes", () {
    return Future.wait([
      for (final look in [CompanionLook.cat, CompanionLook.redPanda])
        _body((c, f) => drawLegs(c, f, look)).then((r) {
          final p = look.palette;
          expect(r.count(p.shoe), 0, reason: look.id);
          expect(r.count(p.pawColor), greaterThan(100), reason: look.id);
          expect(r.centroid(p.pawColor)!.dy, greaterThan(410), reason: look.id);
        }),
    ]);
  });

  test("an animal's arms are its limbs and its hands its paws", () async {
    const look = CompanionLook.redPanda;
    final r = await _body(
      (c, f) => drawArm(c, f, look, const CompanionPose().right, 1),
    );
    expect(r.count(look.palette.limbColor), greaterThan(200));
    expect(r.count(look.palette.skin), 0);
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
        // The grandpa wears no dress; his clothes are their own painter's.
        if (look.species == CompanionSpecies.grandpa) continue;
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

  group('the grandpa', () {
    const look = CompanionLook.grandpa;
    final p = look.palette;

    test('stands in trousers and brogues, with no bare leg', () async {
      final r = await _body((c, f) => drawLegs(c, f, look));
      expect(r.count(p.trousers), greaterThan(1500));
      expect(r.count(p.shoe), greaterThan(100));
      expect(r.centroid(p.shoe)!.dy, greaterThan(440));
      expect(r.count(p.skin), 0);
    });

    test('wears his shirt sleeve rolled past the elbow, his forearm bare, no '
        'cardigan', () async {
      final r = await _body(
        (c, f) => drawArm(c, f, look, const CompanionPose().right, 1),
      );
      expect(r.count(p.shirt), greaterThan(200));
      expect(r.count(p.shirtLight), greaterThan(30));
      expect(r.count(p.cardigan), 0);
      expect(r.count(p.skin), greaterThan(100));
    });
  });

  test("Lotti's sleeve is her cardigan's, never a shirt's", () async {
    const look = CompanionLook.grandma;
    final r = await _body(
      (c, f) => drawArm(c, f, look, const CompanionPose().right, 1),
    );
    expect(r.count(look.palette.cardigan), greaterThan(200));
    expect(r.count(look.palette.shirt), 0);
  });

  group('the aunt', () {
    const look = CompanionLook.aunt;
    final p = look.palette;

    test('stands in her suit legs and high-tops, no bare leg', () async {
      final r = await _body((c, f) => drawLegs(c, f, look));
      expect(r.count(p.trousers), greaterThan(1500));
      expect(r.count(p.shoe), greaterThan(150));
      expect(r.count(p.skin), 0);
    });

    test(
      'bares more arm than the grandpa: her sleeve stops above the elbow',
      () async {
        Future<int> skin(CompanionLook l) async => (await _body(
          (c, f) => drawArm(c, f, l, const CompanionPose().right, 1),
        )).count(l.palette.skin);
        expect(
          await skin(look),
          greaterThan(await skin(CompanionLook.grandpa)),
        );
        final r = await _body(
          (c, f) => drawArm(c, f, look, const CompanionPose().right, 1),
        );
        expect(r.count(p.trousersLight), greaterThan(30));
        expect(r.count(p.shirt), 0);
      },
    );
  });

  group('the uncle', () {
    const look = CompanionLook.uncle;
    final p = look.palette;

    test('stands in chinos and boots, no bare leg', () async {
      final r = await _body((c, f) => drawLegs(c, f, look));
      expect(r.count(p.trousers), greaterThan(1500));
      expect(r.count(p.shoe), greaterThan(150));
      expect(r.count(p.skin), 0);
    });

    test('his jacket sleeve covers his arm to the wrist: less bare arm than '
        'the aunt', () async {
      Future<int> skin(CompanionLook l) async => (await _body(
        (c, f) => drawArm(c, f, l, const CompanionPose().right, 1),
      )).count(l.palette.skin);
      expect(await skin(look), lessThan(await skin(CompanionLook.aunt)));
      final r = await _body(
        (c, f) => drawArm(c, f, look, const CompanionPose().right, 1),
      );
      expect(r.count(p.jacket, tolerance: 20), greaterThan(300));
      expect(r.count(p.rib), greaterThan(20));
    });
  });
}
