import 'dart:math' as math;

import 'package:lotti/features/companion/animation/pause_alignment.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';

/// A moment on the words' clock pinned to a moment on the voice's, in
/// seconds.
typedef ClockKnot = ({double text, double voice});

/// One thing a phrase's windows are laid over: where it starts on the words'
/// clock, how it sounds, how long its letters say it takes, and whether its
/// length is free (a silence).
typedef _Step = ({double text, SoundClass sound, double seconds, bool free});

/// Pins every sound of the words to where the voice makes it.
///
/// `PauseAlignment` pins the phrases; inside a phrase the letters' fixed
/// durations still guess, and in a long phrase with no comma the guess drifts
/// by a fifth of a second and more. Here each 1/fps s window of the voice is
/// scored against each broad class of sound by how loud and how bright it is
/// (`SoundFeatures`) — a vowel is loud and dark, an s bright, a p's closure
/// quiet, an m a darker hum — and the phrase's sounds are laid over its
/// windows in order, each over a run of windows, at the lowest total cost.
/// A sound's run may stray from the length its letters give it, at a price
/// that grows with how far. A pause the voice ran through may take no window
/// at all.
///
/// This is forced alignment, as Rhubarb does with the dialog text, with
/// spelling standing in for the phonemes: the shape still comes from the
/// letter; the voice decides when.
abstract final class SoundAlignment {
  /// How dear a sound's run is, per squared log-ratio of its length to the
  /// length its letters give it.
  static const durationWeight = 1.5;

  /// The weakest pause still pinned beforehand (`PauseAlignment`): a
  /// sentence's end. Commas and the like are silences the sound places.
  static const minPinWeight = 1.2;

  /// The longest silence a voice keeps inside a phrase, in seconds: a breath
  /// or a comma's pause, never a sentence's.
  static const maxSilenceSeconds = 1.5;

  /// The most cells one phrase's search may fill: about 36 MB, a phrase of
  /// roughly a minute.
  static const maxSearchCells = 3000000;

  /// The knots for [sounds] over the voice, phrase by phrase: one at the
  /// start of every sound and of every silence the voice keeps between
  /// words, plus each phrase's ends. [levels] and [brightness] are per window
  /// of 1/[fps] s. A phrase with more sounds than windows keeps [fallback]'s
  /// timing for its sounds.
  static List<ClockKnot> knots({
    required List<SoundUnit> sounds,
    required List<Phrase> phrases,
    required List<double> levels,
    required List<double> brightness,
    required int fps,
    required double Function(double textTime) fallback,
  }) {
    final knots = <ClockKnot>[];
    var next = 0;
    for (final phrase in phrases) {
      // The sounds starting inside the phrase; a pinned pause lies between
      // phrases, not inside one.
      while (next < sounds.length &&
          sounds[next].start < phrase.textStart - _epsilon) {
        next++;
      }
      final units = <SoundUnit>[];
      while (next < sounds.length &&
          sounds[next].start < phrase.textEnd - _epsilon) {
        units.add(sounds[next++]);
      }
      knots.add((text: phrase.textStart, voice: phrase.voiceStart));
      final steps = _steps(units, phrase);
      final starts = _align(steps, phrase, levels, brightness, fps);
      if (starts == null) {
        for (final unit in units) {
          knots.add((text: unit.start, voice: fallback(unit.start)));
        }
      } else {
        for (var k = 0; k < steps.length; k++) {
          knots.add((
            text: steps[k].text,
            voice: starts[k].clamp(phrase.voiceStart, phrase.voiceEnd),
          ));
        }
      }
      knots.add((text: phrase.textEnd, voice: phrase.voiceEnd));
    }
    return knots;
  }

  /// What the phrase's windows are laid over, in order: each sound, and at
  /// every word break a silence the voice may or may not keep. A silence —
  /// a word break's, or a comma the voice was not pinned to — may take no
  /// window or many, at no price for its length: a breath the text gave no
  /// comma for is a silence, not a stretched word.
  static List<_Step> _steps(List<SoundUnit> units, Phrase phrase) {
    final steps = <_Step>[];
    for (var k = 0; k < units.length; k++) {
      final unit = units[k];
      if (k > 0 && unit.start - units[k - 1].end > _epsilon) {
        steps.add((
          text: units[k - 1].end,
          sound: SoundClass.pause,
          seconds: 0,
          free: true,
        ));
      }
      final end = k + 1 < units.length ? units[k + 1].start : phrase.textEnd;
      final pause = unit.sound == SoundClass.pause;
      steps.add((
        text: unit.start,
        sound: unit.sound,
        seconds: pause
            ? 0
            : (k + 1 < units.length ? unit.end : end) - unit.start,
        free: pause,
      ));
    }
    return steps;
  }

