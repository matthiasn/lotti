import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/head_painter.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';

import '../companion_test_utils.dart';

/// The head at twice its size, framed in a 480 px square.
Future<Raster> _head(CompanionLook look, {CompanionPose? pose}) {
  final f = RigFrame(pose ?? const CompanionPose());
  return Raster.of(480, 480, (canvas) {
    canvas
      ..translate(240, 260)
      ..scale(2)
      ..translate(-f.head.origin.dx, -f.head.origin.dy);
    drawBackOfHead(canvas, f, look);
    drawHead(canvas, f, look);
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the face path narrows on the side she turns from', () {
    final ahead = facePath(0).getBounds();
    final turned = facePath(1).getBounds();
    expect(ahead.width, closeTo(90, 1e-6));
    expect(turned.right, lessThan(ahead.right));
  });

  test('her everyday face: skin, both eyes, glasses and pearls', () async {
    const look = CompanionLook.grandma;
    final r = await _head(look);
    expect(r.count(look.palette.skin), greaterThan(2000));
    expect(r.count(look.palette.eyeWhite), greaterThan(40));
    expect(r.count(look.palette.glasses), greaterThan(100));
    expect(r.count(look.palette.pearl), greaterThan(4));
    expect(r.count(look.palette.hat), 0);
    expect(r.count(look.palette.lens), 0);
  });

  test(
    'the rock look wears the beret and dark lenses, not the glasses',
    () async {
      const look = CompanionLook.grandmaRock;
      final r = await _head(look);
      expect(r.count(look.palette.hat), greaterThan(500));
      expect(r.count(look.palette.lens, tolerance: 12), greaterThan(200));
      // Behind dark lenses the whites of the eyes do not show.
      expect(r.count(look.palette.eyeWhite), 0);
      expect(r.count(look.palette.glasses), greaterThan(100));
    },
  );

  test('a brow skew raises her right brow and lowers the left', () async {
    const look = CompanionLook.grandma;
    // The brows' heights, each from its own half of the face.
    Future<(double, double)> brows(double skew) async {
      final r = await _head(look, pose: CompanionPose(browSkew: skew));
      double? at({required bool right}) {
        var sum = 0.0;
        var n = 0;
        for (var y = 120; y < 240; y++) {
          for (var x = right ? 245 : 140; x < (right ? 340 : 235); x++) {
            if (near(r.at(x, y), look.palette.brow)) {
              sum += y;
              n++;
            }
          }
        }
        return n == 0 ? null : sum / n;
      }

      return (at(right: false)!, at(right: true)!);
    }

    final (left, right) = await brows(0);
    final (skewLeft, skewRight) = await brows(1.5);
    expect(skewRight, lessThan(right - 4));
    expect(skewLeft, greaterThan(left + 4));
  });

  test('a blink closes both eyes', () async {
    const look = CompanionLook.grandma;
    final open = await _head(look);
    final shut = await _head(look, pose: const CompanionPose(blink: 1));
    // A few pale pixels of the pearls' and lenses' highlights remain.
    expect(
      shut.count(look.palette.eyeWhite),
      lessThan(open.count(look.palette.eyeWhite) ~/ 10),
    );
  });

  test('a turned head moves the features with it', () async {
    const look = CompanionLook.grandma;
    final ahead = await _head(look);
    final turned = await _head(look, pose: const CompanionPose(headYaw: 1));
    expect(
      turned.centroid(look.palette.eyeWhite)!.dx,
      greaterThan(ahead.centroid(look.palette.eyeWhite)!.dx + 3),
    );
  });

  test('an animal has ears and fur where she has hair', () async {
    final hair = (await _head(
      CompanionLook.grandma,
    )).count(CompanionLook.grandma.palette.hair);
    for (final look in [CompanionLook.cat, CompanionLook.redPanda]) {
      final r = await _head(look);
      final p = look.palette;
      expect(r.count(p.skin), greaterThan(4000), reason: look.id);
      expect(r.count(p.earInner!), greaterThan(300), reason: look.id);
      // Only stray anti-aliased pixels land on the hair's colour.
      expect(r.count(p.hair), lessThan(hair ~/ 20), reason: look.id);
    }
  });

  test('glasses and the beret sit on an animal too', () async {
    final bookish = await _head(CompanionLook.redPandaBookish);
    expect(
      bookish.count(CompanionLook.redPandaBookish.palette.glasses),
      greaterThan(100),
    );
    final rock = await _head(CompanionLook.catRock);
    expect(rock.count(CompanionLook.catRock.palette.hat), greaterThan(500));
  });

  test("the red panda's head is drawn bigger", () async {
    final cat = await _head(CompanionLook.cat);
    final panda = await _head(CompanionLook.redPanda);
    expect(
      panda.count(CompanionLook.redPanda.palette.skin) +
          panda.count(CompanionLook.redPanda.palette.muzzleColor),
      greaterThan(
        cat.count(CompanionLook.cat.palette.skin) +
            cat.count(CompanionLook.cat.palette.muzzleColor),
      ),
    );
  });
}
