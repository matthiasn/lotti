import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show immutable;
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/plaza/domain/attention.dart';
import 'package:lotti/features/plaza/domain/plaza_task.dart';
import 'package:material_ui/material_ui.dart' show Colors;

/// Which sky the world is built under.
///
/// The plaza renders with unlit materials, so nothing here is a light: the
/// hour is *painted*. A mode selects a whole [PlazaPalette] — sky, haze,
/// paving, walls, and how far emitters are pushed — and the scene is rebuilt
/// with it. There is no blend between the two; a switch is a rebuild.
enum PlazaSkyMode {
  night,
  day;

  /// `PLAZA_DAY=1` boots the fixture into daylight.
  static PlazaSkyMode fromEnvironment(Map<String, String> env) =>
      env['PLAZA_DAY'] == '1' ? day : night;

  /// The stored preference. An unknown or missing name is night, the mode
  /// the world was designed in.
  static PlazaSkyMode fromName(String? name) => PlazaSkyMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => night,
  );
}

/// The dome: a zenith-to-horizon gradient with a sun disk in it.
///
/// Both modes use the same gradient source, so the only difference is its
/// numbers. Night's sun is black at zero intensity, which is what makes
/// [hasSun] — and with it every sun-derived effect, shading and shadows —
/// false without a second code path.
@immutable
class PlazaSky {
  const PlazaSky({
    required this.zenith,
    required this.horizon,
    required this.ground,
    required this.sun,
    required this.sunIntensity,
    required this.sunAzimuth,
    required this.sunElevation,
    required this.sunSharpness,
  });

  /// Straight up.
  final Color zenith;

  /// Where the sky meets the district.
  final Color horizon;

  /// Below the horizon; the fog resolves into it at eye level.
  final Color ground;

  /// The disk's hue. Multiplied by [sunIntensity] into the HDR value the
  /// bloom pass sees, so a sun above 1.0 blooms and a night sky does not.
  final Color sun;
  final double sunIntensity;

  /// Where the sun stands. Azimuth is measured from +Z toward +X, the way
  /// the street's yaws are; elevation rises from the horizon.
  final double sunAzimuth;
  final double sunElevation;

  /// Disk tightness; higher is a smaller, harder sun.
  final double sunSharpness;

  /// Whether anything is up there to cast light. Night has a sun in the
  /// data (a black one at zero intensity) so the shader binding stays one
  /// shape; this is the question the scene actually asks.
  bool get hasSun => sunIntensity > 0;

  /// Unit vector toward the sun.
  ({double x, double y, double z}) get sunDirection => (
    x: math.cos(sunElevation) * math.sin(sunAzimuth),
    y: math.sin(sunElevation),
    z: math.cos(sunElevation) * math.cos(sunAzimuth),
  );

  /// How far a [height]-metre wall throws its shadow across the paving.
  /// Clamped because a low sun would otherwise stretch a tower's shadow
  /// across the whole district and swallow the street.
  double shadowLength(double height) {
    if (!hasSun) return 0;
    final tangent = math.tan(sunElevation);
    if (tangent <= 0) return maxShadowLength;
    return math.min(height / tangent, maxShadowLength);
  }

  /// Metres. A shadow longer than this reads as a stain, not a shadow.
  static const maxShadowLength = 26.0;
}

/// What the air does between the camera and the district: haze, bloom and
/// vignette. Every value the sky pass and the scene controller write per
/// frame lives here rather than as a scene constant, so the hour owns them.
@immutable
class PlazaAir {
  const PlazaAir({
    required this.fog,
    required this.fogDensityLow,
    required this.fogDensityHigh,
    required this.fogOpacityLow,
    required this.fogOpacityHigh,
    required this.bloomThreshold,
    required this.bloomIntensity,
    required this.bloomScatter,
    required this.vignetteIntensity,
    required this.vignetteRadius,
    required this.vignetteSmoothness,
  });

  /// The haze's own colour: between the ground and the horizon, so it never
  /// outshines the paving the walker stands on.
  final Color fog;

  /// Haze at eye level and from the air. It thins as the camera climbs so
  /// the overview sees a district rather than a wash.
  final double fogDensityLow;
  final double fogDensityHigh;
  final double fogOpacityLow;
  final double fogOpacityHigh;

  /// HDR brightness above which a pixel blooms, how much comes back, and
  /// how wide it spreads.
  final double bloomThreshold;
  final double bloomIntensity;
  final double bloomScatter;

  /// A zero intensity disables the vignette outright.
  final double vignetteIntensity;
  final double vignetteRadius;
  final double vignetteSmoothness;