  /// When each of [steps] starts on the voice's clock, or null when the
  /// phrase's windows cannot hold its sounds.
  static List<double>? _align(
    List<_Step> steps,
    Phrase phrase,
    List<double> levels,
    List<double> brightness,
    int fps,
  ) {
    if (steps.isEmpty) return const [];
    final first = math.max(0, (phrase.voiceStart * fps).round());
    final last = math.min(levels.length, (phrase.voiceEnd * fps).round());
    final n = last - first;
    final sounding = steps.where((s) => !s.free).length;
    final spoken = steps.fold<double>(0, (sum, s) => sum + s.seconds);
    // A phrase too long to search — minutes without a sentence's end —
    // keeps its pause timing rather than its memory's worth of table.
    if (n < sounding || spoken <= 0) return null;
    if ((steps.length + 1) * (n + 1) > maxSearchCells) return null;

    // Prefix sums of each class's cost over the phrase's windows.
    const classes = SoundClass.values;
    final prefix = List.generate(
      classes.length,
      (_) => List<double>.filled(n + 1, 0),
    );
    for (var i = 0; i < n; i++) {
      final level = levels[first + i];
      final bright = brightness[first + i];
      for (final c in classes) {
        final p = prefix[c.index];
        p[i + 1] = p[i] + frameCost(c, level, bright);
      }
    }

    final k = steps.length;
    final best = List<double>.filled((k + 1) * (n + 1), double.infinity);
    final from = List<int>.filled((k + 1) * (n + 1), -1);
    best[0] = 0;
    for (var u = 1; u <= k; u++) {
      final step = steps[u - 1];
      // Windows the step's letters ask for, at the phrase's own pace.
      final expected = step.seconds / spoken * n;
      final minRun = step.free ? 0 : 1;
      final maxRun = math.min(
        n,
        step.free
            ? (maxSilenceSeconds * fps).ceil()
            : math.max(minRun, (3 * expected + 3).ceil()),
      );
      final p = prefix[step.sound.index];
      for (var at = 0; at <= n; at++) {
        for (var run = minRun; run <= maxRun && run <= at; run++) {
          final before = best[(u - 1) * (n + 1) + at - run];
          if (before == double.infinity) continue;
          final ratio = step.free ? 0.0 : math.log((run + 1) / (expected + 1));
          final cost =
              before + p[at] - p[at - run] + durationWeight * ratio * ratio;
          if (cost < best[u * (n + 1) + at]) {
            best[u * (n + 1) + at] = cost;
            from[u * (n + 1) + at] = at - run;
          }
        }
      }
    }
    if (best[k * (n + 1) + n] == double.infinity) return null;

    final startWindow = List<int>.filled(k, 0);
    var at = n;
    for (var u = k; u >= 1; u--) {
      at = from[u * (n + 1) + at];
      startWindow[u - 1] = at;
    }
    return [
      for (final s in startWindow)
        if (s == 0) phrase.voiceStart else (first + s) / fps,
    ];
  }

  /// How unlike [sound] a window of loudness [level] (0..1) and brightness
  /// [bright] (Hz) is: zero for a perfect match, about one a standard
  /// deviation away on one measure.
  static double frameCost(SoundClass sound, double level, double bright) {
    // Brightness tells even in a quiet window: a voice's silence is dark,
    // the breath of a hiss or a released stop bright.
    final octave = math.log(math.max(bright, 50)) / math.ln2;
    double sq(double x) => x * x;
    return switch (sound) {
      SoundClass.pause => sq(level / 0.12),
      SoundClass.stop => sq((level - 0.05) / 0.3),
      SoundClass.vowel => sq((1 - level) / 0.5) + sq((octave - 9.2) / 1.0),
      SoundClass.fricative =>
        sq((octave - 12.3) / 0.9) + (level > 0.6 ? sq((level - 0.6) / 0.3) : 0),
      SoundClass.nasal => sq((level - 0.5) / 0.35) + sq((octave - 8.5) / 1.0),
      SoundClass.approximant =>
        sq((level - 0.6) / 0.4) + sq((octave - 8.8) / 1.0),
    };
  }

  static const _epsilon = 1e-9;
}

/// A piecewise-linear map between the words' clock and the voice's, through
/// knots that run forward on both.
class ClockWarp {
  /// Knots out of order on either clock are carried forward, never back.
  ClockWarp(List<ClockKnot> knots) : _knots = _forward(knots);

  final List<ClockKnot> _knots;

  /// The voice's time for [text] on the words' clock.
  double voiceOf(double text) => _map(text, toVoice: true);

  /// The words' time for [voice] on the voice's clock. Where the voice holds
  /// still over several moments of the words — a pause it ran through — the
  /// words are already past them.
  double textOf(double voice) => _map(voice, toVoice: false);

  double _map(double x, {required bool toVoice}) {
    if (_knots.isEmpty) return 0;
    double from(ClockKnot k) => toVoice ? k.text : k.voice;
    double to(ClockKnot k) => toVoice ? k.voice : k.text;
    // The last knot at or before x.
    var lo = 0;
    var hi = _knots.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (from(_knots[mid]) <= x) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    if (lo == 0) return to(_knots.first);
    if (lo == _knots.length) return to(_knots.last);
    final a = _knots[lo - 1];
    final b = _knots[lo];
    final span = from(b) - from(a);
    if (span <= 0) return to(a);
    return to(a) + (x - from(a)) / span * (to(b) - to(a));
  }

  static List<ClockKnot> _forward(List<ClockKnot> knots) {
    final out = <ClockKnot>[];
    for (final k in knots) {
      if (out.isEmpty) {
        out.add(k);
        continue;
      }
      out.add((
        text: math.max(k.text, out.last.text),
        voice: math.max(k.voice, out.last.voice),
      ));
    }
    return out;
  }
}
