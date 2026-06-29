/// The shared, pure per-frame *derivation* for the beat-synced dance showcase.
///
/// Both the live audio player (`DanceToTrackPage`) and the offline frame
/// composer (`DanceFrameComposer`, used by the MP4 exporter and the position-
/// window debug harness) turn an **audio position in seconds** into the same
/// on-screen content: which move the trio dances, the warped pose clock it
/// samples, the musical beat pulse, and the virtual director's camera context.
///
/// Keeping that derivation in one place means an offline render matches the
/// running app's *move, pose clock, beat and camera* at a position — there is a
/// single source of truth for those, so they cannot drift. (The paint constants
/// and the stage-light rig are likewise single-sourced in `DanceStageView`; only
/// the ambient stage-light *phase* differs offline, by design — see that file.)
/// Everything here is a pure function of `pos` plus the loaded track data; the
/// stateful parts (the camera rig's smoothing, mouth easing) live in the callers
/// (`DancePlaybackStepper`) and consume these results.
library;

import 'package:lotti/features/character/demo/dance_camera_director.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/clip.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

/// A structural energy section of the track, tagged energetic/calm with a
/// normalized 0..1 energy `level` across the song's sections.
typedef DanceSection = ({
  double start,
  double end,
  String label,
  bool energetic,
  double level,
});

/// A word from the optional synced-lyrics file. `voice` is `lead` or
/// `background`; `section` is the semantic (lyric) section tag.
typedef DanceWord = ({
  double start,
  double end,
  String word,
  String voice,
  String section,
});

/// A contiguous semantic-section span collapsed from the per-word section tags —
/// each chorus / verse / bridge occurrence is its own span.
typedef DanceSectionSpan = ({double start, double end, String section});

/// The lead move plus the three-cat ensemble (ensemble[0] is the lead's clip).
typedef DanceTrio = ({Clip lead, List<Clip> ensemble});

/// Everything the painter needs for one frame: the lead clip, the ensemble
/// clips, the warped pose clock `seconds`, the active `section`, whether the
/// section is energetic, and whether the trio dances in unison (`synchronous`)
/// or canon (staggered phase, e.g. the Pouncing-Cat glide).
typedef DanceStage = ({
  Clip lead,
  List<Clip> ensemble,
  double seconds,
  DanceSection? section,
  bool energetic,
  bool synchronous,
});

/// Number of bars the looping dance phrase spans; the loop stays beat-locked for
/// the whole track once anchored on the first downbeat.
const int kDancePhraseBars = 3;

/// Fraction of the track's energy range below which a section counts as "calm"
/// (and, if also long enough, eases the trio into idle). See [kMinCalmSeconds].
const double kSectionEnergyThreshold = 0.5;

/// Minimum duration for a low-energy section to be treated as calm — shorter
/// transitions stay energetic so the dance doesn't flicker into idle.
const double kMinCalmSeconds = 4;

/// Sections the whole trio sings (a group hook): the backups' mouths join the
/// frontman on the *lead* words here, not just on the `(...)` ad-libs.
const Set<String> kGroupSections = {'chorus', 'post-chorus', 'outro'};

/// Fast attack for the singing mouth: each sung syllable snaps open quickly…
const double kMouthAttackSeconds = 0.045;

/// …then relaxes shut more slowly, so the mouth doesn't flutter symmetrically.
const double kMouthReleaseSeconds = 0.12;

/// Eases a mouth-open value toward [target] with a fast attack and slower
/// release (frame-rate independent via [dt]). Shared by the live player and the
/// offline composer so both animate the singing mouth identically.
double easeDanceMouth(double current, double target, double dt) {
  final tc = target > current ? kMouthAttackSeconds : kMouthReleaseSeconds;
  var k = dt / tc;
  if (k > 1) k = 1;
  return current + (target - current) * k;
}

/// The trio's resting pose for [pos]: all three cats idle, the clock running on
/// raw playback time. Used before the beat map loads and on genuinely dead-quiet
/// sections.
DanceStage danceIdleStage(double pos, {DanceSection? section}) => (
  lead: CatClips.idle,
  ensemble: [CatClips.idle, CatClips.idle, CatClips.idle],
  seconds: pos,
  section: section,
  energetic: false,
  synchronous: true,
);

