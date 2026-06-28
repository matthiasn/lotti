import 'dart:math' as math;
import 'dart:ui' show Color;

/// The default cinematic gel cycle each light snaps through on the beat: a hot
/// Afrobeats-luxe triad — warm **gold** (the hero, tying to the city windows +
/// deck lanterns), a dusk fuchsia, and an electric violet. All-warm/jewel, no
/// festival-cyan. Pulled back from pure-neon saturation (~20%) so the gels read
/// as light that belongs in the blue-hour world — biased toward the lantern
/// amber / dusk-magenta of the plate — rather than arcade decals over it.
const List<Color> kStageGelCycle = [
  Color(0xFFE7A030), // warm gold (hero) — deepened amber so additive pools/rims
  // stay GOLD when hot instead of blowing to white at the beat.
  Color(0xFFE85F97), // dusk fuchsia / rose-magenta
  Color(0xFFB163E0), // muted electric violet
];

/// One concert light resolved for a single frame. [targetX] is normalized 0..1
/// across the stage width; [intensity] is 0..1 brightness.
class StageLightSample {
  const StageLightSample({
    required this.color,
    required this.targetX,
    required this.intensity,
  });

  /// Current cycle colour for this light this frame — the gel used for both the
  /// dancer's rim/halo (drawn by `CharacterPainter`) and the floor pool.
  final Color color;

  /// The light's landing x on the floor — the centre of its pool. Sweeps gently
  /// around its anchor; overridden by the live dancer foot when tracking.
  final double targetX;

  /// 0..1 brightness this frame (base + beat boost).
  final double intensity;
}

/// Pure, deterministic scheduler for a row of beat-snapping RGB concert lights.
/// It owns no clock and no canvas: feed it the scene time and the 0..1 beat
/// envelope and it returns each light's colour, pool position and brightness for
/// that frame. The demo feeds the colours into each cat's rim/halo
/// (`CharacterPainter.memberBacklights`) and the overlay draws the floor pools;
/// tests assert the maths directly.
class StageLightRig {
  const StageLightRig({
    this.count = 3,
    this.colors = kStageGelCycle,
    this.anchors = const [0.30, 0.5, 0.70],
    this.sweep = 0.06,
    this.sweepHz = 0.12,
    this.colorPeriod = 0.5,
    this.baseIntensity = 0.38,
    this.beatBoost = 0.4,
    this.leadGoldIndex,
  }) : assert(count > 0, 'need at least one light'),
       assert(colorPeriod > 0, 'colorPeriod must be > 0');

  /// Number of lights (one per dancer by default).
  final int count;

  /// Discrete colour cycle each light snaps through.
  final List<Color> colors;

  /// Floor anchor x per light; indexed modulo its length.
  final List<double> anchors;

  /// Sweep amplitude as a fraction of stage width.
  final double sweep;

  /// Sweep frequency in Hz (how fast the beams pan side to side).
  final double sweepHz;

  /// Seconds each colour holds before snapping to the next (≈ one beat at the
  /// track tempo — wire `60 / bpm` to lock the snaps to the beat).
  final double colorPeriod;

  /// Brightness with no beat present.
  final double baseIntensity;

  /// Extra brightness added at full beat.
  final double beatBoost;

  /// When set, this lane (the hero/lead) holds [colors]`[0]` every frame instead
  /// of rotating, so the lead reads as a consistent hero colour (gold) while the
  /// flankers still cycle. Null rotates every lane.
  final int? leadGoldIndex;

  /// The colour index light [i] shows at [time]: discrete (it snaps, never
  /// lerps) and offset per light so the row reads as R/G/B rotating rather than
  /// every beam flashing the same colour at once. The [leadGoldIndex] lane is
  /// pinned to index 0 (the hero gold).
  int colorIndexAt(int i, double time) {
    if (i == leadGoldIndex) return 0;
    final step = (time / colorPeriod).floor();
    final n = colors.length;
    return ((step + i) % n + n) % n;
  }

  /// Resolve every light for one frame. With [reducedMotion] the row freezes to
  /// a calm static frame (no sweep, no beat boost).
  List<StageLightSample> sample({
    required double time,
    double beat = 0,
    bool reducedMotion = false,
  }) {
    final t = reducedMotion ? 0.0 : time;
    final b = reducedMotion ? 0.0 : beat.clamp(0.0, 1.0);
    return List<StageLightSample>.generate(count, (i) {
      final anchor = anchors[i % anchors.length];
      final phase = i * (math.pi * 2 / count);
      final osc = reducedMotion
          ? 0.0
          : math.sin(2 * math.pi * sweepHz * t + phase);
      // The pool drifts gently around its anchor (a slow sweep); when the
      // overlay has live dancer anchors it overrides this with the real foot.
      final targetX = (anchor + sweep * osc).clamp(0.0, 1.0);
      return StageLightSample(
        color: colors[colorIndexAt(i, t)],
        targetX: targetX,
        intensity: (baseIntensity + beatBoost * b).clamp(0.0, 1.0),
      );
    });
  }
}
