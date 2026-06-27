import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/sky_layer.dart';

/// An ordered, back-to-front stack of [BackdropLayer]s plus the scene-level
/// knobs that configure them. The default [BackdropScene.blueHourWaterfront]
/// assembles the Lagos-lagoon blue-hour scene; the layer list grows as the
/// bitmap/ocean/props layers land (see the build order in the plan).
class BackdropScene {
  const BackdropScene({required this.layers});

  /// The Lagos-lagoon blue-hour scene.
  factory BackdropScene.blueHourWaterfront() {
    return const BackdropScene(
      layers: [
        SkyLayer(),
      ],
    );
  }

  /// Layers painted in order; earlier entries sit behind later ones.
  final List<BackdropLayer> layers;
}
