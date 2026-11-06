import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/aunt_outfit_painter.dart';
import 'package:lotti/features/companion/rig/body_painter.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

import '../companion_test_utils.dart';

/// Character space, 1:1, origin at the bottom middle of a 320 × 480 canvas.
Future<Raster> _body(void Function(Canvas canvas, RigFrame f) draw) =>
    Raster.of(320, 480, (canvas) {
      canvas.translate(160, 470);
      draw(canvas, RigFrame(const CompanionPose()));
    });

const CompanionLook _look = CompanionLook.aunt;
final CompanionPalette _c = _look.palette;

/// Canvas y of a torso-frame height, standing.
double _y(double torsoY) => 470 + pelvisY + torsoY;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('drawAuntOutfit', () {
    test(
      'a boiler suit in one colour from the shoulders to the seat',
      () async {
        final r = await _body((c, f) => drawAuntOutfit(c, f, _look));
        expect(r.count(_c.trousers), greaterThan(3000));
        // Above the belt and below it, the same cloth.
        expect(
          near(r.at(160 - 25, _y(-60)), _c.trousers, tolerance: 20),
          isTrue,
        );
        expect(near(r.at(160 - 25, _y(0)), _c.trousers, tolerance: 20), isTrue);
      },
    );

    test('belted at the waist, the buckle in the middle', () async {
      final r = await _body((c, f) => drawAuntOutfit(c, f, _look));
      expect(near(r.at(160 - 25, _y(-32)), _c.belt), isTrue);
      expect(near(r.at(160 + 25, _y(-32)), _c.belt), isTrue);
      expect(r.centroid(_c.belt)!.dx, closeTo(160, 1.5));
    });

    test('the pocket flap sits on the chest, beside the zip', () async {
      final r = await _body((c, f) => drawAuntOutfit(c, f, _look));
      expect(near(r.at(160 + 21, _y(-83)), _c.trousersShade), isTrue);
      expect(near(r.at(160 - 21, _y(-83)), _c.trousersShade), isFalse);
    });

    test(
      'an open collar, lighter than the suit, either side of the zip',
      () async {
        final r = await _body((c, f) => drawAuntOutfit(c, f, _look));
        expect(near(r.at(160 - 14, _y(-104)), _c.trousersLight), isTrue);
        expect(near(r.at(160 + 14, _y(-104)), _c.trousersLight), isTrue);
      },
    );

    test("wears nothing of Lotti's or the grandpa's", () async {
      final r = await _body((c, f) => drawAuntOutfit(c, f, _look));
      for (final colour in [
        _c.dress,
        _c.cardigan,
        _c.scarf,
        _c.shirt,
        _c.braces,
        _c.bowTie,
      ]) {
        expect(r.count(colour), 0, reason: '$colour');
      }
    });

    test('each outfit wears its own suit and belt', () async {
      for (final look in CompanionLook.of(CompanionSpecies.aunt)) {
        final p = look.palette;
        final r = await _body((c, f) => drawAuntOutfit(c, f, look));
        expect(r.count(p.trousers), greaterThan(3000), reason: look.id);
        expect(r.count(p.belt), greaterThan(300), reason: look.id);
      }
    });
  });

  group('drawShortSleeve', () {
    // A straight arm along x: root, shoulder, elbow, wrist.
    const spine = [Offset.zero, Offset(20, 0), Offset(80, 0), Offset(140, 0)];

    Future<Raster> sleeve() => Raster.of(200, 60, (canvas) {
      canvas.translate(20, 30);
      drawShortSleeve(canvas, spine, 1, _c, tension: armTension);
    });

    /// The rightmost arm unit [colour] reaches.
    int reach(Raster r, Color colour) {
      for (var x = 199; x >= 0; x--) {
        for (var y = 0; y < 60; y++) {
          if (near(r.at(x, y), colour)) return x - 20;
        }
      }
      return -1;
    }

    test('stops above the elbow, its end turned up in a cuff', () async {
      final r = await sleeve();
      final end = reach(r, _c.trousersLight);
      // Short of the elbow at 80, past the middle of the upper arm.
      expect(end, inInclusiveRange(55, 76));
      expect(reach(r, _c.trousers), lessThanOrEqualTo(end));
    });

    test('the cuff stands wider than the sleeve', () async {
      final r = await sleeve();
      int height(int x, Color colour) => [
        for (var y = 0; y < 60; y++)
          if (near(r.at(x, y), colour)) y,
      ].length;
      final cuff = [
        for (var x = 0; x < 200; x++) height(x, _c.trousersLight),
      ].reduce((a, b) => a > b ? a : b);
      expect(cuff, greaterThan(height(20 + 40, _c.trousers)));
    });
  });
}