/// Tags each detected section energetic/calm by its mean waveform energy
/// (relative to the track's energy range). Calm only when genuinely low-energy
/// AND long enough — short transition sections stay energetic to avoid flicker.
List<DanceSection> classifyDanceSections(
  List<({double start, double end, String label})> raw,
  List<double> amplitudes,
  double duration,
) {
  if (raw.isEmpty || amplitudes.isEmpty || duration <= 0) {
    return [
      for (final s in raw)
        (
          start: s.start,
          end: s.end,
          label: s.label,
          energetic: true,
          level: 1.0,
        ),
    ];
  }
  final n = amplitudes.length;
  double energyOf(double start, double end) {
    var i0 = (start / duration * n).floor();
    var i1 = (end / duration * n).ceil();
    if (i0 < 0) i0 = 0;
    if (i0 >= n) i0 = n - 1;
    if (i1 > n) i1 = n;
    if (i1 <= i0) i1 = i0 + 1;
    var sum = 0.0;
    for (var i = i0; i < i1; i++) {
      sum += amplitudes[i];
    }
    return sum / (i1 - i0);
  }

  final energies = [for (final s in raw) energyOf(s.start, s.end)];
  var minE = energies.first;
  var maxE = energies.first;
  for (final e in energies) {
    if (e < minE) minE = e;
    if (e > maxE) maxE = e;
  }
  final threshold = minE + kSectionEnergyThreshold * (maxE - minE);
  final range = maxE - minE;
  return [
    for (var i = 0; i < raw.length; i++)
      (
        start: raw[i].start,
        end: raw[i].end,
        label: raw[i].label,
        energetic:
            !(energies[i] < threshold &&
                (raw[i].end - raw[i].start) >= kMinCalmSeconds),
        level: range > 0 ? (energies[i] - minE) / range : 1.0,
      ),
  ];
}

/// Collapses the per-word [DanceWord] `section` tags into contiguous spans — each
/// chorus / verse / bridge occurrence becomes its own span — so the director can
/// report progress WITHIN the current section. The last span runs to [duration];
/// earlier ones are trimmed to the next span's start. Empty without tagged words.
List<DanceSectionSpan> buildDanceSectionSpans(
  List<DanceWord> words,
  double duration,
) {
  final spans = <DanceSectionSpan>[];
  for (final w in words) {
    final section = w.section.toLowerCase();
    if (spans.isEmpty || spans.last.section != section) {
      spans.add((start: w.start, end: duration, section: section));
    }
  }
  for (var i = 0; i < spans.length - 1; i++) {
    spans[i] = (
      start: spans[i].start,
      end: spans[i + 1].start,
      section: spans[i].section,
    );
  }
  return spans;
}

/// A short, human display name for a lyric section tag.
String danceSectionDisplayName(String section) {
  switch (section.toLowerCase()) {
    case 'pre-chorus':
      return 'Pre';
    case 'post-chorus':
      return 'Post';
    case 'chorus':
      return 'Chorus';
    case 'verse':
      return 'Verse';
    case 'bridge':
      return 'Bridge';
    case 'intro':
      return 'Intro';
    case 'outro':
      return 'Outro';
    case '':
      return '—';
    default:
      return section[0].toUpperCase() + section.substring(1);
  }
}

/// The single source of truth for what the dance shows at a given audio position.
///
/// Constructed once after the beat map and optional lyrics load; every method is
/// a pure function of its argument plus the immutable track data, so the same
/// `pos` always yields the same stage, beat and camera context — in the live app
/// and in any offline render alike.
class DancePerformance {
  DancePerformance({
    required this.map,
    required this.binding,
    required this.sections,
    required this.sectionSpans,
    required this.trackDurationSec,
    this.words = const [],
  });

