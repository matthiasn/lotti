import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/animal_head_painter.dart';

import '../companion_test_utils.dart';

/// Head-local units at three times their size, the face's centre at (150,
/// 170) of a 300 px square.
Future<Raster> _draw(void Function(Canvas canvas) draw) =>
    Raster.of(300, 300, (canvas) {
      canvas
        ..translate(150, 170)
        ..scale(1.5);
      draw(canvas);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('animalHeadPath', () {
    test("the red panda's head is wider than the cat's", () {
      final cat = animalHeadPath(CompanionSpecies.cat, 0).getBounds();
      final panda = animalHeadPath(CompanionSpecies.redPanda, 0).getBounds();
      expect(panda.width, greaterThan(cat.width + 10));
      // Symmetric when facing ahead.
      expect(cat.center.dx, closeTo(0, 0.5));
    });

    test('a turned head narrows on the far side', () {
      final ahead = animalHeadPath(CompanionSpecies.cat, 0).getBounds();
      final turned = animalHeadPath(CompanionSpecies.cat, 1).getBounds();
      expect(turned.right, lessThan(ahead.right));
    });
  });

  group('drawEars', () {
    test("the cat's ears stand above its head, pink inside", () async {
      const look = CompanionLook.cat;
      final r = await _draw(
        (c) => drawEars(c, look, const CompanionPose()),
      );
      final inner = look.palette.earInner!;
      expect(r.count(inner), greaterThan(300));
      // Above the crown (y -57 in head units, 84 px on this canvas).
      expect(r.centroid(inner)!.dy, lessThan(170 - 57 * 1.5));
    });

    test("the red panda's ears are rimmed in white", () async {
      const look = CompanionLook.redPanda;
      final r = await _draw(
        (c) => drawEars(c, look, const CompanionPose()),
      );
      expect(r.count(look.palette.muzzleColor), greaterThan(200));
      expect(r.count(look.palette.earInner!), greaterThan(200));
    });

    test('a flick turns only the ear it names', () async {
      const look = CompanionLook.cat;
      final inner = look.palette.earInner!;
      final rest = await _draw(
        (c) => drawEars(c, look, const CompanionPose()),
      );
      final right = await _draw(
        (c) => drawEars(c, look, const CompanionPose(earFlick: 1)),
      );
      final left = await _draw(
        (c) => drawEars(c, look, const CompanionPose(earFlick: -1)),
      );
      // Each centroid is both ears' mean: a flick outward pulls it toward
      // the flicked ear's side.
      final x = rest.centroid(inner)!.dx;
      expect(right.centroid(inner)!.dx, greaterThan(x + 2));
      expect(left.centroid(inner)!.dx, lessThan(x - 2));
    });
  });

  group('drawAnimalFace', () {
    test(
      'the cat: fur, a white muzzle, green slit-pupil eyes, a pink nose',
      () async {
        const look = CompanionLook.cat;
        final p = look.palette;
        final r = await _draw(
          (c) => drawAnimalFace(c, look, const CompanionPose()),
        );
        expect(r.count(p.skin), greaterThan(4000));
        expect(r.count(p.muzzleColor), greaterThan(800));
        expect(r.count(p.nose!), greaterThan(30));
        expect(r.count(p.iris, tolerance: 20), greaterThan(60));
        expect(r.count(p.furMarkColor, tolerance: 12), greaterThan(80));
      },
    );

    test(
      'the red panda: white cheeks and brow spots, dark tear marks',
      () async {
        const look = CompanionLook.redPanda;
        final p = look.palette;
        final r = await _draw(
          (c) => drawAnimalFace(c, look, const CompanionPose()),
        );
        expect(r.count(p.muzzleColor), greaterThan(2500));
        expect(r.count(p.furMarkColor), greaterThan(150));
        expect(r.count(p.nose!), greaterThan(60));
        // A brow spot sits above each eye: white pixels high on the face.
        expect(r.at(150 + 22 * 1.5, 170 - 30 * 1.5), p.muzzleColor);
      },
    );

    test('a blink closes its eyes, a turn moves its face', () async {
      const look = CompanionLook.cat;
      final p = look.palette;
      final open = await _draw(
        (c) => drawAnimalFace(c, look, const CompanionPose()),
      );
      final shut = await _draw(
        (c) => drawAnimalFace(c, look, const CompanionPose(blink: 1)),
      );
      final turned = await _draw(
        (c) => drawAnimalFace(c, look, const CompanionPose(headYaw: 1)),
      );
      // Its green irises; the eyes' whites match its muzzle too closely to
      // count.
      expect(shut.count(p.iris, tolerance: 20), 0);
      expect(open.count(p.iris, tolerance: 20), greaterThan(60));
      expect(
        turned.centroid(p.nose!)!.dx,
        greaterThan(open.centroid(p.nose!)!.dx + 5),
      );
    });
  });
}
