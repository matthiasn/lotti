import 'dart:ui' show Size;

/// Native authoring size of the painted scenery art (master plate + masks).
/// All layers and the `SkylineManifest` anchors are expressed in this space and
/// cover-fit to the viewport, so art, mask sampling and lights stay aligned.
const Size kSceneryCanvasSize = Size(2560, 1440);

/// Asset paths for the painted blue-hour waterfront layers.
///
/// `blue_hour_master.png` is the immutable source plate. The runtime base is
/// [cloudlessPlate], with exact master-derived cloud pixels reintroduced through
/// [cloudsFar], [cloudsMid] and [cloudsNear] so they can drift independently.
/// [cityWindows] is a registered window field baked FROM the master (see
/// `tools/scenery_art/bake_city_windows.py`) — the city-lights shader lights its
/// painted windows directly. [cityBridge], [yacht] and [foreground] are
/// alpha-cut structure/occluder layers re-drawn over animated atmosphere/water
/// so moving effects stay behind solid painted objects.
abstract final class SceneryAssets {
  static const masterPlate = 'assets/scenery/blue_hour_master.png';
  static const cloudlessPlate = 'assets/scenery/blue_hour_cloudless.png';
  static const cloudsFar = 'assets/scenery/clouds_far.png';
  static const cloudsMid = 'assets/scenery/clouds_mid.png';
  static const cloudsNear = 'assets/scenery/clouds_near.png';
  static const cityWindows = 'assets/scenery/city_windows.png';
  static const cityBridge = 'assets/scenery/city_bridge.png';
  static const yacht = 'assets/scenery/yacht.png';
  static const foreground = 'assets/scenery/foreground.png';
}