  /// Builds a performance from a parsed beat-map [json] document (the embedded
  /// waveform + structural sections) and the already-parsed [map] / [words], so
  /// the live player and every offline renderer assemble it the same way.
  factory DancePerformance.fromBeatMapJson({
    required Map<String, Object?> json,
    required BeatMap map,
    required double trackDurationSec,
    List<DanceWord> words = const [],
  }) {
    final amplitudes =
        (json['waveform'] as List?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        const <double>[];
    final rawSections = ((json['sections'] as List?) ?? const [])
        .cast<Map<String, Object?>>()
        .map(
          (s) => (
            start: (s['start_sec']! as num).toDouble(),
            end: (s['end_sec']! as num).toDouble(),
            label: (s['label'] as String?) ?? '',
          ),
        )
        .toList();
    return DancePerformance(
      map: map,
      binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
      sections: classifyDanceSections(
        rawSections,
        amplitudes,
        trackDurationSec,
      ),
      sectionSpans: buildDanceSectionSpans(words, trackDurationSec),
      trackDurationSec: trackDurationSec,
      words: words,
    );
  }

  /// The beat/downbeat map driving the warped pose clock and the beat pulse.
  final BeatMap map;

  /// Anchors the looping phrase on the first downbeat across whole bars.
  final BeatLoopBinding binding;

  /// Structural energy sections (gate idle vs. dance, drive the level fallback).
  final List<DanceSection> sections;

  /// Semantic (lyric) section spans (drive the lyric-aware choreography).
  final List<DanceSectionSpan> sectionSpans;

  /// Optional synced lyrics (drive the singing mouths in the callers).
  final List<DanceWord> words;

  /// Whole-track duration in seconds (normalizes the director's build progress).
  final double trackDurationSec;

  static final Clip _shaku = CatClips.shaku;
  static final Clip _zanku = CatClips.zanku;
  static final Clip _azonto = CatClips.azonto;
  static final Clip _buga = CatClips.buga;
  static final Clip _pounce = CatClips.pouncingCat;
  static final Clip _sekem = CatClips.sekem;

  /// How far open the lyric-synced mouth slack window is dilated so short gaps
  /// between a phrase's words don't make the mouth flicker shut.
  static const double voiceSlack = 0.3;

  /// The full per-frame stage at [pos]: the clip + warped clock for the current
  /// section. The trio dances the routine chosen for the current semantic (lyric)
  /// section, falling back to the energy level when the song has no lyrics; it
  /// only fully rests on a genuinely dead-quiet section. The lead's duration sets
  /// the beat-lock clock (all dance moves share the phrase length).
  DanceStage stageAt(double pos) {
    final section = sectionAt(pos);
    final level = section?.level ?? 1.0;
    final resting = section != null && !section.energetic && level < 0.15;
    if (!resting) {
      final lyric = sectionInfoAt(pos);
      final occ = sectionOccurrenceAt(pos, lyric.section);
      final trio = choreoTrioForSection(lyric.section, lyric.phase, level, occ);
      return (
        lead: trio.lead,
        ensemble: trio.ensemble,
        seconds: map.clipSecondsAt(
          pos,
          clipDuration: trio.lead.duration,
          binding: binding,
        ),
        section: section,
        energetic: section?.energetic ?? true,
        // Canon (staggered phase) when the trio is on the Pouncing-Cat glide so
        // they creep in sequence rather than swinging as one pendulum; tight
        // unison for every other move.
        synchronous: trio.lead != _pounce,
      );
    }
    return danceIdleStage(pos, section: section);
  }

  /// The structural energy section covering [pos] (the last section past the end).
  DanceSection? sectionAt(double pos) {
    for (final s in sections) {
      if (pos >= s.start && pos < s.end) return s;
    }
    return sections.isEmpty ? null : sections.last;
  }

  /// Where [pos] sits inside the current semantic section: its label and progress
  /// 0..1. Defaults to the empty section when no span covers [pos].
  ({String section, double phase}) sectionInfoAt(double pos) {
    for (final s in sectionSpans) {
      if (pos >= s.start && pos < s.end) {
        final span = (s.end - s.start) <= 0 ? 1.0 : s.end - s.start;
        return (
          section: s.section,
          phase: ((pos - s.start) / span).clamp(0.0, 1.0),
        );
      }
    }
    return (section: '', phase: 0);
  }

  /// How many earlier spans share [section]'s label — 0 for its first occurrence.
  /// Lets the choreography vary repeated choruses/verses so they don't read
  /// identical.
  int sectionOccurrenceAt(double pos, String section) {
    var occ = 0;
    for (final s in sectionSpans) {
      if (pos >= s.start && pos < s.end) break;
      if (s.section == section) occ++;
    }
    return occ;
  }

  /// The lyric-driven routine for a semantic [section]: each section of the song
  /// gets its own trio across the six moves, so the dance reads as a designed set
  /// — verses groove, the chorus punches its hook into a unison Buga hit, the
  /// bridge drops to the Pouncing-Cat glide, the outro winds down. [phase] is
  /// 0..1 progress through the section; [variant] is the section occurrence (0 =
  /// first) so repeats don't read identical. Falls back to the energy-level map
  /// for untagged sections / no lyrics.
  DanceTrio choreoTrioForSection(
    String section,
    double phase,
    double level,
    int variant,
  ) {
    switch (section) {
      case 'chorus':
      case 'post-chorus':
        if (phase >= 0.55) {
          return (lead: _buga, ensemble: [_buga, _buga, _buga]);
        }
        final fronts = [
          [_zanku, _sekem, _buga],
          [_sekem, _zanku, _buga],
          [_zanku, _buga, _sekem],
        ];
        final front = fronts[variant % fronts.length];
        return (lead: front[0], ensemble: front);
      case 'pre-chorus':
        return (lead: _shaku, ensemble: [_shaku, _zanku, _sekem]);
      case 'verse':
        return variant.isEven
            ? (lead: _azonto, ensemble: [_azonto, _shaku, _zanku])
            : (lead: _shaku, ensemble: [_shaku, _azonto, _zanku]);
      case 'bridge':
        return (lead: _pounce, ensemble: [_pounce, _pounce, _pounce]);
      case 'outro':
        return (lead: _pounce, ensemble: [_pounce, _pounce, _shaku]);
      default:
        return choreoTrioByLevel(level);
    }
  }

  /// Energy-only fallback (no lyrics): map the section's normalized [level] to a
  /// trio, building from the Pouncing-Cat glide up to the unison Buga hit.
  DanceTrio choreoTrioByLevel(double level) {
    if (level >= 0.90) return (lead: _buga, ensemble: [_buga, _buga, _buga]);
    if (level >= 0.78) {
      return (lead: _zanku, ensemble: [_zanku, _sekem, _buga]);
    }
    if (level >= 0.62) {
      return (lead: _shaku, ensemble: [_shaku, _zanku, _sekem]);
    }
    if (level >= 0.45) {
      return (lead: _shaku, ensemble: [_shaku, _azonto, _zanku]);
    }
    if (level >= 0.28) {
      return (lead: _azonto, ensemble: [_azonto, _shaku, _pounce]);
    }
    return (lead: _pounce, ensemble: [_pounce, _pounce, _pounce]);
  }

  /// The virtual director's CONTEXT for [pos], from which the target framing
  /// ([cameraShot]) and cut predicates are derived. [energetic] mirrors the
  /// acoustic dance gate so the camera rests on a wide establish exactly when the
  /// dancers ease to idle, and performs when they dance.
  DanceCameraContext directorContext(double pos, {required bool energetic}) {
    final info = sectionInfoAt(pos);
    return cameraContext(
      beat: map.beatAt(pos),
      anchorBeat: binding.anchorBeatIndex.toDouble(),
      loopLengthBeats: binding.loopLengthBeats.toDouble(),
      section: info.section,
      energetic: energetic,
      build: trackDurationSec > 0 ? pos / trackDurationSec : 0,
      sectionPhase: info.phase,
    );
  }

  /// Whether a voice (selected by [test]) is singing at [pos], dilated by
  /// [voiceSlack] so short gaps between a phrase's words don't make the mouth
  /// flicker shut — it only rests between phrases / when that voice is silent.
  bool voiceActive(double pos, bool Function(DanceWord w) test) {
    for (final w in words) {
      if (test(w) && windowActiveAt(w.start, w.end, pos, voiceSlack)) {
        return true;
      }
      if (w.start - voiceSlack > pos) break;
    }
    return false;
  }

  /// A 0..1 musical pulse that spikes on each detected beat and decays, so the
  /// backdrop lights and foam shimmer with the track. A pure function of [pos]
  /// and the beat times, so it freezes with playback.
  double beatPulse(double pos) {
    final beats = map.beatTimesSec;
    if (beats.isEmpty) return 0;
    var lo = 0;
    var hi = beats.length - 1;
    var idx = 0;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      if (beats[mid] <= pos) {
        idx = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    final since = pos - beats[idx];
    if (since < 0) return 0;
    final v = 1 - since / 0.18;
    return v <= 0 ? 0 : v * v;
  }
}
