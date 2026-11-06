import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/trousers_painter.dart';

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
const _black = Color(0xFF000000);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('drawTrouserLegs', () {
    test('covers both legs from the hips to the ankles', () async {
      final r = await _body((c, f) => drawTrouserLegs(c, f, _look));
      // Canvas y of the hips (pelvis + 12) and the ankles (-20).
      const hipY = 470 + pelvisY + 12;
      const ankleY = 470 - 20;
      for (final x in [160 - 15, 160 + 15]) {
        for (var y = hipY + 6; y < ankleY - 8; y += 10) {
          expect(r.at(x, y), isNot(_black), reason: 'x $x, y $y');
        }
      }
    });

    test('leaves a gap between the ankles, as two legs do', () async {
      final r = await _body((c, f) => drawTrouserLegs(c, f, _look));
      expect(r.at(160, 470 - 40), _black);
    });

    test('puts the far leg in shade and the near one in the light', () async {
      final r = await _body((c, f) => drawTrouserLegs(c, f, _look));
      final left = r.at(160 - 24, 380);
      final right = r.at(160 + 24, 380);
      expect(near(left, _c.trousers, tolerance: 2), isTrue);
      expect(right.computeLuminance(), lessThan(left.computeLuminance()));
    });

    test('stands in brogues on the floor, no bare instep', () async {
      final r = await _body((c, f) => drawTrouserLegs(c, f, _look));
      expect(r.count(_c.shoe), greaterThan(150));
      expect(r.centroid(_c.shoe)!.dy, greaterThan(445));
      expect(r.count(_c.sole), greaterThan(40));
      expect(r.count(_c.skin), 0);
    });

    test('the brogues face outwards, each its own way', () async {
      final r = await _body((c, f) => drawTrouserLegs(c, f, _look));
      var left = 0;
      var right = 0;
      for (var y = 440; y < 480; y++) {
        for (var x = 0; x < 320; x++) {
          if (!near(r.at(x, y), _c.shoe)) continue;
          if (x < 160 - 30) left++;
          if (x > 160 + 30) right++;
        }
      }
      expect(left, greaterThan(10));
      expect(right, greaterThan(10));
    });
  });

  group('drawTrouserTop', () {
    test(
      'draws the seat between the waist and the hips, its band darker',
      () async {
        final r = await _body((c, f) => drawTrouserTop(c, f, _c));
        expect(r.count(_c.trousers), greaterThan(1500));
        // The band sits at the waist, 36 to 28 above the pelvis.
        const bandY = 470 + pelvisY - 32;
        expect(near(r.at(160 - 20, bandY), _c.trousersShade), isTrue);
        expect(r.at(160, 470 + pelvisY - 50), _black);
      },
    );

    test('rides up with a bounce of joy, a little', () async {
      Future<double> seatTop(double lift) async {
        final r = await _body(
          (c, f) => drawTrouserTop(c, f, _c),
          pose: CompanionPose(lift: lift),
        );
        for (var y = 0; y < 480; y++) {
          if (!near(r.at(160 - 20, y), _black)) return y.toDouble();
        }
        return 480;
      }

      final rest = await seatTop(0);
      final lifted = await seatTop(6);
      expect(lifted, lessThan(rest));
      expect(rest - lifted, lessThan(6));
    });

    test('never parts from the legs, at the biggest bounce', () async {
      for (final lift in [0.0, 3.0, 6.0]) {
        final r = await _body((c, f) {
          drawTrouserLegs(c, f, _look);
          drawTrouserTop(c, f, _c);
        }, pose: CompanionPose(lift: lift));
        // Down each leg, from the waistband to the ankle: no black.
        for (final x in [160 - 15, 160 + 15]) {
          for (var y = 470 + pelvisY - 34; y < 470 - 28; y += 2) {
            expect(r.at(x, y), isNot(_black), reason: 'lift $lift, y $y');
          }
        }
      }
    });
  });

  group('tuckedTopPath', () {
    test("rises at the shoulder of an arm that lifts, and only that one's", () {
      final rest = tuckedTopPath(RigFrame(const CompanionPose())).getBounds();
      final lifted = tuckedTopPath(
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

    test('ends inside the waistband, so its hem is always tucked', () {
      final hem = tuckedTopPath(RigFrame(const CompanionPose())).getBounds();
      // The band runs from 36 to 28 above the pelvis; the hem is lower.
      expect(hem.bottom, greaterThan(pelvisY - 28));
      expect(hem.bottom, lessThan(pelvisY));
    });
  });

  group('the shoes', () {
    const aunt = CompanionLook.aunt;

    /// The highest canvas row [colour] reaches near the floor.
    int top(Raster r, Color colour) {
      for (var y = 380; y < 480; y++) {
        for (var x = 0; x < 320; x++) {
          if (near(r.at(x, y), colour)) return y;
        }
      }
      return 480;
    }

    test(
      "are the character's: high-tops for the aunt, brogues for him",
      () async {
        final his = await _body((c, f) => drawTrouserLegs(c, f, _look));
        final hers = await _body((c, f) => drawTrouserLegs(c, f, aunt));
        // A high-top reaches well above a brogue, over the ankle.
        expect(
          top(hers, aunt.palette.shoe),
          lessThan(top(his, _c.shoe) - 8),
        );
        // Its thick rubber sole, and no leather sole.
        expect(hers.count(const Color(0xFFF7F5F0)), greaterThan(80));
        // An edge pixel or two may blend near it; a brogue's sole is dozens.
        expect(hers.count(aunt.palette.sole), lessThan(10));
        expect(his.count(_c.sole), greaterThan(40));
      },
    );

    test('her suit legs are her suit colour', () async {
      final r = await _body((c, f) => drawTrouserLegs(c, f, aunt));
      expect(r.count(aunt.palette.trousers), greaterThan(1500));
    });
  });

  group("the uncle's chinos", () {
    const uncle = CompanionLook.uncle;
    final p = uncle.palette;

    test(
      'are turned up above his boots; nobody else turns theirs up',
      () async {
        final his = await _body((c, f) => drawTrouserLegs(c, f, uncle));
        final hers = await _body(
          (c, f) => drawTrouserLegs(c, f, CompanionLook.aunt),
        );
        // The turn-up band, both legs, just above the shoes.
        const bandY = 470 - 20 + 2 - 12;
        expect(near(his.at(160 - 19, bandY), p.trousersLight), isTrue);
        expect(near(his.at(160 + 19, bandY), p.trousersLight), isTrue);
        expect(
          near(
            hers.at(160 - 19, bandY),
            CompanionLook.aunt.palette.trousersLight,
          ),
          isFalse,
        );
      },
    );

    test('end in boots on a treaded sole, lower than high-tops', () async {
      final his = await _body((c, f) => drawTrouserLegs(c, f, uncle));
      expect(his.count(p.shoe), greaterThan(150));
      expect(his.count(const Color(0xFF2B2622)), greaterThan(150));
      int top(Raster r, Color colour) {
        for (var y = 380; y < 480; y++) {
          for (var x = 0; x < 320; x++) {
            if (near(r.at(x, y), colour)) return y;
          }
        }
        return 480;
      }

      final hers = await _body(
        (c, f) => drawTrouserLegs(c, f, CompanionLook.aunt),
      );
      expect(
        top(his, p.shoe),
        greaterThan(top(hers, CompanionLook.aunt.palette.shoe)),
      );
    });
  });

  test("a broad top is a man's: squarer shoulders, straight sides", () {
    final f = RigFrame(const CompanionPose());
    final hers = tuckedTopPath(f).getBounds();
    final his = tuckedTopPath(f, broad: true).getBounds();
    expect(his.width, greaterThan(hers.width + 5));
    // Straight sides: at the waist the broad top keeps more of its width.
    /// How far right the top reaches at torso height -44, the waist.
    double waist(Path p) {
      var right = 0.0;
      for (var x = 0.0; x < 80; x += 0.5) {
        if (p.contains(Offset(x, pelvisY - 44))) right = x;
      }
      return right;
    }

    expect(
      waist(tuckedTopPath(f, broad: true)),
      greaterThan(waist(tuckedTopPath(f)) + 3),
    );
  });
}
