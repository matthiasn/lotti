import 'dart:math' as math;

/// A stretch of silence on one clock, in seconds: a stop in the words, or a
/// gap in the voice.
typedef SilentSpan = ({double start, double end});

/// A stop in the words, on the words' own clock, and how sure the text is
/// that a voice pauses there: a comma weighs less than a full stop.
typedef TextPause = ({double start, double end, double weight});

/// Maps the words' clock onto a recorded voice's clock, phrase by phrase.
///
/// The words' clock (`TextLipSync`) gives every letter a fixed duration, so
/// it knows the order of the shapes but not their timing. A single stretch
/// from the first sound to the last spreads the guess's error over the whole
/// clip: on a real voice the lips ran 0.3 s behind after the first comma. Where a voice pauses, though, is plain in its loudness, and
/// those pauses sit at the text's punctuation.
///
/// So both clocks are first squeezed to speech alone — the text's pauses and
/// the voice's gaps taken out — and the text's pauses are matched to the
/// voice's gaps in order ([PauseAlignment.align]). Each matched pair pins the two clocks
/// together; between pins, the words are stretched over the voice linearly.
/// A comma the voice ran through, or a breath the text did not mark, is
/// simply left unmatched.
class PauseAlignment {
  PauseAlignment._(this._text, this._voice, this._knots, this.matches);

  /// Aligns the words — speech from 0 to [textEnd] on their clock, resting at
  /// [textPauses] — with a voice that sounds from [voiceFrom] to [voiceTo]
  /// and falls silent at [voiceGaps].
  ///
  /// Both lists are in order and do not overlap. Pauses before the first word
  /// or after [textEnd], and gaps outside the voiced span, pin nothing.
  factory PauseAlignment.align({
    required double textEnd,
    required List<TextPause> textPauses,
    required double voiceFrom,
    required double voiceTo,
    required List<SilentSpan> voiceGaps,
  }) {
    final text = _Squeeze(0, [
      for (final p in textPauses)
        if (p.end > p.start && p.start < textEnd)
          (start: p.start, end: math.min(p.end, textEnd)),
    ]);
    final voice = _Squeeze(voiceFrom, [
      for (final g in voiceGaps)
        if (g.end > g.start && g.start > voiceFrom && g.end < voiceTo) g,
    ]);
    final textSpeech = text.speechAt(textEnd);
    final voiceSpeech = voice.speechAt(voiceTo);

    // The pins on offer: pauses and gaps strictly inside the speech.
    final pauses = <({double at, double weight})>[];
    var index = 0;
    for (final p in textPauses) {
      if (p.end > p.start && p.start < textEnd) {
        final at = text.positions[index];
        if (at > 0 && at < textSpeech) {
          pauses.add((at: at, weight: p.weight));
        }
        index++;
      }
    }
    final gaps = [
      for (var j = 0; j < voice.positions.length; j++)
        (at: voice.positions[j], length: voice.lengths[j]),
    ];

    final matched = textSpeech <= 0 || voiceSpeech <= 0
        ? const <({int text, int voice})>[]
        : _match(
            pauseAt: [for (final p in pauses) p.at],
            pauseWeight: [for (final p in pauses) p.weight],
            gapAt: [for (final g in gaps) g.at],
            gapLength: [for (final g in gaps) g.length],
            textSpeech: textSpeech,
            voiceSpeech: voiceSpeech,
          );
    final knots = <({double text, double voice})>[
      (text: 0, voice: 0),
      for (final m in matched)
        (text: pauses[m.text].at, voice: gaps[m.voice].at),
      (text: textSpeech, voice: voiceSpeech),
    ];
    return PauseAlignment._(text, voice, knots, matched);
  }

  final _Squeeze _text;
  final _Squeeze _voice;
  final List<({double text, double voice})> _knots;

  /// Which interior text pause was pinned to which voice gap, by their order
  /// among the pauses and gaps inside the speech.
  final List<({int text, int voice})> matches;

  /// The voice's time, in seconds, for [textTime] on the words' clock. A
  /// word right after a pinned pause is reached when the voice resumes.
  double voiceTimeOf(double textTime) {
    final speech = _text.speechAt(textTime);
    return _voice.clockAt(_interpolate(speech, toVoice: true));
  }

  /// The words' time, in seconds, for [voiceTime] on the voice's clock.
  /// Inside a gap the words wait at the gap's pause.
  double textTimeOf(double voiceTime) {
    final speech = _voice.speechAt(voiceTime);
    return _text.clockAt(_interpolate(speech, toVoice: false));
  }

  double _interpolate(double x, {required bool toVoice}) {
    double from(({double text, double voice}) k) => toVoice ? k.text : k.voice;
    double to(({double text, double voice}) k) => toVoice ? k.voice : k.text;
    final first = _knots.first;
    final last = _knots.last;
    if (x <= from(first)) return to(first);
    if (x >= from(last)) return to(last);
    var lo = 0;
    var hi = _knots.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (from(_knots[mid]) <= x) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = _knots[lo];
    final b = _knots[hi];
    final span = from(b) - from(a);
    if (span <= 0) return to(b);
    return to(a) + (x - from(a)) / span * (to(b) - to(a));
  }
}

/// How many pauses or gaps one stretch between two pins may pass over.
const _window = 12;

/// How far apart, as a share of the speech, a pause and a gap may sit and
/// still be considered for a pin.
const _band = 0.3;

