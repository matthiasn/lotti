import 'dart:ui' show Color;

/// Physics-guided color palette for the blue-hour waterfront `LayeredBackdrop`.
///
/// This is an **artistic scene palette**, intentionally outside the
/// design-system token set (the same way the legacy waterfront backdrop in
/// `character_painter.dart` uses raw `Color` literals). It is the single
/// tweakable source of truth that art-directs both the fragment shaders (sky,
/// ocean) and the structural bitmap layers Codex paints against, so every
/// scene element stays color-coherent.
///
/// The values are grounded in twilight optics — blue hour is roughly when the
/// sun sits 4–8° below the horizon:
///
/// * **Rayleigh scattering** (∝ 1/λ⁴) lets short (blue) wavelengths survive,
///   and **ozone Chappuis-band absorption** removes the residual orange/red —
///   together that is why the zenith reads as a deep, pure blue.
/// * A thin warm **ember** only survives low on the sunset azimuth (the last
///   long-wavelength light to make it through the long horizon path).
/// * **Moonlight** is reflected sunlight (~4300 K with a slight regolith
///   warmth) wrapped in a cool, scattered halo.
/// * Artificial lights sit at their real correlated color temperatures
///   (sodium ~2000 K amber, LED ~4500 K cool white), and signal emitters
///   (aircraft beacon, police, COLREGS nav lights) at their fixed wavelengths.
/// * Water is a Fresnel reflection of the sky minus the red the body absorbs,
///   so it trends dark teal.
///
/// A low warm-grey **smog/haze** band and a faint film grain (applied in the
/// shaders) keep the scene grimy and lived-in rather than shiny and new.
class BackdropPalette {
  const BackdropPalette({
    required this.skyZenith,
    required this.skyUpper,
    required this.skyHorizonCool,
    required this.skyEmber,
    required this.sunsetGlow,
    required this.sunsetHot,
    required this.hazeSmog,
    required this.moonDisk,
    required this.moonHalo,
    required this.star,
    required this.cloudLit,
    required this.cloudBase,
    required this.skylineFar,
    required this.skylineNear,
    required this.buildingRim,
    required this.windowSodium,
    required this.windowLed,
    required this.bridgeStruct,
    required this.bridgeCable,
    required this.yachtHull,
    required this.yachtCabinGlow,
    required this.oceanHorizon,
    required this.oceanNear,
    required this.foam,
    required this.moonGlint,
    required this.beaconRed,
    required this.policeRed,
    required this.policeBlue,
    required this.shipPort,
    required this.shipStarboard,
    required this.shipMast,
    required this.heliBeacon,
    required this.heliStrobe,
  });

  /// Zenith of the sky gradient — deepest, darkest twilight blue.
  final Color skyZenith;

  /// Mid-altitude sky blue.
  final Color skyUpper;

  /// Teal-cyan band where the sky meets the horizon.
  final Color skyHorizonCool;

  /// Muted warm residual on the sunset azimuth (used sparingly, low).
  final Color skyEmber;

  /// Dramatic post-sunset afterglow band rising off the horizon (burnt orange).
  final Color sunsetGlow;

  /// Hot core of the afterglow right at the horizon / sun azimuth (amber).
  final Color sunsetHot;

  /// Low pollution/haze band over the lagoon — lifts blacks, desaturates.
  final Color hazeSmog;

  /// The moon disc — warm pale white.
  final Color moonDisk;

  /// Cool bluish bloom around the moon.
  final Color moonHalo;

  /// Faint near-white star points.
  final Color star;

  /// Moon/sky-lit cloud tops.
  final Color cloudLit;

  /// Shadowed cloud undersides.
  final Color cloudBase;

  /// Distant skyline tier — lifted toward sky blue by aerial perspective.
  final Color skylineFar;

  /// Foreground skyline tier — near-black blue silhouette.
  final Color skylineNear;

  /// Cool moon-side rim light on building edges.
  final Color buildingRim;

  /// High-pressure sodium window glow (~2000 K amber, dominant).
  final Color windowSodium;

  /// LED/fluorescent window glow (~4500 K cool white, minority).
  final Color windowLed;

  /// Bridge structural silhouette.
  final Color bridgeStruct;

  /// Thin moonlit bridge-cable highlights.
  final Color bridgeCable;

  /// Moored-yacht hull silhouette.
  final Color yachtHull;

  /// Warm interior cabin spill on the yacht (~2700 K).
  final Color yachtCabinGlow;

  /// Water near the horizon — reflects the cyan sky band.
  final Color oceanHorizon;

  /// Deep foreground water — body absorption dominates.
  final Color oceanNear;

  /// Cool near-white wave-crest foam.
  final Color foam;

  /// Warm broken moon-reflection column on the water.
  final Color moonGlint;

  /// Red aircraft obstruction beacon (~630 nm), flashing.
  final Color beaconRed;

  /// Police strobe red (~630 nm).
  final Color policeRed;

  /// Police strobe blue (~465 nm).
  final Color policeBlue;

  /// COLREGS port (left) navigation light — red.
  final Color shipPort;

  /// COLREGS starboard (right) navigation light — green.
  final Color shipStarboard;

