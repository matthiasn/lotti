import 'dart:ui' show Size;

/// Native authoring size of the painted scenery art (master plate + masks).
/// All layers and the `SkylineManifest` anchors are expressed in this space and
/// cover-fit to the viewport, so art, mask sampling and lights stay aligned.
const Size kSceneryCanvasSize = Size(2560, 1440);

/// Asset paths for the painted blue-hour waterfront layers.
///
/// `blue_hour_master.png` is the full-frame base plate (sky, skyline, bridge,
/// lagoon, yacht, deck). [cityWindows] is a registered window field baked FROM
/// the master (see `tools/scenery_art/bake_city_windows.py`) — the city-lights
/// shader lights its painted windows directly. [yacht] is the alpha-cut yacht
/// for its cabin/porthole anchors, and [foreground] is the deck/palms occluder
/// drawn over the animated ocean (so foam never streaks the planks).
abstract final class SceneryAssets {
  static const masterPlate = 'assets/scenery/blue_hour_master.png';
  static const cityWindows = 'assets/scenery/city_windows.png';
  static const yacht = 'assets/scenery/yacht.png';
  static const foreground = 'assets/scenery/foreground.png';
}