/// Pins text pauses to voice gaps in order, at the lowest total cost.
///
/// A stretch between two pins costs how far its voice length strays from
/// the words' length at the clip's overall pace — a little leeway for every
/// phrase, more for long ones. A pause left unpinned costs its weight (the
/// voice ran through a comma); a gap left unpinned costs more the longer it
/// is (a long silence the text gave no reason for).
List<({int text, int voice})> _match({
  required List<double> pauseAt,
  required List<double> pauseWeight,
  required List<double> gapAt,
  required List<double> gapLength,
  required double textSpeech,
  required double voiceSpeech,
}) {
  final n = pauseAt.length;
  final m = gapAt.length;
  final pace = voiceSpeech / textSpeech;
  // Anchors 0 and n+1 (m+1) are the start and the end of the speech.
  final tAt = [0.0, ...pauseAt, textSpeech];
  final vAt = [0.0, ...gapAt, voiceSpeech];
  final skipText = List<double>.filled(n + 2, 0);
  for (var i = 1; i <= n; i++) {
    skipText[i] = skipText[i - 1] + pauseWeight[i - 1];
  }
  skipText[n + 1] = skipText[n];
  final skipVoice = List<double>.filled(m + 2, 0);
  for (var j = 1; j <= m; j++) {
    final g = gapLength[j - 1] / 0.3;
    skipVoice[j] = skipVoice[j - 1] + g * g;
  }
  skipVoice[m + 1] = skipVoice[m];

  double stretch(int i, int j, int i2, int j2) {
    final expected = (tAt[i2] - tAt[i]) * pace;
    final error = (vAt[j2] - vAt[j] - expected) / (0.12 + 0.3 * expected);
    return error * error +
        (skipText[i2 - 1] - skipText[i]) +
        (skipVoice[j2 - 1] - skipVoice[j]);
  }

  bool near(int i, int j) =>
      (tAt[i] / textSpeech - vAt[j] / voiceSpeech).abs() <= _band;

  final cols = m + 2;
  final best = List<double>.filled((n + 2) * cols, double.infinity);
  final back = List<int>.filled((n + 2) * cols, -1);
  best[0] = 0;
  for (var i = 0; i <= n; i++) {
    for (var j = 0; j <= m; j++) {
      final here = best[i * cols + j];
      if (here == double.infinity) continue;
      for (var i2 = i + 1; i2 <= math.min(n, i + _window); i2++) {
        for (var j2 = j + 1; j2 <= math.min(m, j + _window); j2++) {
          if (!near(i2, j2)) continue;
          final cost = here + stretch(i, j, i2, j2);
          final at = i2 * cols + j2;
          if (cost < best[at]) {
            best[at] = cost;
            back[at] = i * cols + j;
          }
        }
      }
      // The end is always in reach, so a path always exists.
      final end = (n + 1) * cols + m + 1;
      final cost = here + stretch(i, j, n + 1, m + 1);
      if (cost < best[end]) {
        best[end] = cost;
        back[end] = i * cols + j;
      }
    }
  }

  final pins = <({int text, int voice})>[];
  var at = back[(n + 1) * cols + m + 1];
  while (at > 0) {
    pins.add((text: at ~/ cols - 1, voice: at % cols - 1));
    at = back[at];
  }
  return pins.reversed.toList();
}

/// One clock with its silences taken out: [speechAt] runs only while
/// something is said, and [clockAt] puts the silences back.
class _Squeeze {
  _Squeeze(this.origin, List<SilentSpan> silences) {
    var removed = 0.0;
    for (final s in silences) {
      _starts.add(s.start);
      _ends.add(s.end);
      positions.add(s.start - origin - removed);
      lengths.add(s.end - s.start);
      _before.add(removed);
      removed += s.end - s.start;
    }
  }

  final double origin;
  final _starts = <double>[];
  final _ends = <double>[];

  /// Total silence before each one.
  final _before = <double>[];

  /// Where each silence sits in speech time.
  final positions = <double>[];

  /// How long each silence is.
  final lengths = <double>[];

  /// Speech time at [clock]: frozen through a silence at exactly the
  /// silence's position, so [clockAt] puts it back after that silence, and
  /// never below zero.
  double speechAt(double clock) {
    final k = _lastAtOrBefore(_starts, clock, inclusive: false);
    if (k >= 0 && clock <= _ends[k]) return positions[k];
    final speech = math
        .max(
          0,
          clock - origin - (k < 0 ? 0.0 : _before[k] + lengths[k]),
        )
        .toDouble();
    // Rounding must not carry a moment back before the silence it follows,
    // or past the one it precedes.
    final floor = k < 0 ? 0.0 : positions[k];
    final ceiling = k + 1 < positions.length
        ? positions[k + 1]
        : double.infinity;
    return speech.clamp(floor, ceiling);
  }

  /// The clock at [speech]: where a silence sits, the moment it ends.
  double clockAt(double speech) {
    final k = _lastAtOrBefore(positions, speech, inclusive: true);
    final removed = k < 0 ? 0.0 : _before[k] + lengths[k];
    return origin + speech + removed;
  }

  static int _lastAtOrBefore(
    List<double> sorted,
    double x, {
    required bool inclusive,
  }) {
    var lo = 0;
    var hi = sorted.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      final v = sorted[mid];
      if (inclusive ? v <= x : v < x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo - 1;
  }
}
