import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/model/companion_look.dart';
import 'package:lotti/features/companion/model/companion_pose.dart';
import 'package:lotti/features/companion/rig/rig_frame.dart';
import 'package:lotti/features/companion/rig/tail_painter.dart';

import '../companion_test_utils.dart';

/// Character space, 1:1, origin at the bottom middle of a 320 × 480 canvas.
Future<Raster> _tail(CompanionLook look, {CompanionPose? pose}) =>
    Raster.of(320, 480, (canvas) {
      canvas.translate(160, 470);
      drawTail(canvas, RigFrame(pose ?? const CompanionPose()), look);
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('tailSpine', () {
    test('a swing turns the tip more than the root', () {
      final rest = tailSpine(
        RigFrame(const CompanionPose()),
        CompanionSpecies.cat,
      );
      final swung = tailSpine(
        RigFrame(const CompanionPose(tail: 1)),
        CompanionSpecies.cat,
      );
      expect(swung.first, rest.first);
      final moved = [
        for (var i = 0; i < rest.length; i++) (swung[i] - rest[i]).distance,
      ];
      for (var i = 1; i < moved.length; i++) {
        expect(moved[i], greaterThan(moved[i - 1]));
      }
    });

    test('it grows from behind the hip and curls up beside the body', () {
      final f = RigFrame(const CompanionPose());
      final spine = tailSpine(f, CompanionSpecies.redPanda);
      expect((spine.first - f.pelvis).distance, lessThan(20));
      expect(spine.last.dy, lessThan(f.pelvis.dy - 50));
      expect(spine.last.dx, greaterThan(f.pelvis.dx + 60));
    });
  });

  test('the grandmother has no tail', () async {
    final r = await _tail(CompanionLook.grandma);
    expect(r.at(160 + 90, 470 - 178), const Color(0xFF000000));
    expect(r.count(const Color(0xFF000000)), 320 * 480);
  });

  test("the red panda's tail is thick and ringed", () async {
    const look = CompanionLook.redPanda;
    final r = await _tail(look);
    expect(r.count(look.palette.tailColor), greaterThan(1500));
    expect(
      r.count(look.palette.tailRingColor, tolerance: 12),
      greaterThan(800),
    );
  });

  test("the cat's tail is thin, with a dark tip", () async {
    const look = CompanionLook.cat;
    final cat = await _tail(look);
    final panda = await _tail(CompanionLook.redPanda);
    final catPixels = 320 * 480 - cat.count(const Color(0xFF000000));
    final pandaPixels = 320 * 480 - panda.count(const Color(0xFF000000));
    expect(catPixels, lessThan(pandaPixels ~/ 2));
    expect(cat.count(look.palette.furMarkColor), greaterThan(40));
  });
}
