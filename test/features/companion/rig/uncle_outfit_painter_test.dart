import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/body_painter.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/uncle_outfit_painter.dart';

import '../companion_test_utils.dart';

/// Character space, 1:1, origin at the bottom middle of a 320 × 480 canvas.
Future<Raster> _body(void Function(Canvas canvas, RigFrame f) draw) =>
    Raster.of(320, 480, (canvas) {
      canvas.translate(160, 470);
      draw(canvas, RigFrame(const CompanionPose()));
    });

const CompanionLook _look = CompanionLook.uncle;
final CompanionPalette _c = _look.palette;

/// Canvas y of a torso-frame height, standing.
double _y(double torsoY) => 470 + pelvisY + torsoY;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('drawUncleOutfit', () {
    test('the jacket open on both sides, the tee down the middle', () async {
      final r = await _body((c, f) => drawUncleOutfit(c, f, _look));
      expect(near(r.at(160, _y(-60)), _c.shirt), isTrue);
      expect(near(r.at(160 - 30, _y(-60)), _c.jacket, tolerance: 20), isTrue);
      expect(near(r.at(160 + 30, _y(-60)), _c.jacket, tolerance: 30), isTrue);
    });

    test('ribbed at the hem, low on the hip, both sides', () async {
      final r = await _body((c, f) => drawUncleOutfit(c, f, _look));
      for (final x in [160 - 28, 160 + 28]) {
        final hem = r.at(x, _y(6));
        expect(
          near(hem, _c.rib, tolerance: 30),
          isTrue,
          reason: 'x $x',
        );
      }
    });

    test('headphones rest on both collarbones', () async {
      final r = await _body((c, f) => drawUncleOutfit(c, f, _look));
      var left = 0;
      var right = 0;
      for (var y = _y(-125).round(); y < _y(-95); y++) {
        for (var x = 0; x < 320; x++) {
          if (!near(r.at(x, y), _c.headphones)) continue;
          x < 160 ? left++ : right++;
        }
      }
      expect(left, greaterThan(60));
      expect(right, greaterThan(60));
    });

    test("wears nothing of Lotti's, the grandpa's or the aunt's", () async {
      final r = await _body((c, f) => drawUncleOutfit(c, f, _look));
      for (final colour in [
        _c.dress,
        _c.cardigan,
        _c.scarf,
        _c.braces,
        _c.bowTie,
        _c.belt,
      ]) {
        expect(r.count(colour), 0, reason: '$colour');
      }
    });

    test('each outfit wears its own jacket and tee', () async {
      for (final look in CompanionLook.of(CompanionSpecies.uncle)) {
        final p = look.palette;
        final r = await _body((c, f) => drawUncleOutfit(c, f, look));
        expect(r.count(p.jacket), greaterThan(1000), reason: look.id);
        expect(r.count(p.shirt), greaterThan(300), reason: look.id);
      }
    });
  });

  group('the outlines', () {
    test('the tee hangs untucked, to the hip', () {
      final tee = teePath(RigFrame(const CompanionPose())).getBounds();
      expect(tee.bottom, closeTo(pelvisY + 6, 0.5));
    });

    test("a jacket front rises with its own arm's lift only", () {
      CompanionPose lifted(double lift) => CompanionPose(
        right: ArmPose(
          wrist: const CompanionPose().right.wrist,
          handAngle: 0,
          lift: lift,
        ),
      );
      double top(int side, double lift) =>
          jacketPanelPath(RigFrame(lifted(lift)), side).getBounds().top;
      expect(top(1, 10), lessThan(top(1, 0) - 5));
      expect(top(-1, 10), top(-1, 0));
    });
  });

  group('drawJacketSleeve', () {
    // A straight arm along x: root, shoulder, elbow, wrist.
    const spine = [Offset.zero, Offset(20, 0), Offset(80, 0), Offset(140, 0)];

    Future<Raster> sleeve() => Raster.of(200, 60, (canvas) {
      canvas.translate(20, 30);
      drawJacketSleeve(canvas, spine, 1, _c, tension: armTension);
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

    test('runs down to the wrist, ending in a ribbed cuff', () async {
      final r = await sleeve();
      final cuffEnd = reach(r, _c.rib);
      // Close to the wrist at 140, leaving the hand bare.
      expect(cuffEnd, inInclusiveRange(125, 139));
      expect(reach(r, _c.jacket), lessThan(cuffEnd));
    });

    test('the cuff gathers narrower than the sleeve', () async {
      final r = await sleeve();
      int height(int x, Color colour) => [
        for (var y = 0; y < 60; y++)
          if (near(r.at(x, y), colour)) y,
      ].length;
      final cuff = [
        for (var x = 0; x < 200; x++) height(x, _c.rib),
      ].reduce((a, b) => a > b ? a : b);
      expect(cuff, lessThan(height(20 + 50, _c.jacket)));
      expect(cuff, greaterThan(6));
    });
  });
}
