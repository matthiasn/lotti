import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/ocean_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

// The ocean is a GPU fragment shader with NO CPU fallback (hard rule: full
// shader fidelity or nothing), so its rendered output can only be exercised on
// a real device. The pure, deterministic testable seam is buildOceanUniforms —
// the wiring that packs the layer + palette into the shader's uniform vector.
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
}