  bool get hasVignette => vignetteIntensity > 0;

  /// The bloom is worth running when something can exceed its threshold.
  bool get hasBloom => bloomIntensity > 0;
}

/// The flat colours of the built world. Under unlit materials these are the
/// final pixels, not albedos waiting for a light — which is why the day set
/// is mid-toned rather than white: a sunlit concrete slab photographs
/// around 70 % grey, and painting it white leaves nothing for the sun.
@immutable
class PlazaSurfaceColors {
  const PlazaSurfaceColors({
    required this.ground,
    required this.road,
    required this.gap,
    required this.post,
    required this.tower,
    required this.pavement,
    required this.kerb,
    required this.centreLine,
    required this.cornice,
    required this.plotBase,
    required this.plotRim,
    required this.unlitNeon,
    required this.riser,
    required this.timber,
    required this.ironwork,
    required this.foliage,
    required this.wallBase,
    required this.roofBase,
    required this.doneWallBase,
    required this.cable,
  });

  /// The ground plane and the plaza slab flush with it.
  final Color ground;
  final Color road;
  final Color gap;

  /// Lamp posts, pylons and other slender structure.
  final Color post;

  /// The far skyline's towers, already half lost in haze.
  final Color tower;

  final Color pavement;
  final Color kerb;
  final Color centreLine;

  /// The band under a roofline: the wall's own colour, a shade along.
  final Color cornice;

  /// A plot's plinth and the rim around it.
  final Color plotBase;
  final Color plotRim;

  /// What a neon strip is made of before it is lit — the housing. Night
  /// lerps its neon out of this; by day the strips never leave it.
  final Color unlitNeon;

  /// Stair and balcony risers on the filler blocks.
  final Color riser;

  /// Benches, planters and their foliage.
  final Color timber;
  final Color ironwork;
  final Color foliage;

  /// What a category's colour is mixed into for a task's walls and roof.
  final Color wallBase;
  final Color roofBase;

  /// A connection cable strung between two roofs. Near-black reads as a
  /// wire against the night; against a pale sky it reads as ink, so
  /// daylight lifts it to the grey of a real span.
  final Color cable;

  /// What the success green is mixed into for a finished task's walls.
  /// Separate from [wallBase] because a done block is not a tinted category
  /// block: it is set back, quiet, and reads green rather than coloured.
  final Color doneWallBase;
}

/// How light behaves in this hour: how far emitters are pushed past white,
/// whether the ground carries pools of it, and what the sun leaves behind.
@immutable
class PlazaLightSettings {
  const PlazaLightSettings({
    required this.emissiveBoost,
    required this.groundLightScale,
    required this.glowScale,
    required this.lampsLit,
    required this.shadowAlpha,
    required this.shadow,
    required this.lamp,
    required this.interior,
    required this.parade,
    required this.skyGlow,
    required this.warning,
  });

  /// How far past display white a lit emitter goes, so the bloom pass picks
  /// it up. Daylight is 1.0: nothing outshines the sky, so nothing blooms.
  final double emissiveBoost;

  /// Multiplies every ground pool and wash. Zero removes them, which is
  /// what daylight wants — a pool of lamplight on sunlit paving is a smudge.
  final double groundLightScale;

  /// Multiplies the soft glow quads behind emitters (neon, signage, roof
  /// lanterns).
  final double glowScale;

  /// Whether the street lamps burn. Their posts stand either way.
  final bool lampsLit;

  /// The opacity of a building's contact shadow. Zero means no shadows,
  /// which is the only honest option when there is no sun.
  final double shadowAlpha;

  /// The shadow's colour, multiplied onto the paving beneath it.
  final Color shadow;

  /// Warm sodium-vapour lamp light.
  final Color lamp;

  /// Light spilling out of a window or a doorway.
  final Color interior;

  /// The amber a lit shopfront parade throws onto the pavement.
  final Color parade;

  /// The warm bloom a city throws onto its own horizon.
  final Color skyGlow;

  /// Aircraft warning light on the spires. It blinks by day too — that is
  /// what it is for.
  final Color warning;

  bool get hasShadows => shadowAlpha > 0;
}

/// The roof lantern's colour per state, and with it the facade light bar,
/// the billboard frame and every sprite that carries a task's health.
///
/// Night states are lights in the dark. The day set answers a different
/// question — what reads as a coloured mark against a bright sky — so the
/// hues hold but the values drop; a pale cream lantern that glows at
/// midnight disappears at noon.
@immutable
class PlazaLanterns {
  const PlazaLanterns({
    required this.blocked,
    required this.overdue,
    required this.inProgress,
    required this.open,
    required this.off,
  });

