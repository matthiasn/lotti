import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/cloud_parallax_layer.dart';

void main() {
  group('cloudParallaxOffset', () {
    const cover = Rect.fromLTWH(0, 0, 2560, 1440);

    test('advances horizontally with playback time', () {
      const layer = CloudParallaxLayer(
        'clouds',
      );

      expect(cloudParallaxOffset(cover, 0, layer).dx, closeTo(0, 1e-9));
      expect(
        cloudParallaxOffset(cover, 60, layer).dx,
        closeTo(153.6, 1e-6),
      );
      expect(
        cloudParallaxOffset(cover, 120, layer).dx,
        closeTo(307.2, 1e-6),
      );
    });

    test('wraps without growing beyond half the art width', () {
      const layer = CloudParallaxLayer(
        'clouds',
        dxPerSecond: 0.01,
      );

      final offset = cloudParallaxOffset(cover, 60, layer);
      expect(offset.dx.abs(), lessThanOrEqualTo(cover.width / 2));
    });

    test('uses independent vertical breathing', () {
      const layer = CloudParallaxLayer(
        'clouds',
        dxPerSecond: 0,
        dyAmplitude: 0.01,
        dyCycleSeconds: 30,
        phase: 0.25,
      );

      final a = cloudParallaxOffset(cover, 0, layer);
      final b = cloudParallaxOffset(cover, 15, layer);
      expect(a.dy, isNot(closeTo(b.dy, 1e-6)));
      expect(a.dy.abs(), lessThanOrEqualTo(cover.height * 0.01));
      expect(b.dy.abs(), lessThanOrEqualTo(cover.height * 0.01));
    });
  });
}
