import 'dart:ui' show Size;

import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart';
import 'package:lotti/features/scenery/layers/deck_glow_layer.dart';
import 'package:lotti/features/scenery/layers/image_layer.dart';
import 'package:lotti/features/scenery/layers/ocean_layer.dart';
import 'package:lotti/features/scenery/layers/sky_layer.dart';
import 'package:lotti/features/scenery/layers/vignette_layer.dart';
import 'package:lotti/features/scenery/model/scenery_assets.dart';

/// An ordered, back-to-front stack of [BackdropLayer]s plus the bitmap assets
/// the scene needs decoded. [layers] are painted behind the consumer's content;
/// [foregroundLayers] are painted in front of it (occluders).
class BackdropScene {
  const BackdropScene({
    required this.layers,
    this.foregroundLayers = const [],
    this.imageAssets = const [],
    this.sceneSize = kSceneryCanvasSize,
  });

  /// The painted Lagos-lagoon blue-hour scene, back to front: the full master
  /// plate as the base, the additive city/yacht night lights on its painted
  /// windows, the animated ocean over its painted water, the foreground
  /// deck/palms drawn over the ocean so foam never streaks the planks, and the
  /// warm lantern glow pooling on the now-lit deck. All sit behind the dancers
  /// (they are background layers).
  factory BackdropScene.blueHourWaterfront() {
    return const BackdropScene(
      layers: [
        ImageLayer(SceneryAssets.masterPlate),
        // More windows lit (brighter highrises) than the 0.6 default, and a
        // livelier ocean (more foam + a stronger glint) so the water reads as
        // moving at normal viewing size, not just under a pixel loupe.
        CityLightsLayer(windowAmount: 0.8),
        OceanLayer(foamDensity: 0.72, reflection: 0.3),
        ImageLayer(SceneryAssets.foreground),
        DeckGlowLayer(),
      ],
      foregroundLayers: [VignetteLayer()],
      imageAssets: [
        SceneryAssets.masterPlate,
        SceneryAssets.cityWindows,
        SceneryAssets.yacht,
        SceneryAssets.foreground,
      ],
    );
  }

  /// A fully procedural blue-hour sky (gradient, moon, stars, drifting clouds)
  /// with no painted assets — the reusable shader variant / art-free fallback.
  factory BackdropScene.proceduralBlueHour() {
    return const BackdropScene(layers: [SkyLayer()]);
  }

  /// Layers painted behind the content, in order (earlier = further back).
  final List<BackdropLayer> layers;

  /// Layers painted in front of the content (foreground occluders).
  final List<BackdropLayer> foregroundLayers;

  /// Asset paths the scene's [ImageLayer]s need decoded before they can paint.
  final List<String> imageAssets;

  /// Native coordinate space the layers paint in; cover-fit to the viewport so
  /// painted art, mask sampling and light anchors all stay aligned.
  final Size sceneSize;
}
