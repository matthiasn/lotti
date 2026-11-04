import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_parts.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
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

  test("she wears her look's hairstyle, front and back", () async {
    const bun = CompanionLook.grandma;
    final afro = bun.copyWith(hairStyle: CompanionHairStyle.afro);
    final withBun = await _head(bun);
    final withAfro = await _head(afro);
    // The afro is far more hair, behind and over the head: counted in
    // either tone, as its coils mix the two.
    int hair(Raster r) =>
        r.count(bun.palette.hairBack, tolerance: 20) +
        r.count(bun.palette.hair, tolerance: 20);
    expect(hair(withAfro), greaterThan(hair(withBun) + 4000));
    expect(
      withAfro.count(bun.palette.hair, tolerance: 30),
      greaterThan(withBun.count(bun.palette.hair, tolerance: 30)),
    );
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

  group('the grandpa', () {
    /// How many pixels of [colour] lie below head-local [y].
    int below(Raster r, Color colour, double y, {int tolerance = 20}) {
      var n = 0;
      for (var py = (260 + y * 2).round(); py < 480; py++) {
        for (var x = 0; x < 480; x++) {
          if (near(r.at(x, py), colour, tolerance: tolerance)) n++;
        }
      }
      return n;
    }

    test(
      'wears his readers low on the nose, Lotti hers round her eyes',
      () async {
        Future<double> drop(CompanionLook look) async {
          final r = await _head(look);
          return r.centroid(look.palette.glasses)!.dy -
              r.centroid(look.palette.eyeWhite)!.dy;
        }

        expect(
          await drop(CompanionLook.grandpa),
          greaterThan(await drop(CompanionLook.grandma) + 4),
        );
      },
    );

    test(
      'has a beard below the nose; Lotti, in the same short hair, none',
      () async {
        const his = CompanionLook.grandpa;
        final lotti = CompanionLook.grandma.copyWith(
          hairStyle: CompanionHairStyle.short,
        );
        // Her pearls are near the silver of the hair: a few pixels, not a
        // beard's thousands.
        expect(
          below(await _head(his), his.palette.hair, 12),
          greaterThan(below(await _head(lotti), lotti.palette.hair, 12) + 1500),
        );
      },
    );

    test('still shows his mouth through the beard', () async {
      const look = CompanionLook.grandpa;
      final r = await _head(
        look,
        pose: CompanionPose(mouth: Viseme.d.shape),
      );
      expect(r.count(look.palette.mouthIn, tolerance: 10), greaterThan(40));
    });

    test('wears the moustache over his lip', () async {
      final r = await _head(CompanionLook.grandpa);
      // Head-local (0, 15): between the nose and the mouth.
      expect(
        near(
          r.at(240, 260 + 30),
          CompanionLook.grandpa.palette.hair,
          tolerance: 30,
        ),
        isTrue,
      );
    });

    test('wears the flat cap to market only', () async {
      const market = CompanionLook.grandpaMarket;
      // A grey near the cap's blends at a few hair edges without one.
      final cap = market.palette.cap;
      expect(
        (await _head(market)).count(cap),
        greaterThan((await _head(CompanionLook.grandpa)).count(cap) + 1500),
      );
    });
  });

  group('the aunt', () {
    const aunt = CompanionLook.aunt;

    test('wears gold hoops and no glasses', () async {
      final r = await _head(aunt);
      expect(r.count(aunt.palette.earring, tolerance: 12), greaterThan(40));
      // Bare skin where Lotti's frames cross the bridge of the nose.
      expect(
        near(r.at(240, 260 - 18), aunt.palette.skin, tolerance: 8),
        isTrue,
      );
      final lotti = await _head(CompanionLook.grandma);
      expect(
        near(lotti.at(240, 260 - 18), aunt.palette.skin, tolerance: 8),
        isFalse,
      );
    });

    test('has no laugh lines beside her mouth; Lotti does', () async {
      /// Pixels off the bare skin beside the mouth, head-local x 16..23,
      /// y 14..32 on both sides.
      Future<int> creases(CompanionLook look) async {
        final r = await _head(look);
        var n = 0;
        for (final side in [-1, 1]) {
          for (var x = 16; x <= 23; x++) {
            for (var y = 14; y <= 32; y++) {
              final px = r.at(240 + side * x * 2, 260 + y * 2);
              if (!near(px, look.palette.skin, tolerance: 4)) n++;
            }
          }
        }
        return n;
      }

      expect(
        await creases(aunt),
        lessThan(await creases(CompanionLook.grandma) - 10),
      );
    });

    test('has fuller brows than Lotti', () async {
      final hers = (await _head(aunt)).count(aunt.palette.brow);
      final lottis = (await _head(CompanionLook.grandma)).count(
        CompanionLook.grandma.palette.brow,
      );
      expect(hers, greaterThan(lottis * 1.2));
    });

    test('wears the headband to the festival only', () async {
      const festival = CompanionLook.auntFestival;
      final band = festival.palette.headband;
      expect((await _head(festival)).count(band), greaterThan(500));
      expect((await _head(aunt)).count(band), 0);
    });
  });
}
