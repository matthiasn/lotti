import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart';
import 'package:lotti/features/scenery/layers/cloud_parallax_layer.dart';
import 'package:lotti/features/scenery/layers/deck_glow_layer.dart';
import 'package:lotti/features/scenery/layers/drone_show_layer.dart';
import 'package:lotti/features/scenery/layers/image_layer.dart';
import 'package:lotti/features/scenery/layers/ocean_layer.dart';
import 'package:lotti/features/scenery/layers/sky_layer.dart';
import 'package:lotti/features/scenery/layers/vignette_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_scene.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';

void main() {
  group('BackdropScene.blueHourWaterfront', () {
    test('uses the cloudless painted plate as its base layer', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(scene.layers, isNotEmpty);
      expect(scene.layers.first, isA<ImageLayer>());
      expect(
        (scene.layers.first as ImageLayer).assetKey,
        SceneryAssets.cloudlessPlate,
      );
    });

    test('declares cloud, light, and structure assets to decode', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(
        scene.imageAssets,
        containsAll(<String>[
          SceneryAssets.cloudlessPlate,
          SceneryAssets.masterPlate,
          SceneryAssets.cloudsFar,
          SceneryAssets.cloudsMid,
          SceneryAssets.cloudsNear,
          SceneryAssets.cityBridge,
          SceneryAssets.cityWindows,
          SceneryAssets.yacht,
          SceneryAssets.foreground,
        ]),
      );
    });

    test(
      'composites plate -> clouds -> sky drones -> ocean -> city/yacht -> launch drones -> deck',
      () {
        final layers = BackdropScene.blueHourWaterfront().layers;
        final plate = layers.indexWhere(
          (l) => l is ImageLayer && l.assetKey == SceneryAssets.cloudlessPlate,
        );
        final cloud = layers.indexWhere((l) => l is CloudParallaxLayer);
        final deck = layers.lastIndexWhere((l) => l is ImageLayer);
        final city = layers.indexWhere(
          (l) => l is ImageLayer && l.assetKey == SceneryAssets.cityBridge,
        );
        final yacht = layers.indexWhere(
          (l) => l is ImageLayer && l.assetKey == SceneryAssets.yacht,
        );
        final lights = layers.indexWhere((l) => l is CityLightsLayer);
        final ocean = layers.indexWhere((l) => l is OceanLayer);
        final skyDrones = layers.indexWhere(
          (l) =>
              l is DroneShowLayer &&
              l.visiblePhases.contains(DroneShowPhase.beam),
        );
        final launchDrones = layers.indexWhere(
          (l) =>
              l is DroneShowLayer &&
              l.visiblePhases.contains(DroneShowPhase.launch),
        );
        final glow = layers.indexWhere((l) => l is DeckGlowLayer);
        expect(plate, 0);
        expect(cloud, greaterThan(plate));
        expect(skyDrones, greaterThan(cloud));
        // Animated water sits over the painted plate.
        expect(ocean, greaterThan(plate));
        expect(ocean, greaterThan(cloud));
        expect(ocean, greaterThan(skyDrones));
        // The fixed skyline/bridge is re-drawn over drifting clouds so the clouds
        // stay behind the city instead of sliding across tower silhouettes.
        expect(city, greaterThan(ocean));
        // The moored yacht is re-drawn OVER the ocean so its solid hull occludes
        // the foam, and the city lights (incl. the lit cabin windows) draw on top
        // of the yacht so the warm cabin glow is not hidden behind the hull.
        expect(yacht, greaterThan(ocean));
        expect(lights, greaterThan(yacht));
        // The bridge-road launch pass draws after the fixed bridge/yacht layer
        // so cable stays do not slice visible holes through the takeoff row.
        expect(launchDrones, greaterThan(city));
        expect(launchDrones, greaterThan(yacht));
        expect(launchDrones, greaterThan(lights));
        // The foreground deck is the LAST bitmap, drawn over the ocean so foam
        // never streaks the planks; the lantern glow pools on the now-lit deck.
        expect(deck, greaterThan(launchDrones));
        expect(glow, greaterThan(deck));
      },
    );

    test('darkens the frame edges with a foreground vignette', () {
      final scene = BackdropScene.blueHourWaterfront();
      expect(scene.foregroundLayers, [isA<VignetteLayer>()]);
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
