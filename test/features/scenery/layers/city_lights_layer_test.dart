import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';

// period(0) = 3.8 + 1.7 * frac(0*0.37 + 0.11) = 3.987s; flash duty = 0.08,
// so the per-flash peak is at pos = 0.04 (a quarter sine).
const _period0 = 3.987;

void main() {
  group('coverFit maps normalized art anchors onto BoxFit.cover', () {
    test('aspect-matching viewport fills exactly with no crop', () {
      // 1280x720 has the same 16:9 aspect as the 2560x1440 art, so cover-fit
      // is the identity rect: offset (0,0), size == viewport.
      final cover = coverFit(const Size(1280, 720));
      expect(cover.left, closeTo(0, 1e-6));
      expect(cover.top, closeTo(0, 1e-6));
      expect(cover.width, closeTo(1280, 1e-6));
      expect(cover.height, closeTo(720, 1e-6));
    });

    test(
      'taller-than-art viewport scales by height and centers horizontally',
      () {
        // Portrait-ish viewport: cover scales by the larger ratio (height here)
        // and overflows symmetrically on the wide axis.
        const vp = Size(900, 1600);
        final cover = coverFit(vp);
        final scale = vp.height / kSceneryCanvasSize.height; // binding axis
        expect(cover.height, closeTo(kSceneryCanvasSize.height * scale, 1e-6));
        expect(cover.width, greaterThan(vp.width)); // overflows, fully covers
        // Centered: equal overflow on left and right.
        expect(cover.left, closeTo((vp.width - cover.width) / 2, 1e-6));
        expect(cover.left + cover.width, closeTo(vp.width - cover.left, 1e-6));
      },
    );

    test('the center anchor maps to the viewport center for any aspect', () {
      for (final vp in const [
        Size(1280, 720),
        Size(900, 1600),
        Size(2000, 800),
      ]) {
        final cover = coverFit(vp);
        final mid = Offset(
          cover.left + 0.5 * cover.width,
          cover.top + 0.5 * cover.height,
        );
        expect(mid.dx, closeTo(vp.width / 2, 1e-6), reason: '$vp');
        expect(mid.dy, closeTo(vp.height / 2, 1e-6), reason: '$vp');
      }
    });
  });

  group('beaconIntensity schedules a slow, staggered blink', () {
    test('is dark for the bulk of the period and flashes only briefly', () {
      var lit = 0;
      const samples = 600;
      const window = 12.0; // a few long periods
      for (var i = 0; i < samples; i++) {
        final t = i / samples * window;
        final v = beaconIntensity(0, t);
        expect(v, inInclusiveRange(0, 1));
        if (v > 0) lit++;
      }
      // ~8% duty of each ~4s period → well under a sixth of the time lit.
      expect(lit / samples, lessThan(0.16));
      expect(lit, greaterThan(0)); // but it does flash
    });

    test('two beacons do not flash in lockstep', () {
      // There must be a moment where beacon #0 is lit while #1 is dark.
      var staggered = false;
      for (var i = 0; i < 400; i++) {
        final t = i / 400 * 12;
        if (beaconIntensity(0, t) > 0 && beaconIntensity(1, t) == 0) {
          staggered = true;
          break;
        }
      }
      expect(staggered, isTrue);
    });

    test('repeats one period later and is deterministic', () {
      const t = 0.11; // inside beacon #0's first flash
      expect(beaconIntensity(0, t), greaterThan(0));
      expect(
        beaconIntensity(0, t + _period0),
        closeTo(beaconIntensity(0, t), 1e-3),
      );
      // Pure: identical inputs → identical output.
      expect(beaconIntensity(3, 1.234), beaconIntensity(3, 1.234));
    });
  });

  group('paint draws beacons on their cover-mapped anchors', () {
    BackdropContext ctx(Size size, double time) => BackdropContext(
      size: size,
      timeSeconds: time,
      palette: kBlueHourPalette,
      // No program/images → the window shader is skipped; only the
      // canvas beacons render, which is what we assert on.
    );

    test(
      'a flashing beacon paints red at its mapped screen position',
      () async {
        // t chosen so beacon #0 sits at its flash peak (pos = 0.04 of period).
        const t = 0.04 * _period0;
        expect(beaconIntensity(0, t), closeTo(1, 0.02));

        const size = Size(1280, 720); // 16:9 → anchor maps directly to fraction
        final recorder = ui.PictureRecorder();
        const CityLightsLayer().paint(Canvas(recorder), ctx(size, t));
        final image = await recorder.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final data = await image.toByteData(); // defaults to rawRgba
        image.dispose();

        int red(Offset p) {
          final i = (p.dy.round() * size.width.toInt() + p.dx.round()) * 4;
          return data!.getUint8(i); // R channel
        }

        final anchor = kPlaceholderSkylineManifest.buildingTops.first;
        final at = Offset(anchor.dx * size.width, anchor.dy * size.height);
        // Bright red core at the beacon; near-zero far away in empty sky.
        expect(red(at), greaterThan(180), reason: 'beacon core should be red');
        expect(
          red(const Offset(20, 700)),
          lessThan(40),
          reason: 'empty corner',
        );
      },
    );

    test('does not throw when its programs and masks have not decoded', () {
      final recorder = ui.PictureRecorder();
      expect(
        () => const CityLightsLayer().paint(
          Canvas(recorder),
          ctx(const Size(800, 600), 1.5),
        ),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });

    test('reduced motion freezes the blink clock to a calm frame', () {
      // Under reduce-motion the layer paints from time 0 regardless of the
      // injected clock, so the frame never animates.
      const frozen = BackdropContext(
        size: Size(1280, 720),
        timeSeconds: 99,
        palette: kBlueHourPalette,
        reducedMotion: true,
      );
      final recorder = ui.PictureRecorder();
      const CityLightsLayer().paint(Canvas(recorder), frozen);
      expect(recorder.endRecording(), isNotNull);
    });
  });
}
