import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/sky_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

Future<ui.Image> _renderFallback(
  Size size,
  double time, {
  SkyLayer layer = const SkyLayer(),
}) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  paintSkyFallback(canvas, size, time, kBlueHourPalette, layer);
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
    return Color.fromARGB(
      bytes[i + 3],
      bytes[i],
      bytes[i + 1],
      bytes[i + 2],
    );
  };
}

void main() {
  group('buildSkyUniforms', () {
    test('packs resolution, time and layer knobs in index order', () {
      const layer = SkyLayer(
        horizon: 0.6,
        moonX: 0.7,
        moonY: 0.2,
        moonRadius: 0.08,
        starDensity: 0.5,
        cloudCoverage: 0.55,
        cloudSoftness: 0.2,
        cloudScale: 2,
        hazeStrength: 0.4,
        grain: 0.03,
      );
      final u = buildSkyUniforms(const Size(800, 600), 1.5, layer);

      expect(u, hasLength(13));
      expect(u[0], 800); // width
      expect(u[1], 600); // height
      expect(u[2], 1.5); // time
      expect(u[3], 0.6); // horizon
      expect(u[4], 0.7); // moonX
      expect(u[5], 0.2); // moonY
      expect(u[6], 0.08); // moonRadius
      expect(u[7], 0.5); // starDensity
      expect(u[8], 0.55); // cloudCoverage
      expect(u[9], 0.2); // cloudSoftness
      expect(u[10], 2); // cloudScale
      expect(u[11], 0.4); // hazeStrength
      expect(u[12], 0.03); // grain
    });

    test('tracks resolution and time across samples', () {
      const layer = SkyLayer();
      for (final (w, h, t) in const [
        (320.0, 240.0, 0.0),
        (1024.0, 768.0, 12.5),
        (1920.0, 1080.0, 99.9),
      ]) {
        final u = buildSkyUniforms(Size(w, h), t, layer);
        expect(u[0], w);
        expect(u[1], h);
        expect(u[2], t);
      }
    });
  });

  group('paintSkyFallback', () {
    testWidgets('paints a blue sky with a brighter moon region', (
      tester,
    ) async {
      // toImage()/toByteData() drive the engine raster path, which only runs
      // outside the fake-async test zone — hence runAsync.
      await tester.runAsync(() async {
        const size = Size(240, 200);
        // Moon at the layer's default position (0.74, 0.22).
        const layer = SkyLayer(moonRadius: 0.09);
        final image = await _renderFallback(size, 2, layer: layer);
        final pixel = await _pixelReader(image);

        // Top of the sky is opaque and blue-dominant.
        final top = pixel(size.width ~/ 2, 3);
        expect(top.a, 1.0);
        expect(top.b, greaterThan(top.r));

        // The moon disc is far brighter than the sky away from it.
        final moon = pixel(
          (0.74 * size.width).round(),
          (0.22 * size.height).round(),
        );
        final awayFromMoon = pixel(
          (0.2 * size.width).round(),
          (0.22 * size.height).round(),
        );
        expect(
          moon.computeLuminance(),
          greaterThan(awayFromMoon.computeLuminance() + 0.2),
        );
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
}
