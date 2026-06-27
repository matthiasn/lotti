import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/sky_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';

void main() {
  group('BackdropScene.blueHourWaterfront', () {
    test('places the sky as the back-most layer', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(scene.layers, isNotEmpty);
      expect(scene.layers.first, isA<SkyLayer>());
    });
  });

  group('BackdropScene', () {
    test('preserves the provided layer order', () {
      const sky = SkyLayer();
      const sky2 = SkyLayer(moonX: 0.1);
      const scene = BackdropScene(layers: [sky, sky2]);
      expect(scene.layers, [sky, sky2]);
    });
  });
}
