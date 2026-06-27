import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/image_layer.dart';
import 'package:lotti/features/scenery/layers/sky_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';

void main() {
  group('BackdropScene.blueHourWaterfront', () {
    test('uses the painted master plate as its base layer', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(scene.layers, isNotEmpty);
      expect(scene.layers.first, isA<ImageLayer>());
      expect(
        (scene.layers.first as ImageLayer).assetKey,
        SceneryAssets.masterPlate,
      );
    });

    test('declares the master plate as an asset to decode', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(scene.imageAssets, contains(SceneryAssets.masterPlate));
    });
  });

  group('BackdropScene.proceduralBlueHour', () {
    test(
      'uses the shader sky as its back-most layer with no bitmap assets',
      () {
        final scene = BackdropScene.proceduralBlueHour();
        expect(scene.layers.first, isA<SkyLayer>());
        expect(scene.imageAssets, isEmpty);
      },
    );
  });

  group('BackdropScene', () {
    test('preserves the provided layer order', () {
      const a = SkyLayer();
      const b = SkyLayer(moonX: 0.1);
      const scene = BackdropScene(layers: [a, b]);
      expect(scene.layers, [a, b]);
      expect(scene.foregroundLayers, isEmpty);
    });
  });
}
