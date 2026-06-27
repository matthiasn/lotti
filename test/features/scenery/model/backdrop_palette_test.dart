import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

void main() {
  group('kBlueHourPalette physical relationships', () {
    const p = kBlueHourPalette;

    test('sky darkens and blues from horizon up to the zenith', () {
      // Twilight: the zenith is the darkest, most saturated blue; the horizon
      // band is lighter and cyan-shifted.
      expect(
        p.skyZenith.computeLuminance(),
        lessThan(p.skyHorizonCool.computeLuminance()),
      );
      expect(p.skyZenith.b, greaterThan(p.skyZenith.r));
      expect(p.skyZenith.b, greaterThan(p.skyZenith.g));
    });

    test('water is blue-dominant and darker than the sky horizon', () {
      expect(p.oceanNear.b, greaterThan(p.oceanNear.r));
      expect(p.oceanHorizon.b, greaterThan(p.oceanHorizon.r));
      expect(
        p.oceanNear.computeLuminance(),
        lessThan(p.skyHorizonCool.computeLuminance()),
      );
    });

    test('foam is a cool near-white', () {
      expect(p.foam.r, greaterThan(0.75));
      expect(p.foam.g, greaterThan(0.75));
      expect(p.foam.b, greaterThan(0.75));
    });

    test('artificial lights sit at their real color temperatures', () {
      // Sodium street lamps are warm (amber), LED windows are cool.
      expect(p.windowSodium.r, greaterThan(p.windowSodium.b));
      expect(p.windowLed.b, greaterThan(p.windowLed.r));
      expect(p.yachtCabinGlow.r, greaterThan(p.yachtCabinGlow.b));
    });

    test('signal emitters are saturated at their fixed wavelengths', () {
      expect(p.beaconRed.r, greaterThan(p.beaconRed.g));
      expect(p.beaconRed.r, greaterThan(p.beaconRed.b));
      expect(p.policeBlue.b, greaterThan(p.policeBlue.r));
      expect(p.policeBlue.b, greaterThan(p.policeBlue.g));
      // COLREGS navigation lights: red to port, green to starboard.
      expect(p.shipPort.r, greaterThan(p.shipPort.g));
      expect(p.shipStarboard.g, greaterThan(p.shipStarboard.r));
      expect(p.shipStarboard.g, greaterThan(p.shipStarboard.b));
    });

    test('all palette colors are fully opaque', () {
      for (final color in [
        p.skyZenith,
        p.skyHorizonCool,
        p.moonDisk,
        p.oceanNear,
        p.foam,
        p.beaconRed,
        p.policeBlue,
        p.shipStarboard,
        p.yachtHull,
        p.hazeSmog,
      ]) {
        expect(color.a, 1.0, reason: '$color must be opaque');
      }
    });
  });

  group('BackdropPalette.copyWith', () {
    test('overrides only the named field', () {
      const replacement = Color(0xFF010203);
      final tweaked = kBlueHourPalette.copyWith(foam: replacement);

      expect(tweaked.foam, replacement);
      // Every other field is untouched.
      expect(tweaked.skyZenith, kBlueHourPalette.skyZenith);
      expect(tweaked.oceanNear, kBlueHourPalette.oceanNear);
      expect(tweaked.beaconRed, kBlueHourPalette.beaconRed);
    });

    test('with no arguments preserves every field', () {
      final copy = kBlueHourPalette.copyWith();
      expect(copy.skyZenith, kBlueHourPalette.skyZenith);
      expect(copy.moonGlint, kBlueHourPalette.moonGlint);
      expect(copy.heliStrobe, kBlueHourPalette.heliStrobe);
    });
  });
}
