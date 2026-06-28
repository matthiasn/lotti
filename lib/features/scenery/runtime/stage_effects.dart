import 'dart:math' as math;
import 'dart:ui' show Color, Offset;

import 'package:lotti/features/scenery/runtime/stage_lights.dart';
import 'package:meta/meta.dart';

/// The particle language for the dance stage effects.
///
/// These are scenery-stage effects, not design-system celebrations. The visual
/// math intentionally borrows the deterministic, index-seeded approach from the
/// completion celebrations, but the scheduling and staging are local to scenery
/// so the character showcase can be extracted cleanly.
enum StageEffectKind {
  /// Narrow white-gold spark fountains from the rear deck line.
  coldSparks,

  /// Side-cannon ribbons that arc inward and fall.
  confetti,

  /// Soft bubbles drifting in from the side wings.
  bubbles,

  /// Warm post-pyro motes close to the floor.
  embers,
}

/// A coarse section span from the audio analysis / lyric structure.
class StageEffectSection {
  const StageEffectSection({
    required this.startSeconds,
    required this.endSeconds,
    required this.label,
    required this.energetic,
  }) : assert(endSeconds >= startSeconds, 'section end before start');

  final double startSeconds;
  final double endSeconds;
  final String label;
  final bool energetic;

  double get durationSeconds => endSeconds - startSeconds;
}

/// A deterministic one-shot effect trigger in normalized stage coordinates.
class StageEffectCue {
  const StageEffectCue({
    required this.kind,
    required this.startSeconds,
    required this.durationSeconds,
    required this.origin,
    required this.directionRadians,
    required this.intensity,
    this.lane,
    this.count,
    this.reach,
  }) : assert(durationSeconds > 0, 'effect duration must be positive'),
       assert(intensity >= 0 && intensity <= 1, 'intensity must be 0..1');

  final StageEffectKind kind;
  final double startSeconds;
  final double durationSeconds;
  final Offset origin;

  /// Particle launch direction in screen radians (`-pi/2` = straight up).
  final double directionRadians;

  /// Base visual strength, 0..1.
  final double intensity;

  /// Optional dancer/light lane used to pick a gel color.
  final int? lane;

  /// Optional particle count override.
  final int? count;

  /// Optional reach override as a fraction of stage height.
  final double? reach;
}

/// One active effect resolved for a painter at one playback time.
@immutable
class StageParticleSample {
  const StageParticleSample({
    required this.kind,
    required this.progress,
    required this.origin,
    required this.directionRadians,
    required this.palette,
    required this.count,
    required this.reach,
    required this.intensity,
    this.lane,
  });

  final StageEffectKind kind;
  final double progress;
  final Offset origin;
  final double directionRadians;
  final List<Color> palette;
  final int count;
  final double reach;
  final double intensity;
  final int? lane;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StageParticleSample &&
          other.kind == kind &&
          other.progress == progress &&
          other.origin == origin &&
          other.directionRadians == directionRadians &&
          _colorListsEqual(other.palette, palette) &&
          other.count == count &&
          other.reach == reach &&
          other.intensity == intensity &&
          other.lane == lane;

  @override
  int get hashCode => Object.hash(
    kind,
    progress,
    origin,
    directionRadians,
    Object.hashAll(palette),
    count,
    reach,
    intensity,
    lane,
  );
}

/// Pure cue scheduler. It owns no clock and no canvas.
class StageEffectScheduler {
  const StageEffectScheduler({
    this.maxConcurrentBursts = 8,
    this.beatIntensityBoost = 0.24,
  }) : assert(maxConcurrentBursts > 0, 'need at least one burst slot');

  final int maxConcurrentBursts;
  final double beatIntensityBoost;

  List<StageParticleSample> sample({
    required double positionSeconds,
    required double beat,
    required List<StageEffectCue> cues,
    required List<StageLightSample> lights,
    bool reducedMotion = false,
  }) {
    if (reducedMotion) return const [];
    final active = <StageParticleSample>[];
    final clampedBeat = beat.clamp(0.0, 1.0);
    for (final cue in cues) {
      final dt = positionSeconds - cue.startSeconds;
      if (dt < 0 || dt >= cue.durationSeconds) continue;
      final progress = (dt / cue.durationSeconds).clamp(0.0, 1.0);
      final intensity = (cue.intensity * (1 + beatIntensityBoost * clampedBeat))
          .clamp(0.0, 1.0);
      active.add(
        StageParticleSample(
          kind: cue.kind,
          progress: progress,
          origin: _clampOffset(cue.origin),
          directionRadians: cue.directionRadians,
          palette: _paletteFor(cue, lights),
          count: cue.count ?? _defaultCount(cue.kind, intensity),
          reach: cue.reach ?? _defaultReach(cue.kind),
          intensity: intensity,
          lane: cue.lane,
        ),
      );
    }
    active.sort((a, b) => b.intensity.compareTo(a.intensity));
    return active.length <= maxConcurrentBursts
        ? active
        : active.take(maxConcurrentBursts).toList(growable: false);
  }
}

