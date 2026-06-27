import 'dart:ui' show Offset, Rect;

/// Normalized (0..1) anchor geometry for the structural bitmap layers, used by
/// the runtime light/props layer to pin windows, beacons, police sweeps and
/// vessel lights onto the painted art.
///
/// Coordinates are fractions of the artwork canvas (origin top-left, y down),
/// so they scale to any render size. This is the **contract** between the
/// Codex-authored artwork (`assets/scenery/*.png`) and the runtime: the
/// generator that draws the PNGs emits a matching const so the two cannot
/// drift. The placeholder [kPlaceholderSkylineManifest] below lets the runtime
/// compile and be exercised before the real art lands; Codex replaces it with
/// art-derived values.
class SkylineManifest {
  const SkylineManifest({
    required this.buildingTops,
    required this.windowCells,
    required this.bridgeTowerTops,
    required this.bridgeDeck,
    required this.yachtCabin,
    required this.yachtNavLights,
    required this.waterline,
  });

  /// Apex point of each tall building (aircraft beacons + roof lights).
  final List<Offset> buildingTops;

  /// Rects where lit windows may be drawn (one per building face / grid block).
  final List<Rect> windowCells;

  /// The two bridge-tower tops (aircraft beacons).
  final List<Offset> bridgeTowerTops;

  /// Polyline of the bridge deck, left→right (police-light sweeps travel it).
  final List<Offset> bridgeDeck;

  /// Rect of the yacht's cabin block (warm interior windows).
  final Rect yachtCabin;

  /// Yacht navigation lights — bow (port), bow (starboard), masthead/stern.
  final List<Offset> yachtNavLights;

  /// Normalized y of the horizon / waterline.
  final double waterline;
}

/// A coarse stand-in until the Codex-generated, art-matched manifest replaces
/// it. Values are plausible but not tied to any real artwork.
const SkylineManifest kPlaceholderSkylineManifest = SkylineManifest(
  buildingTops: [
    Offset(0.12, 0.46),
    Offset(0.22, 0.40),
    Offset(0.34, 0.49),
    Offset(0.46, 0.36),
    Offset(0.58, 0.44),
    Offset(0.71, 0.41),
    Offset(0.84, 0.47),
    Offset(0.92, 0.43),
  ],
  windowCells: [
    Rect.fromLTWH(0.10, 0.47, 0.05, 0.13),
    Rect.fromLTWH(0.20, 0.41, 0.045, 0.18),
    Rect.fromLTWH(0.32, 0.50, 0.05, 0.10),
    Rect.fromLTWH(0.44, 0.37, 0.05, 0.22),
    Rect.fromLTWH(0.56, 0.45, 0.05, 0.14),
    Rect.fromLTWH(0.69, 0.42, 0.05, 0.17),
    Rect.fromLTWH(0.82, 0.48, 0.05, 0.11),
  ],
  bridgeTowerTops: [
    Offset(0.30, 0.30),
    Offset(0.66, 0.30),
  ],
  bridgeDeck: [
    Offset(0, 0.64),
    Offset(0.30, 0.62),
    Offset(0.48, 0.615),
    Offset(0.66, 0.62),
    Offset(1, 0.64),
  ],
  yachtCabin: Rect.fromLTWH(0.55, 0.66, 0.07, 0.03),
  yachtNavLights: [
    Offset(0.535, 0.675),
    Offset(0.625, 0.675),
    Offset(0.58, 0.645),
  ],
  waterline: 0.62,
);
