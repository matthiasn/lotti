import 'dart:ui' show Size;

import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/city_lights_layer.dart';
import 'package:lotti/features/scenery/layers/cloud_parallax_layer.dart';
import 'package:lotti/features/scenery/layers/deck_glow_layer.dart';
import 'package:lotti/features/scenery/layers/drone_show_layer.dart';
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

  /// The painted Lagos-lagoon blue-hour scene, back to front: the cloudless
  /// master-derived base plate, three exact-pixel cloud layers drifting at
  /// different depths, the animated ocean, solid skyline/bridge/yacht structure
  /// re-drawn OVER atmosphere/water so clouds/foam never slide across them, the
  /// additive city/yacht night lights, the foreground deck/palms, the warm
  /// lantern glow pooling on the now-lit deck, and finally both drone-show
  /// passes above the painted structures so bridge cables cannot slice holes in
  /// the ascent. All sit behind the dancers (they are background layers).
  factory BackdropScene.blueHourWaterfront() {
    return const BackdropScene(
      layers: [
        ImageLayer(SceneryAssets.cloudlessPlate),
        CloudParallaxLayer(
          SceneryAssets.cloudsFar,
          opacity: 0.84,
          dxPerSecond: 0.00165,
          dyAmplitude: 0.001,
          dyCycleSeconds: 72,
          phase: 0.17,
        ),
        CloudParallaxLayer(
          SceneryAssets.cloudsMid,
          opacity: 0.84,
          dxPerSecond: 0.0021,
          dyAmplitude: 0.0015,
          dyCycleSeconds: 58,
          phase: 0.43,
        ),
        CloudParallaxLayer(
          SceneryAssets.cloudsNear,
          opacity: 0.9,
          dxPerSecond: 0.002775,
          dyCycleSeconds: 46,
          phase: 0.71,
        ),
        // Animated water first; the additive ocean and additive city lights
        // commute, so the only thing the order buys us is letting the opaque
        // yacht sit BETWEEN them.
        OceanLayer(foamDensity: 0.72, reflection: 0.3),
        // Re-draw fixed skyline + bridge over the drifting cloud layers and
        // ocean shimmer, preserving the original depth ordering.
        ImageLayer(SceneryAssets.cityBridge),
        // The moored yacht silhouette, re-drawn over the ocean so its hull
        // covers the foam that would otherwise wash up its side.
        ImageLayer(SceneryAssets.yacht),
        // More windows lit (brighter highrises) than the 0.6 default; drawn
        // after the yacht so the warm cabin glow reads on top of the hull.
        CityLightsLayer(windowAmount: 0.8),
        ImageLayer(SceneryAssets.foreground),
        DeckGlowLayer(),
        // Drones are the highest backdrop art pass: the takeoff starts as
        // unlit dark dots and switches on above the cable-stayed bridge, so
        // painted bridge cables/trees must not cut gaps through the aircraft.
        DroneShowLayer.sky(),
        DroneShowLayer.launchRoad(),
      ],
      foregroundLayers: [VignetteLayer(dim: 0.12)],
      imageAssets: [
        SceneryAssets.cloudlessPlate,
        SceneryAssets.masterPlate,
        SceneryAssets.cloudsFar,
        SceneryAssets.cloudsMid,
        SceneryAssets.cloudsNear,
        SceneryAssets.cityBridge,
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