  final Color blocked;
  final Color overdue;
  final Color inProgress;
  final Color open;
  final Color off;

  Color of(LanternState state) => switch (state) {
    LanternState.blocked => blocked,
    LanternState.overdue => overdue,
    LanternState.inProgress => inProgress,
    LanternState.open => open,
    LanternState.off => off,
  };
}

/// Everything the hour decides, in one value.
///
/// The scene holds one of these and reads every colour and atmospheric
/// number from it. Nothing in `scene/` may keep a colour constant of its
/// own: a value that is not here cannot change with the sky, and that is
/// exactly the bug this type exists to prevent.
@immutable
class PlazaPalette {
  const PlazaPalette({
    required this.mode,
    required this.sky,
    required this.air,
    required this.surfaces,
    required this.lights,
    required this.lanterns,
  });

  final PlazaSkyMode mode;
  final PlazaSky sky;
  final PlazaAir air;
  final PlazaSurfaceColors surfaces;
  final PlazaLightSettings lights;
  final PlazaLanterns lanterns;

  bool get isDay => mode == PlazaSkyMode.day;

  static PlazaPalette of(PlazaSkyMode mode) => switch (mode) {
    PlazaSkyMode.night => night,
    PlazaSkyMode.day => day,
  };

  /// A task's own colour: done is the success green, everything else is its
  /// lantern. The facade light bar, the sprite and the sign frame share it.
  Color taskColor(TaskAttention attention) =>
      attention.task.state == PlazaTaskState.done
      ? dsTokensDark.colors.alert.success.defaultColor
      : lanterns.of(attention.lantern);

  /// The dim wall tint: the category's colour mixed into this hour's wall
  /// base. A finished task's walls take the success green instead, at the
  /// same strength, so a done block reads as done before its sign is legible.
  Color categoryWall(PlazaTask task) => task.state == PlazaTaskState.done
      ? Color.lerp(
          surfaces.doneWallBase,
          dsTokensDark.colors.alert.success.defaultColor,
          _doneMix,
        )!
      : Color.lerp(surfaces.wallBase, Color(task.categoryColor), _wallMix)!;

  /// The roof: the same mix, a step darker, and the surface the aerial
  /// overview actually reads.
  Color categoryRoof(PlazaTask task) => task.state == PlazaTaskState.done
      ? dsTokensDark.colors.alert.success.defaultColor
      : Color.lerp(surfaces.roofBase, Color(task.categoryColor), _roofMix)!;

  static const _wallMix = 0.28;
  static const _roofMix = 0.22;

  /// How much success green a finished task's walls take. Night borrowed
  /// the design system's muted alpha; daylight needs more of it, because a
  /// pale wall swallows a tint that reads fine against a dark one.
  double get _doneMix => isDay ? 0.5 : SurfaceAlphas.muted;

  /// The night the district was designed in: a desaturated indigo dusk, so
  /// amber signage sits warm against it and the magenta lives in the hero
  /// towers' domes alone.
  static const night = PlazaPalette(
    mode: PlazaSkyMode.night,
    sky: PlazaSky(
      zenith: Color(0xFF03030B),
      horizon: Color(0xFF2A2446),
      ground: Color(0xFF090A16),
      sun: Colors.black,
      sunIntensity: 0,
      sunAzimuth: 0,
      sunElevation: 0,
      sunSharpness: 400,
    ),
    air: PlazaAir(
      fog: Color(0xFF181727),
      fogDensityLow: 0.0055,
      fogDensityHigh: 0.002,
      fogOpacityLow: 0.92,
      fogOpacityHigh: 0.6,
      bloomThreshold: 1,
      bloomIntensity: 0.3,
      bloomScatter: 0.6,
      vignetteIntensity: 0.32,
      vignetteRadius: 0.82,
      vignetteSmoothness: 0.6,
    ),
    surfaces: PlazaSurfaceColors(
      ground: Color(0xFF15131E),
      road: Color(0xFF1A1D2B),
      gap: Color(0xFF15171F),
      post: Color(0xFF14171F),
      tower: Color(0xFF0E0B18),
      pavement: Color(0xFF232532),
      kerb: Color(0xFF5A5E72),
      centreLine: Color(0xFF7A7050),
      cornice: Color(0xFF141220),
      plotBase: Color(0xFF0A0910),
      plotRim: Color(0xFF07060D),
      unlitNeon: Color(0xFF0B0A14),
      riser: Color(0xFF14161C),
      timber: Color(0xFF4A3A2E),
      ironwork: Color(0xFF1E1A1C),
      foliage: Color(0xFF1F3A28),
      wallBase: Color(0xFF3B3F4A),
      roofBase: Color(0xFF262A33),
      // `dsTokensDark.colors.background.level01`, which is not a constant
      // and so cannot be named here; a palette test pins the two together.
      doneWallBase: Color(0xFF181818),
      // `dsTokensDark.colors.background.level03`; pinned by a palette test.
      cable: Color(0xFF535353),
    ),
    lights: PlazaLightSettings(
      emissiveBoost: 1.6,
      groundLightScale: 1,
      glowScale: 1,
      lampsLit: true,
      shadowAlpha: 0,
      shadow: Colors.black,
      lamp: Color(0xFFFFD08A),
      interior: Color(0xFFFFE2B8),
      parade: Color(0xFFFFC46B),
      skyGlow: Color(0xFFFF7A4A),
      warning: Color(0xFFFF3B30),
    ),
    lanterns: PlazaLanterns(
      blocked: Color(0xFFE4655F),
      overdue: Color(0xFFFBA336),
      inProgress: Color(0xFF4AB6E8),
      open: Color(0xFFD0C2A0),
      off: Color(0xFF3A3F48),
    ),
  );