  /// COLREGS masthead/stern navigation light — white.
  final Color shipMast;

  /// Helicopter red anti-collision beacon.
  final Color heliBeacon;

  /// Helicopter white anti-collision strobe.
  final Color heliStrobe;

  BackdropPalette copyWith({
    Color? skyZenith,
    Color? skyUpper,
    Color? skyHorizonCool,
    Color? skyEmber,
    Color? sunsetGlow,
    Color? sunsetHot,
    Color? hazeSmog,
    Color? moonDisk,
    Color? moonHalo,
    Color? star,
    Color? cloudLit,
    Color? cloudBase,
    Color? skylineFar,
    Color? skylineNear,
    Color? buildingRim,
    Color? windowSodium,
    Color? windowLed,
    Color? bridgeStruct,
    Color? bridgeCable,
    Color? yachtHull,
    Color? yachtCabinGlow,
    Color? oceanHorizon,
    Color? oceanNear,
    Color? foam,
    Color? moonGlint,
    Color? beaconRed,
    Color? policeRed,
    Color? policeBlue,
    Color? shipPort,
    Color? shipStarboard,
    Color? shipMast,
    Color? heliBeacon,
    Color? heliStrobe,
  }) {
    return BackdropPalette(
      skyZenith: skyZenith ?? this.skyZenith,
      skyUpper: skyUpper ?? this.skyUpper,
      skyHorizonCool: skyHorizonCool ?? this.skyHorizonCool,
      skyEmber: skyEmber ?? this.skyEmber,
      sunsetGlow: sunsetGlow ?? this.sunsetGlow,
      sunsetHot: sunsetHot ?? this.sunsetHot,
      hazeSmog: hazeSmog ?? this.hazeSmog,
      moonDisk: moonDisk ?? this.moonDisk,
      moonHalo: moonHalo ?? this.moonHalo,
      star: star ?? this.star,
      cloudLit: cloudLit ?? this.cloudLit,
      cloudBase: cloudBase ?? this.cloudBase,
      skylineFar: skylineFar ?? this.skylineFar,
      skylineNear: skylineNear ?? this.skylineNear,
      buildingRim: buildingRim ?? this.buildingRim,
      windowSodium: windowSodium ?? this.windowSodium,
      windowLed: windowLed ?? this.windowLed,
      bridgeStruct: bridgeStruct ?? this.bridgeStruct,
      bridgeCable: bridgeCable ?? this.bridgeCable,
      yachtHull: yachtHull ?? this.yachtHull,
      yachtCabinGlow: yachtCabinGlow ?? this.yachtCabinGlow,
      oceanHorizon: oceanHorizon ?? this.oceanHorizon,
      oceanNear: oceanNear ?? this.oceanNear,
      foam: foam ?? this.foam,
      moonGlint: moonGlint ?? this.moonGlint,
      beaconRed: beaconRed ?? this.beaconRed,
      policeRed: policeRed ?? this.policeRed,
      policeBlue: policeBlue ?? this.policeBlue,
      shipPort: shipPort ?? this.shipPort,
      shipStarboard: shipStarboard ?? this.shipStarboard,
      shipMast: shipMast ?? this.shipMast,
      heliBeacon: heliBeacon ?? this.heliBeacon,
      heliStrobe: heliStrobe ?? this.heliStrobe,
    );
  }
}

/// The default blue-hour Lagos-lagoon palette. See [BackdropPalette] for the
/// per-token physical justification.
const BackdropPalette kBlueHourPalette = BackdropPalette(
  skyZenith: Color(0xFF0A1733),
  skyUpper: Color(0xFF12305C),
  skyHorizonCool: Color(0xFF285E78),
  skyEmber: Color(0xFF9C5A33),
  sunsetGlow: Color(0xFFB5532E),
  sunsetHot: Color(0xFFE8A552),
  hazeSmog: Color(0xFF3A4252),
  moonDisk: Color(0xFFF2E9CF),
  moonHalo: Color(0xFF9FBBD6),
  star: Color(0xFFEAF0FF),
  cloudLit: Color(0xFFC4D2E2),
  cloudBase: Color(0xFF2B3754),
  skylineFar: Color(0xFF213A5C),
  skylineNear: Color(0xFF0D1A30),
  buildingRim: Color(0xFF6C8098),
  windowSodium: Color(0xFFFFB257),
  windowLed: Color(0xFFDCEBFF),
  bridgeStruct: Color(0xFF14233B),
  bridgeCable: Color(0xFF43536D),
  yachtHull: Color(0xFF16283C),
  yachtCabinGlow: Color(0xFFFFCE86),
  oceanHorizon: Color(0xFF123847),
  oceanNear: Color(0xFF08202D),
  foam: Color(0xFFD7E6EA),
  moonGlint: Color(0xFFE6D6A8),
  beaconRed: Color(0xFFFF2A1F),
  policeRed: Color(0xFFFF1736),
  policeBlue: Color(0xFF1E59FF),
  shipPort: Color(0xFFE23A2E),
  shipStarboard: Color(0xFF1FB85A),
  shipMast: Color(0xFFFFF3DE),
  heliBeacon: Color(0xFFFF2A1F),
  heliStrobe: Color(0xFFFFFFFF),
);
