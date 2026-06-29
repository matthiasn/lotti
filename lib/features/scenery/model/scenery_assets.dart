import 'dart:ui' show Size;

/// Native authoring size of the painted scenery art (master plate + masks).
/// All layers and the `SkylineManifest` anchors are expressed in this space and
/// cover-fit to the viewport, so art, mask sampling and lights stay aligned.
const Size kSceneryCanvasSize = Size(2560, 1440);

/// Asset paths for the painted blue-hour waterfront layers.
///
/// `blue_hour_master.webp` is the immutable source plate. The runtime base is
/// [cloudlessPlate], with exact master-derived cloud pixels reintroduced through
/// [cloudsFar], [cloudsMid] and [cloudsNear] so they can drift independently.
/// [cityWindows] is a registered window field baked FROM the master (see
/// `tools/scenery_art/bake_city_windows.py`) — the city-lights shader lights its
/// painted windows directly. [cityBridge], [yacht] and [foreground] are
/// alpha-cut structure/occluder layers re-drawn over animated atmosphere/water
/// so moving effects stay behind solid painted objects. [lufthansa747] is a
/// cropped transparent overlay asset used by the distant-jet layer.
abstract final class SceneryAssets {
  static const masterPlate = 'assets/scenery/blue_hour_master.webp';
  static const cloudlessPlate = 'assets/scenery/blue_hour_cloudless.webp';
  static const cloudsFar = 'assets/scenery/clouds_far.webp';
  static const cloudsMid = 'assets/scenery/clouds_mid.webp';
  static const cloudsNear = 'assets/scenery/clouds_near.webp';
  static const cityWindows = 'assets/scenery/city_windows.webp';
  static const cityBridge = 'assets/scenery/city_bridge.webp';
  static const yacht = 'assets/scenery/yacht.webp';
  static const foreground = 'assets/scenery/foreground.webp';
  static const lufthansa747 = 'assets/scenery/lufthansa_747.png';
}