/// Builds a restrained "Afro-luxe" stage-effects score from generic beat and
/// section data: rear cold sparks on energetic downbeats, side confetti on
/// section hits, bubbles in calmer/bridge spans, and warm embers as fallout.
class StageEffectCueBuilder {
  const StageEffectCueBuilder({
    this.sparkEveryDownbeats = 2,
    this.bubbleEveryDownbeats = 2,
  }) : assert(
         sparkEveryDownbeats > 0,
         'sparkEveryDownbeats must be positive',
       ),
       assert(
         bubbleEveryDownbeats > 0,
         'bubbleEveryDownbeats must be positive',
       );

  final int sparkEveryDownbeats;
  final int bubbleEveryDownbeats;

  List<StageEffectCue> build({
    required List<double> beatTimesSec,
    required List<int> downbeatIndices,
    required List<StageEffectSection> sections,
    double trackDurationSeconds = 0,
  }) {
    if (sections.isEmpty || beatTimesSec.isEmpty) return const [];
    final cues = <StageEffectCue>[];
    final downbeats = downbeatIndices.isEmpty
        ? <int>[
            for (var i = 0; i < beatTimesSec.length; i += 4) i,
          ]
        : downbeatIndices;

    for (var si = 0; si < sections.length; si++) {
      final section = sections[si];
      if (section.durationSeconds <= 0) continue;
      final label = section.label.toLowerCase();
      final hero = _isHeroSection(label, section.energetic, si);
      final bridgeLike = label.contains('bridge') || label.contains('break');
      final safeStart = math.max<double>(0, section.startSeconds + 0.04);

      if (section.energetic && hero) {
        cues
          ..add(_leftConfetti(safeStart, lane: 0, intensity: 0.84))
          ..add(_rightConfetti(safeStart + 0.08, lane: 2, intensity: 0.84))
          ..add(_rearSpark(safeStart + 0.02, 0.33, lane: 0, intensity: 0.8))
          ..add(_rearSpark(safeStart + 0.10, 0.67, lane: 2, intensity: 0.8));
      } else if (!section.energetic || bridgeLike) {
        cues
          ..add(_leftBubbles(safeStart, lane: 0, intensity: 0.62))
          ..add(_rightBubbles(safeStart + 0.35, lane: 2, intensity: 0.62));
      }

      var localDownbeat = 0;
      for (final beatIndex in downbeats) {
        if (beatIndex < 0 || beatIndex >= beatTimesSec.length) continue;
        final t = beatTimesSec[beatIndex];
        if (t < section.startSeconds || t >= section.endSeconds) continue;
        if (section.energetic) {
          if (localDownbeat % sparkEveryDownbeats == 0) {
            final x = localDownbeat.isEven ? 0.24 : 0.76;
            cues
              ..add(
                _rearSpark(
                  t,
                  x,
                  lane: localDownbeat.isEven ? 0 : 2,
                  intensity: hero ? 0.78 : 0.58,
                ),
              )
              ..add(
                _emberFallout(
                  t + 0.38,
                  x,
                  lane: localDownbeat.isEven ? 0 : 2,
                  intensity: hero ? 0.56 : 0.38,
                ),
              );
          }
        } else if (localDownbeat % bubbleEveryDownbeats == 0) {
          cues.add(
            localDownbeat.isEven
                ? _leftBubbles(t, lane: 0, intensity: 0.46)
                : _rightBubbles(t, lane: 2, intensity: 0.46),
          );
        }
        localDownbeat++;
      }
    }

    final end = trackDurationSeconds <= 0
        ? beatTimesSec.last
        : trackDurationSeconds;
    return cues.where((c) => c.startSeconds < end).toList(growable: false)
      ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
  }
}

const _whiteGold = Color(0xFFFFF6C8);
const _stageGold = Color(0xFFFFB547);
const _stageFuchsia = Color(0xFFFF3C93);
const _stageViolet = Color(0xFFC058FF);
const _stageBlue = Color(0xFF83C7FF);
const _stageOrange = Color(0xFFFF7A1E);
const _stageRed = Color(0xFFFF3B25);

