/// A detected **beat grid** for an audio track, plus the maths to warp a looping
/// dance clip onto it so the choreography lands on the real beat.
///
/// This is the Dart consumer of the offline `tools/dance_audio/analyze.py`
/// artifact (Beat This! beats + downbeats). The clip stays authored in its own
/// normalized time (`DancePhrase` frames / counts); a [BeatMap] only **warps the
/// input time** — `clipSecondsAt` replaces the constant `× playbackRate` scalar
/// the demo uses today. Nothing inside the engine's `frameAt` pipeline changes,
/// so determinism and the film-strip "byte-identical renders" invariant hold for
/// a fixed beat map.
///
/// See `docs/implementation_plans/2026-06-27_dance_audio_analysis.md` (§3, §7).
library;

/// The beat grid: detected beat timestamps plus which of them are bar downbeats.
///
/// [beatTimesSec] are the anchors — strictly increasing, at least two. Tempo is
/// implicit in their spacing, so a *variable* tempo is captured for free (each
/// inter-beat interval carries its own local tempo).
///
/// Typical use — warp a looping clip onto a track's beats:
/// ```dart
/// final map = BeatMap.fromJson(
///   jsonDecode(beatMapJson) as Map<String, Object?>,
/// );
/// // A 2-bar loop anchored on a real downbeat (rung 3, bar-correct):
/// final binding = BeatLoopBinding.barAligned(map, bars: 2);
/// // In the ticker, warp wall-clock time onto the detected beats:
/// final clipSeconds = map.clipSecondsAt(
///   elapsedSeconds,
///   clipDuration: clip.duration,
///   binding: binding,
/// );
/// // ...then feed clipSeconds to the engine exactly as the constant-tempo
/// // path does today: scene.frameAt(clip, clipSeconds).
/// ```
class BeatMap {
  BeatMap({
    required this.beatTimesSec,
    required this.downbeatIndices,
    this.timeSignatureNumerator = 4,
  }) : assert(beatTimesSec.length >= 2, 'need at least two beats'),
       assert(timeSignatureNumerator > 0, 'time signature must be positive'),
       assert(_isStrictlyIncreasing(beatTimesSec), 'beat times must increase');

  /// Parses the `analyze.py` beat-map JSON (the §5 schema). `beats[]` is the
  /// source of truth; an entry with `is_downbeat == true` records its index as a
  /// downbeat.
  factory BeatMap.fromJson(Map<String, Object?> json) {
    final beats = (json['beats'] as List?)?.cast<Map<String, Object?>>();
    if (beats == null || beats.length < 2) {
      throw const FormatException(
        'beat map needs a "beats" array of length >= 2',
      );
    }
    final times = <double>[];
    final downbeats = <int>[];
    for (var i = 0; i < beats.length; i++) {
      times.add((beats[i]['time_sec']! as num).toDouble());
      if (beats[i]['is_downbeat'] == true) downbeats.add(i);
    }
    final ts = json['time_signature'] as Map<String, Object?>?;
    return BeatMap(
      beatTimesSec: times,
      downbeatIndices: downbeats,
      timeSignatureNumerator: (ts?['numerator'] as num?)?.toInt() ?? 4,
    );
  }

  /// Detected beat times in seconds, strictly increasing (the grid anchors).
  final List<double> beatTimesSec;

  /// Indices into [beatTimesSec] that are bar downbeats (the "1"s). May be empty
  /// when downbeats were not detected or are not trusted.
  final List<int> downbeatIndices;

  /// Beats per bar (default 4). Used to derive an integer-bar loop length.
  final int timeSignatureNumerator;

  /// Number of detected beats (the count of grid anchors).
  int get beatCount => beatTimesSec.length;

  /// Wall-clock [tSec] → fractional **beat index**, piecewise-linear over the
  /// detected anchors. Outside the detected range it extrapolates with the edge
  /// inter-beat interval, so it stays well-defined (and invertible) everywhere.
  double beatAt(double tSec) {
    final n = beatTimesSec.length;
    final first = beatTimesSec[0];
    final last = beatTimesSec[n - 1];
    if (tSec <= first) {
      return (tSec - first) / (beatTimesSec[1] - first);
    }
    if (tSec >= last) {
      return (n - 1) + (tSec - last) / (last - beatTimesSec[n - 2]);
    }
    // Binary search for the segment [lo, lo+1] containing tSec.
    var lo = 0;
    var hi = n - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (beatTimesSec[mid] <= tSec) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return lo +
        (tSec - beatTimesSec[lo]) / (beatTimesSec[hi] - beatTimesSec[lo]);
  }

