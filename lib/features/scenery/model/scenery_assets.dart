/// Asset paths for the painted blue-hour waterfront layers.
///
/// `blue_hour_master.png` is the full-frame base plate (sky, skyline, bridge,
/// lagoon, yacht, deck). The other three carry the master's RGB cut to a region
/// by an alpha mask (see `tools/scenery_art/`): [cityBridge] and [yacht] are
/// mid-ground anchors for lights, and [foreground] is a full-height occluder
/// (palms, planters, deck edge) meant to sit in front of the dancers.
abstract final class SceneryAssets {
  static const masterPlate = 'assets/scenery/blue_hour_master.png';
  static const cityBridge = 'assets/scenery/city_bridge.png';
  static const yacht = 'assets/scenery/yacht.png';
  static const foreground = 'assets/scenery/foreground.png';
}
