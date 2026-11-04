import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/body_painter.dart';
import 'package:lotti/features/companion/rig/grandpa_outfit_painter.dart';
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

const CompanionLook _look = CompanionLook.grandpa;
final CompanionPalette _c = _look.palette;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('drawGrandpaOutfit', () {
    test('a shirt with braces and a bow tie, tucked into trousers', () async {
      final r = await _body((c, f) => drawGrandpaOutfit(c, f, _look));
      expect(r.count(_c.shirt), greaterThan(2000));
      expect(r.count(_c.braces), greaterThan(150));
      expect(r.count(_c.bowTie), greaterThan(60));
      expect(r.count(_c.trousers), greaterThan(800));
      // The trousers below the shirt.
      expect(
        r.centroid(_c.trousers)!.dy,
        greaterThan(r.centroid(_c.shirt)!.dy),
      );
    });

    test("wears nothing of Lotti's: no dress, cardigan or scarf", () async {
      final r = await _body((c, f) => drawGrandpaOutfit(c, f, _look));
      expect(r.count(_c.dress), 0);
      expect(r.count(_c.cardigan), 0);
      expect(r.count(_c.scarf), 0);
    });

    test('the bow tie sits at the collar, in the middle', () async {
      final r = await _body((c, f) => drawGrandpaOutfit(c, f, _look));
      final tie = r.centroid(_c.bowTie)!;
      expect(tie.dx, closeTo(160, 2));
      // The collar is 104 above the pelvis.
      expect(tie.dy, closeTo(470 + pelvisY - 104, 4));
    });

    test('one brace each side of the placket', () async {
      final r = await _body((c, f) => drawGrandpaOutfit(c, f, _look));
      var left = 0;
      var right = 0;
      for (var y = 0; y < 480; y++) {
        for (var x = 0; x < 320; x++) {
          if (!near(r.at(x, y), _c.braces)) continue;
          x < 160 ? left++ : right++;
        }
      }
      expect(left, greaterThan(60));
      expect(right, greaterThan(60));
    });

    test('each outfit wears its own shirt and bow tie', () async {
      for (final look in CompanionLook.of(CompanionSpecies.grandpa)) {
        final p = look.palette;
        final r = await _body((c, f) => drawGrandpaOutfit(c, f, look));
        expect(r.count(p.shirt), greaterThan(2000), reason: look.id);
        expect(r.count(p.bowTie), greaterThan(60), reason: look.id);
      }
    });
  });

  group('shirtPath', () {
    test("rises at the shoulder of an arm that lifts, and only that one's", () {
      final rest = shirtPath(RigFrame(const CompanionPose())).getBounds();
      final lifted = shirtPath(
        RigFrame(
          CompanionPose(
            right: ArmPose(
              wrist: const CompanionPose().right.wrist,
              handAngle: 0,
              lift: 10,
            ),
          ),
        ),
      ).getBounds();
      expect(lifted.top, lessThan(rest.top - 5));
      expect(lifted.bottom, rest.bottom);
    });
  });

  group('drawShirtSleeve', () {
    // A straight arm along x: root, shoulder, elbow, wrist.
    const spine = [Offset.zero, Offset(20, 0), Offset(80, 0), Offset(140, 0)];

    Future<Raster> sleeve() => Raster.of(200, 60, (canvas) {
      canvas.translate(20, 30);
      drawShirtSleeve(canvas, spine, 1, _c, tension: armTension);
    });

    /// The rightmost column [colour] reaches, in arm units.
    int reach(Raster r, Color colour) {
      for (var x = 199; x >= 0; x--) {
        for (var y = 0; y < 60; y++) {
          if (near(r.at(x, y), colour)) return x - 20;
        }
      }
      return -1;
    }

    test(
      'runs from the shoulder past the elbow, rolled to the forearm',
      () async {
        final r = await sleeve();
        final end = reach(r, _c.shirtLight);
        // A third of the forearm past the elbow (80), short of the wrist.
        expect(end, inInclusiveRange(95, 106));
        expect(r.count(_c.shirt), greaterThan(500));
      },
    );

    test('ends in a roll wider than the sleeve', () async {
      final r = await sleeve();
      int height(int x, Color colour) => [
        for (var y = 0; y < 60; y++)
          if (near(r.at(x, y), colour)) y,
      ].length;
      final roll = [
        for (var x = 0; x < 200; x++) height(x, _c.shirtLight),
      ].reduce((a, b) => a > b ? a : b);
      // Wider than the sleeve at mid upper arm.
      expect(roll, greaterThan(height(20 + 50, _c.shirt)));
    });
  });
}
