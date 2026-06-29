import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/sky_layer.dart';

// The sky is a GPU fragment shader with NO CPU fallback (hard rule: full shader
// fidelity or nothing), so its rendered output can only be exercised on a real
// device. The pure, deterministic testable seam is buildSkyUniforms — the
// wiring that packs the layer knobs into the shader's scalar uniform vector.
void main() {
  group('buildSkyUniforms', () {
    test('packs resolution, time and layer knobs in index order', () {
      const layer = SkyLayer(
        horizon: 0.6,
        sunGlowX: 0.65,
        moonX: 0.7,
        moonY: 0.22,
        moonRadius: 0.08,
        starDensity: 0.5,
        cloudCoverage: 0.55,
        cloudSoftness: 0.2,
        cloudScale: 2,
        hazeStrength: 0.4,
        grain: 0.03,
      );
      final u = buildSkyUniforms(const Size(800, 600), 1.5, layer);

      expect(u, hasLength(14));
      expect(u[0], 800); // width
      expect(u[1], 600); // height
      expect(u[2], 1.5); // time
      expect(u[3], 0.6); // horizon
      expect(u[4], 0.65); // sunGlowX
      expect(u[5], 0.7); // moonX
      expect(u[6], 0.22); // moonY
      expect(u[7], 0.08); // moonRadius
      expect(u[8], 0.5); // starDensity
      expect(u[9], 0.55); // cloudCoverage
      expect(u[10], 0.2); // cloudSoftness
      expect(u[11], 2); // cloudScale
      expect(u[12], 0.4); // hazeStrength
      expect(u[13], 0.03); // grain
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
}