  /// Fractional [beat] index → wall-clock seconds. Inverse of [beatAt] (same
  /// piecewise-linear segments + edge extrapolation).
  double timeAtBeat(double beat) {
    final n = beatTimesSec.length;
    if (beat <= 0) {
      return beatTimesSec[0] + beat * (beatTimesSec[1] - beatTimesSec[0]);
    }
    if (beat >= n - 1) {
      return beatTimesSec[n - 1] +
          (beat - (n - 1)) * (beatTimesSec[n - 1] - beatTimesSec[n - 2]);
    }
    final i = beat.floor();
    return beatTimesSec[i] +
        (beat - i) * (beatTimesSec[i + 1] - beatTimesSec[i]);
  }

  /// Warp wall-clock [tSec] → **clip seconds**, so the clip's beat grid lands on
  /// the detected beats. Replaces the constant `× playbackRate` scalar.
  ///
  /// The clip is authored over [clipDuration] seconds and treated as one loop of
  /// [BeatLoopBinding.loopLengthBeats] beats whose frame 0 sits on
  /// [BeatLoopBinding.anchorBeatIndex]. Because the warp follows the detected
  /// beats, accents land on-beat even when the track's tempo drifts.
  double clipSecondsAt(
    double tSec, {
    required double clipDuration,
    required BeatLoopBinding binding,
  }) {
    final beat = beatAt(tSec) - binding.anchorBeatIndex;
    var loopPhase = (beat / binding.loopLengthBeats) % 1.0;
    if (loopPhase < 0) loopPhase += 1.0; // defensive; Dart % is already >= 0
    return loopPhase * clipDuration;
  }

  static bool _isStrictlyIncreasing(List<double> xs) {
    for (var i = 1; i < xs.length; i++) {
      if (xs[i] <= xs[i - 1]) return false;
    }
    return true;
  }
}

/// How a looping clip binds onto a [BeatMap]: where its frame 0 sits and how many
/// beats one loop spans.
///
/// Two constructors encode the two quality rungs:
/// - [BeatLoopBinding.barAligned] (rung 3) anchors on a real **downbeat** and
///   spans an integer number of **bars** — the phrase's "1" lands on the bar's
///   "1". This is what we want when downbeat detection is trustworthy.
/// - [BeatLoopBinding.beatAligned] (rung 2 fallback) anchors on a plain beat and
///   spans a fixed number of **beats** — still on-beat and tempo-following, but
///   it does not claim bar-phase correctness. Use it when downbeats are shaky.
class BeatLoopBinding {
  const BeatLoopBinding({
    required this.loopLengthBeats,
    required this.anchorBeatIndex,
  }) : assert(loopLengthBeats > 0, 'loop must span at least one beat'),
       assert(anchorBeatIndex >= 0, 'anchor beat index must be non-negative');

  /// Rung 3 — bar-correct. Anchor the loop on the `fromDownbeat`-th detected
  /// downbeat and span `bars` bars. Falls back to beat 0 if the map has no
  /// downbeats (so this never throws on an undetected-downbeat track — it just
  /// degrades to a beat-0 anchor).
  factory BeatLoopBinding.barAligned(
    BeatMap map, {
    required int bars,
    int fromDownbeat = 0,
  }) {
    final anchor = map.downbeatIndices.isEmpty
        ? 0
        : map.downbeatIndices[fromDownbeat.clamp(
            0,
            map.downbeatIndices.length - 1,
          )];
    return BeatLoopBinding(
      loopLengthBeats: bars * map.timeSignatureNumerator,
      anchorBeatIndex: anchor,
    );
  }

  /// Rung 2 — beat-level fallback. Anchor on [anchorBeatIndex] and loop
  /// [loopLengthBeats] beats, without trusting the bar phase.
  factory BeatLoopBinding.beatAligned({
    required int loopLengthBeats,
    int anchorBeatIndex = 0,
  }) => BeatLoopBinding(
    loopLengthBeats: loopLengthBeats,
    anchorBeatIndex: anchorBeatIndex,
  );

  /// Beats spanned by one loop of the clip.
  final int loopLengthBeats;

  /// Beat index that the clip's frame 0 (loop phase 0) lands on.
  final int anchorBeatIndex;
}