StageEffectCue _rearSpark(
  double start,
  double x, {
  required int lane,
  required double intensity,
}) => StageEffectCue(
  kind: StageEffectKind.coldSparks,
  startSeconds: start,
  durationSeconds: 0.82,
  origin: Offset(x, 0.69),
  directionRadians: -math.pi / 2,
  intensity: intensity.clamp(0.0, 1.0),
  lane: lane,
  reach: 0.31,
);

StageEffectCue _emberFallout(
  double start,
  double x, {
  required int lane,
  required double intensity,
}) => StageEffectCue(
  kind: StageEffectKind.embers,
  startSeconds: start,
  durationSeconds: 1.15,
  origin: Offset(x, 0.72),
  directionRadians: -math.pi / 2,
  intensity: intensity.clamp(0.0, 1.0),
  lane: lane,
  reach: 0.18,
);

StageEffectCue _leftConfetti(
  double start, {
  required int lane,
  required double intensity,
}) => StageEffectCue(
  kind: StageEffectKind.confetti,
  startSeconds: start,
  durationSeconds: 1.9,
  origin: const Offset(0.05, 0.79),
  directionRadians: -0.92,
  intensity: intensity.clamp(0.0, 1.0),
  lane: lane,
  reach: 0.58,
);

StageEffectCue _rightConfetti(
  double start, {
  required int lane,
  required double intensity,
}) => StageEffectCue(
  kind: StageEffectKind.confetti,
  startSeconds: start,
  durationSeconds: 1.9,
  origin: const Offset(0.95, 0.79),
  directionRadians: -2.22,
  intensity: intensity.clamp(0.0, 1.0),
  lane: lane,
  reach: 0.58,
);

StageEffectCue _leftBubbles(
  double start, {
  required int lane,
  required double intensity,
}) => StageEffectCue(
  kind: StageEffectKind.bubbles,
  startSeconds: start,
  durationSeconds: 3.2,
  origin: const Offset(0.05, 0.77),
  directionRadians: -0.72,
  intensity: intensity.clamp(0.0, 1.0),
  lane: lane,
  reach: 0.42,
);

StageEffectCue _rightBubbles(
  double start, {
  required int lane,
  required double intensity,
}) => StageEffectCue(
  kind: StageEffectKind.bubbles,
  startSeconds: start,
  durationSeconds: 3.2,
  origin: const Offset(0.95, 0.77),
  directionRadians: -2.42,
  intensity: intensity.clamp(0.0, 1.0),
  lane: lane,
  reach: 0.42,
);

bool _isHeroSection(String label, bool energetic, int index) {
  if (!energetic) return false;
  return label.contains('chorus') ||
      label.contains('hook') ||
      label.contains('drop') ||
      label.contains('outro') ||
      label.contains('final') ||
      index > 0;
}

Offset _clampOffset(Offset o) => Offset(
  o.dx.clamp(0.0, 1.0),
  o.dy.clamp(0.0, 1.0),
);

int _defaultCount(StageEffectKind kind, double intensity) {
  final base = switch (kind) {
    StageEffectKind.coldSparks => 30,
    StageEffectKind.confetti => 38,
    StageEffectKind.bubbles => 24,
    StageEffectKind.embers => 20,
  };
  return math.max(6, (base * (0.65 + 0.35 * intensity)).round());
}

double _defaultReach(StageEffectKind kind) => switch (kind) {
  StageEffectKind.coldSparks => 0.3,
  StageEffectKind.confetti => 0.55,
  StageEffectKind.bubbles => 0.4,
  StageEffectKind.embers => 0.18,
};

List<Color> _paletteFor(StageEffectCue cue, List<StageLightSample> lights) {
  final gel = cue.lane != null && lights.isNotEmpty
      ? lights[cue.lane! % lights.length].color
      : _stageGold;
  return switch (cue.kind) {
    StageEffectKind.coldSparks => [_whiteGold, _stageGold, gel],
    StageEffectKind.confetti => [
      gel,
      _stageGold,
      _stageFuchsia,
      _stageViolet,
      _whiteGold,
    ],
    StageEffectKind.bubbles => [gel, _stageBlue, _whiteGold],
    StageEffectKind.embers => [_stageGold, _stageOrange, _stageRed],
  };
}

bool _colorListsEqual(List<Color> a, List<Color> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