  /// Clear mid-morning: a high sun across the avenue, concrete and asphalt
  /// at their real values, and light that is in the sky rather than in the
  /// buildings. Every emitter falls back to its housing, the ground pools
  /// go out, and what a task is doing has to survive on paint, shadow and
  /// signage instead.
  static const day = PlazaPalette(
    mode: PlazaSkyMode.day,
    sky: PlazaSky(
      zenith: Color(0xFF2F6FD0),
      horizon: Color(0xFFC4DCF2),
      ground: Color(0xFF7E7A6E),
      sun: Color(0xFFFFF3D6),
      sunIntensity: 7,
      // Across the avenue rather than down it, and behind the district
      // rather than behind the walker: facades keep their relief, and the
      // shade the signs throw falls toward the camera instead of hiding
      // behind them.
      sunAzimuth: 5.34,
      sunElevation: 0.72,
      sunSharpness: 900,
    ),
    air: PlazaAir(
      fog: Color(0xFFBFD3E6),
      // Thinner than night: distance should read as aerial perspective,
      // not as a wall of haze two blocks out.
      fogDensityLow: 0.0026,
      fogDensityHigh: 0.0011,
      fogOpacityLow: 0.7,
      fogOpacityHigh: 0.42,
      // Above the sky's own brightness, so only the sun disk blooms.
      bloomThreshold: 1.4,
      bloomIntensity: 0.1,
      bloomScatter: 0.5,
      vignetteIntensity: 0,
      vignetteRadius: 0.9,
      vignetteSmoothness: 0.6,
    ),
    surfaces: PlazaSurfaceColors(
      ground: Color(0xFF8E8B84),
      road: Color(0xFF6E7079),
      gap: Color(0xFF7A7C85),
      post: Color(0xFF5A5E68),
      tower: Color(0xFF9AA3B4),
      pavement: Color(0xFFB4B0A6),
      kerb: Color(0xFFD6D2C6),
      centreLine: Color(0xFFE8D9A0),
      cornice: Color(0xFFA9A296),
      plotBase: Color(0xFF6B6A66),
      plotRim: Color(0xFF4E4D4A),
      unlitNeon: Color(0xFF8C93A3),
      riser: Color(0xFF7C8089),
      timber: Color(0xFF8A6A4E),
      ironwork: Color(0xFF3E3A3C),
      foliage: Color(0xFF4E7A46),
      wallBase: Color(0xFFB9BEC8),
      roofBase: Color(0xFF9AA0AC),
      doneWallBase: Color(0xFFC8CCC4),
      cable: Color(0xFF6E727A),
    ),
    lights: PlazaLightSettings(
      emissiveBoost: 1,
      groundLightScale: 0,
      glowScale: 0.25,
      lampsLit: false,
      shadowAlpha: 0.72,
      shadow: Color(0xFF2A3038),
      // Unchanged from night, and unused: daylight scales every pool and
      // wash they colour to nothing.
      lamp: Color(0xFFFFD08A),
      interior: Color(0xFFFFE2B8),
      parade: Color(0xFFFFC46B),
      skyGlow: Color(0xFFFF7A4A),
      warning: Color(0xFFFF3B30),
    ),
    lanterns: PlazaLanterns(
      blocked: Color(0xFFC0332C),
      overdue: Color(0xFFD9781B),
      inProgress: Color(0xFF1F7FBF),
      open: Color(0xFF6E6350),
      off: Color(0xFF5A5F68),
    ),
  );
}
