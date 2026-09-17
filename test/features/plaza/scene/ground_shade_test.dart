import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/plaza/scene/ground_shade.dart';
import 'package:lotti/features/plaza/ui/plaza_palette.dart';

/// The day palette with one light setting changed, so a branch can be
/// reached without inventing a whole hour.
PlazaPalette _dayWith({required double shadowAlpha}) {
  const day = PlazaPalette.day;
  final lights = day.lights;
  return PlazaPalette(
    mode: day.mode,
    sky: day.sky,
    air: day.air,
    surfaces: day.surfaces,
    lights: PlazaLightSettings(
      emissiveBoost: lights.emissiveBoost,
      groundLightScale: lights.groundLightScale,
      glowScale: lights.glowScale,
      lampsLit: lights.lampsLit,
      shadowAlpha: shadowAlpha,
      shadow: lights.shadow,
      lamp: lights.lamp,
      interior: lights.interior,
      parade: lights.parade,
      skyGlow: lights.skyGlow,
      warning: lights.warning,
    ),
    lanterns: day.lanterns,
  );
}

const _footX = 30.0;
const _footZ = -40.0;

List<ShadeQuad> _quads(
  PlazaPalette palette, {
  double width = 12,
  double depth = 8,
  double height = 20,
  bool contact = true,
}) => shadeQuadsFor(
  palette,
  x: _footX,
  z: _footZ,
  width: width,
  depth: depth,
  height: height,
  contact: contact,
);

void main() {
  group('when nothing is cast', () {
    test('night plans no shade: there is no sun to throw it', () {
      expect(PlazaPalette.night.sky.hasSun, isFalse);
      expect(_quads(PlazaPalette.night), isEmpty);
    });

    test('an hour with a sun but no shadow opacity plans none either', () {
      final sunlitButShadeless = _dayWith(shadowAlpha: 0);
      expect(sunlitButShadeless.sky.hasSun, isTrue);
      expect(_quads(sunlitButShadeless), isEmpty);
    });

    test('a caster with no height throws nothing', () {
      expect(_quads(PlazaPalette.day, height: 0), isEmpty);
    });
  });

  test('a daylight caster gets a contact pad and then a cast streak', () {
    final quads = _quads(PlazaPalette.day);
    expect(quads, hasLength(2));
    expect(quads.first.yaw, 0);
    expect(quads.last.yaw, isNot(0));
  });

  group('the contact pad', () {
    test('sits on the footprint, square to the sun, at full density', () {
      final pad = _quads(PlazaPalette.day).first;
      expect(pad.x, _footX);
      expect(pad.z, _footZ);
      expect(pad.yaw, 0);
      expect(pad.alpha, PlazaPalette.day.lights.shadowAlpha);
    });

    test('takes the larger footprint side, whichever it is', () {
      // ignore: avoid_redundant_argument_values
      final wide = _quads(PlazaPalette.day, width: 12, depth: 8).first;
      final deep = _quads(PlazaPalette.day, width: 8, depth: 12).first;
      for (final pad in [wide, deep]) {
        expect(pad.width, closeTo(12 * shadeContactSpread, 1e-12));
        expect(pad.length, closeTo(12 * shadeContactSpread, 1e-12));
      }
      expect(shadeContactSpread, greaterThan(1));
    });

    test('is left out for a caster standing on posts', () {
      final quads = _quads(PlazaPalette.day, contact: false);
      expect(quads, hasLength(1));
      // What remains is the streak, not a pad renamed.
      expect(quads.single.yaw, PlazaPalette.day.sky.sunAzimuth + math.pi);
    });
  });

  group('the cast streak', () {
    test('runs away from the sun, its centre half a shadow-length out', () {
      final sky = PlazaPalette.day.sky;
      final streak = _quads(PlazaPalette.day).last;
      final length = sky.shadowLength(20);
      final cast = sky.sunAzimuth + math.pi;
      expect(streak.yaw, cast);
      expect(streak.x, closeTo(_footX + math.sin(cast) * length / 2, 1e-9));
      expect(streak.z, closeTo(_footZ + math.cos(cast) * length / 2, 1e-9));
      // Away from the sun: the offset from the foot points against the
      // sun's own direction on the ground.
      final sun = sky.sunDirection;
      final along = (streak.x - _footX) * sun.x + (streak.z - _footZ) * sun.z;
      expect(along, lessThan(0));
    });

    test('is the footprint plus the shadow length long, and a shade wider', () {
      final streak = _quads(PlazaPalette.day).last;
      final length = PlazaPalette.day.sky.shadowLength(20);
      expect(streak.length, closeTo(12 + length, 1e-12));
      expect(streak.width, closeTo(12 * shadeStreakSpread, 1e-12));
      expect(shadeStreakSpread, greaterThan(1));
    });

    test('carries a lighter share of the pad density', () {
      final quads = _quads(PlazaPalette.day);
      expect(shadeCastShare, inExclusiveRange(0, 1));
      expect(
        quads.last.alpha,
        closeTo(quads.first.alpha * shadeCastShare, 1e-12),
      );
    });

    test('a tower is clamped: its streak grows no further than the cap', () {
      final short = _quads(PlazaPalette.day, height: 4).last;
      final tower = _quads(PlazaPalette.day, height: 400).last;
      expect(tower.length, 12 + PlazaSky.maxShadowLength);
      expect(tower.length, greaterThan(short.length));
    });
  });
}
