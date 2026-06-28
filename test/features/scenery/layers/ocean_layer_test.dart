import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart';
import 'package:lotti/features/scenery/layers/ocean_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';
import 'package:lotti/features/scenery/model/skyline_manifest.dart';

final double _waterline = kPlaceholderSkylineManifest.waterline;

Future<ui.Image> _renderFallback(
  Size size,
  double time, {
  OceanLayer layer = const OceanLayer(),
  double beat = 0,
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintOceanFallback(
    canvas,
    size,
    time,
    kBlueHourPalette,
    layer,
    cover: coverFit(size),
    waterline: _waterline,
    beat: beat,
  );
  return recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
}

/// Renders the whole layer (program-less, so the CPU fallback runs) end to end
/// so the reduced-motion freeze logic in the layer's paint is exercised too.
Future<ui.Image> _renderLayer(
  Size size, {
  required double time,
  required bool reducedMotion,
}) {
  final recorder = ui.PictureRecorder();
  const OceanLayer().paint(
    Canvas(recorder),
    BackdropContext(
      size: size,
      timeSeconds: time,
      palette: kBlueHourPalette,
      reducedMotion: reducedMotion,
    ),
  );
  return recorder.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
}

Future<Color Function(int, int)> _pixelReader(ui.Image image) async {
  final data = await image.toByteData();
  final bytes = data!.buffer.asUint8List();
  final w = image.width;
  return (int x, int y) {
    final i = (y * w + x) * 4;
    return Color.fromARGB(bytes[i + 3], bytes[i], bytes[i + 1], bytes[i + 2]);
  };
}

double _maxLuminance(
  Color Function(int, int) pixel,
  int x0,
  int y0,
  int x1,
  int y1,
) {
  var best = 0.0;
  for (var y = y0; y <= y1; y++) {
    for (var x = x0; x <= x1; x++) {
      final l = pixel(x, y).computeLuminance();
      if (l > best) best = l;
    }
  }
  return best;
}

void main() {
  group('buildOceanUniforms', () {
    test('packs resolution, time, cover/waterline, knobs and colors', () {
      const layer = OceanLayer(
        moonX: 0.4,
        foamDensity: 0.7,
        waveScale: 11,
        reflection: 0.6,
        tint: 0.15,
        grain: 0.03,
      );
      final u = buildOceanUniforms(
        const Size(800, 600),
        1.5,
        layer,
        kBlueHourPalette,
        cover: const Rect.fromLTWH(-50, 0, 340, 200),
        waterline: 0.62,
        beat: 0.8,
      );

      expect(u, hasLength(31));
      expect(u[0], 800); // width
      expect(u[1], 600); // height
      expect(u[2], 1.5); // time
      expect(u[3], -50); // cover.left
      expect(u[4], 0); // cover.top
      expect(u[5], 340); // cover.width
      expect(u[6], 200); // cover.height
      expect(u[7], 0.62); // waterline
      expect(u[8], 0.4); // moonX
      expect(u[9], 0.7); // foamDensity
      expect(u[10], 11); // waveScale
      expect(u[11], 0.6); // reflection
      expect(u[12], 0.15); // tint
      expect(u[13], 0.03); // grain
      expect(u[14], 0.8); // beat

      // The four palette colors land at offsets 15 / 19 / 23 / 27.
      const p = kBlueHourPalette;
      expect(u[15], closeTo(p.oceanHorizon.r, 1e-6));
      expect(u[18], closeTo(p.oceanHorizon.a, 1e-6));
      expect(u[19], closeTo(p.oceanNear.r, 1e-6));
      expect(u[22], closeTo(p.oceanNear.a, 1e-6));
      expect(u[23], closeTo(p.foam.r, 1e-6));
      expect(u[26], closeTo(p.foam.a, 1e-6));
      expect(u[27], closeTo(p.moonGlint.r, 1e-6));
      expect(u[30], closeTo(p.moonGlint.a, 1e-6));
    });

    test('tracks resolution and time across samples', () {
      const layer = OceanLayer();
      for (final (w, h, t) in const [
        (320.0, 240.0, 0.0),
        (1024.0, 768.0, 12.5),
        (1920.0, 1080.0, 99.9),
      ]) {
        final u = buildOceanUniforms(
          Size(w, h),
          t,
          layer,
          kBlueHourPalette,
          cover: const Rect.fromLTWH(0, 0, 1, 1),
          waterline: 0.62,
          beat: 0,
        );
        expect(u[0], w);
        expect(u[1], h);
        expect(u[2], t);
      }
    });
  });

  group('paintOceanFallback', () {
    testWidgets('paints a teal band with brighter foam and glint', (
      tester,
    ) async {
      // toImage()/toByteData() drive the engine raster path, which only runs
      // outside the fake-async test zone — hence runAsync.
      await tester.runAsync(() async {
        const size = Size(240, 200);
        final image = await _renderFallback(size, 2);
        final pixel = await _pixelReader(image);

        // The water band starts at the cover-mapped waterline (~0.62 * height).
        // Above it the layer paints nothing → fully transparent.
        final above = pixel(size.width ~/ 2, 100);
        expect(above.a, 0, reason: 'nothing above the waterline');

        // Calm water near the bottom, away from foam crests and the glint
        // column, is opaque and teal (blue > red), and dim.
        final water = pixel(30, 195);
        expect(water.a, 1.0);
        expect(water.b, greaterThan(water.r), reason: 'teal water');
        final waterLum = water.computeLuminance();
        expect(waterLum, lessThan(0.2));

        // A foam crest row (band depth ~0.47) is markedly brighter than calm
        // water, away from the central glint column. (computeLuminance is in
        // linear space, where the dark teal water sits near 0.015.)
        final foamLum = _maxLuminance(pixel, 40, 150, 100, 170);
        expect(foamLum, greaterThan(waterLum + 0.05), reason: 'foam crest');

        // The moon-glint column (default moonX 0.5 → screen center) is brighter
        // than the calm water too.
        final glintLum = _maxLuminance(pixel, 112, 168, 128, 198);
        expect(glintLum, greaterThan(waterLum + 0.05), reason: 'moon glint');

        image.dispose();
      });
    });

    testWidgets('is deterministic for a given time', (tester) async {
      await tester.runAsync(() async {
        const size = Size(160, 120);
        final a = await _renderFallback(size, 3.25);
        final b = await _renderFallback(size, 3.25);
        final ba = (await a.toByteData())!.buffer.asUint8List();
        final bb = (await b.toByteData())!.buffer.asUint8List();
        expect(ba, equals(bb));
        a.dispose();
        b.dispose();
      });
    });
  });

  group('OceanLayer.paint', () {
    testWidgets('reduced motion freezes the clock; otherwise it animates', (
      tester,
    ) async {
      await tester.runAsync(() async {
        const size = Size(240, 200);

        // Reduce-motion holds time at 0 regardless of the injected clock, so two
        // different clocks render identical frames.
        final frozenA = await _renderLayer(size, time: 1, reducedMotion: true);
        final frozenB = await _renderLayer(size, time: 9, reducedMotion: true);
        final fa = (await frozenA.toByteData())!.buffer.asUint8List();
        final fb = (await frozenB.toByteData())!.buffer.asUint8List();
        expect(fa, equals(fb), reason: 'frozen under reduce-motion');

        // With motion on, the same two clocks drift the foam/glint apart.
        final liveA = await _renderLayer(size, time: 1, reducedMotion: false);
        final liveB = await _renderLayer(size, time: 9, reducedMotion: false);
        final la = (await liveA.toByteData())!.buffer.asUint8List();
        final lb = (await liveB.toByteData())!.buffer.asUint8List();
        expect(la, isNot(equals(lb)), reason: 'animates when motion is on');

        frozenA.dispose();
        frozenB.dispose();
        liveA.dispose();
        liveB.dispose();
      });
    });
  });
}
