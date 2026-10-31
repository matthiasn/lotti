import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/pause_alignment.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// One mouth shape from its `start`, in seconds, on.
typedef VisemeCue = ({double start, Viseme viseme});

/// The mouth on the words: the text is read letter by letter into the eight
/// speaking shapes of the Rhubarb convention plus its rest, timed at a steady
/// speaking rate.
///
/// A pure-Dart stand-in for Rhubarb (a native binary the app cannot ship):
/// spelling is not sound, but the closed lips of m/b/p, the bite of f/v, the
/// pucker of o/w and the open vowels land where they should, which is most of
/// what reads as speech. Every one of the eight speaking shapes is reached:
///
/// | Shape | Letters |
/// |-------|---------|
/// | A closed | m, b, p |
/// | B teeth together | every other consonant, "ee", "ck", "ng" |
/// | C open | e, i, u, y |
/// | D wide | a |
/// | E rounded | o, r, "sh", "ch" |
/// | F puckered | w, q, "oo", "ou", "ow", "wh" |
/// | G bite | f, v, "ph" |
/// | H tongue up | l, "th" |
/// | X rest | , ; : . ! ? and line breaks |
///
/// A word's silent final e ("have", "time") takes neither a shape nor time,
/// so the word ends on the shape the voice ends it on. Commas and full stops
/// close the mouth for a breath, and are kept as [pauses] so a recorded voice
/// can pin its own pauses to them (`VoicedTextTrack`).
class TextLipSync implements MouthTrack {
  /// The cues for [text], spoken at [rate] times the natural pace.
  factory TextLipSync(String text, {double rate = 1}) {
    final cues = <VisemeCue>[];
    final pauses = <TextPause>[];
    var t = 0.0;
    final s = text.toLowerCase();
    // When each character is reached, so a later reader can time the words.
    final reached = List<double>.filled(s.length + 1, 0);
    // A run of stops ("?!", ".\n") is one pause; any sound ends the run.
    var soundSincePause = true;
    void add(Viseme v, double seconds) {
      if (cues.isEmpty || cues.last.viseme != v) {
        cues.add((start: t, viseme: v));
      }
      t += seconds / rate;
      soundSincePause = true;
    }

    void pause(double seconds, double weight) {
      final merge = pauses.isNotEmpty && !soundSincePause;
      final last = merge ? pauses.removeLast() : null;
      final start = last?.start ?? t;
      add(Viseme.x, seconds);
      pauses.add((
        start: start,
        end: t,
        weight: last != null && last.weight > weight ? last.weight : weight,
      ));
      soundSincePause = false;
    }

    var i = 0;
    while (i < s.length) {
      reached[i] = t;
      final two = i + 1 < s.length ? s.substring(i, i + 2) : '';
      final ch = s[i];
      if (_digraphs.containsKey(two)) {
        add(_digraphs[two]!, 0.1);
        reached[i + 1] = reached[i];
        i += 2;
        continue;
      }
      if (ch == ' ') {
        // A word break keeps the shape it has; only time passes. Right
        // after a stop it is part of that pause, so the next word starts
        // the moment a voice resumes.
        t += 0.03 / rate;
        if (pauses.isNotEmpty && !soundSincePause) {
          final last = pauses.removeLast();
          pauses.add((start: last.start, end: t, weight: last.weight));
        }
      } else if (_pauses.containsKey(ch)) {
        final (seconds, weight) = _pauses[ch]!;
        pause(seconds, weight);
      } else if (_isSilentE(s, i)) {
        // Neither a shape nor time: "have" ends on the bite of its v.
      } else if (_vowels.containsKey(ch)) {
        add(_vowels[ch]!, 0.085);
      } else if (_consonants.containsKey(ch)) {
        add(_consonants[ch]!, 0.055);
      } else if (_letterOrDigit.hasMatch(ch)) {
        add(Viseme.b, 0.055);
      }
      i++;
    }
    reached[s.length] = t;
    add(Viseme.x, 0.2);
    return TextLipSync._(cues, pauses, t, reached);
  }

  TextLipSync._(this.cues, this.pauses, this._end, this._reached);

  final List<VisemeCue> cues;

  /// Where the mouth rests at punctuation, on this track's clock, with how
  /// sure the punctuation is that a voice breathes there.
  final List<TextPause> pauses;

  final double _end;
  final List<double> _reached;

  /// Time to blend from one shape into the next.
  static const blendSeconds = 0.06;

  @override
  Duration get length => Duration(microseconds: (_end * 1e6).round());

  /// When the last word ends: the start of the closed-mouth rest every line
  /// ends on, a trailing full stop's pause included. A track timing these
  /// shapes to a real voice stretches this span, not [length], over the
  /// voice — the rest is silence the voice does not have.
  Duration get spokenLength =>
      Duration(microseconds: (cues.last.start * 1e6).round());

  /// [spokenLength] in seconds.
  double get spokenSeconds => cues.last.start;

  @override
  MouthShape mouthAt(Duration position) =>
      mouthAtSeconds(position.inMicroseconds / 1e6);

  /// [mouthAt], for a time in seconds on this track's clock.
  MouthShape mouthAtSeconds(double t) {
    if (t < 0 || t >= _end || cues.isEmpty) return Viseme.x.shape;
    // The last cue that has started; cues are in time order.
    var lo = 0;
    var hi = cues.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cues[mid].start <= t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final idx = lo > 0 ? lo - 1 : 0;
    final current = cues[idx].viseme.shape;
    final previous = idx > 0 ? cues[idx - 1].viseme.shape : Viseme.x.shape;
    return previous.blend(
      current,
      smoothstep((t - cues[idx].start) / blendSeconds),
    );
  }

  /// When the mouth reaches the character at [offset], at the same steady
  /// rate as the shapes.
  @override
  Duration timeOf(int offset) =>
      Duration(microseconds: (secondsOf(offset) * 1e6).round());

  /// [timeOf], in seconds on this track's clock.
  double secondsOf(int offset) =>
      _reached[offset.clamp(0, _reached.length - 1)];

  /// How open the mouth is, standing in for the voice's loudness.
  @override
  double loudnessAt(Duration position) =>
      clampUnit(mouthAt(position).open / Viseme.d.shape.open);
}

final _letterOrDigit = RegExp('[a-z0-9]');
final _letter = RegExp('[a-z]');

/// Whether the e at [i] is a word's silent final e: after a consonant, at the
/// end of a word of four letters or more ("have", "time", but not "the").
bool _isSilentE(String s, int i) {
  if (s[i] != 'e') return false;
  if (i + 1 < s.length && _letter.hasMatch(s[i + 1])) return false;
  var start = i;
  while (start > 0 && _letter.hasMatch(s[start - 1])) {
    start--;
  }
  if (i - start + 1 < 4) return false;
  return !_vowels.containsKey(s[i - 1]);
}

const Map<String, Viseme> _digraphs = {
  'th': Viseme.h,
  'oo': Viseme.f,
  'ee': Viseme.b,
  'ou': Viseme.f,
  'ow': Viseme.f,
  'sh': Viseme.e,
  'ch': Viseme.e,
  'ph': Viseme.g,
  'wh': Viseme.f,
  'ck': Viseme.b,
  'ng': Viseme.b,
};

const Map<String, Viseme> _vowels = {
  'a': Viseme.d,
  'e': Viseme.c,
  'i': Viseme.c,
  'o': Viseme.e,
  'u': Viseme.c,
  'y': Viseme.c,
};

const Map<String, Viseme> _consonants = {
  'm': Viseme.a,
  'b': Viseme.a,
  'p': Viseme.a,
  'f': Viseme.g,
  'v': Viseme.g,
  'l': Viseme.h,
  'w': Viseme.f,
  'q': Viseme.f,
  'r': Viseme.e,
};

/// Seconds the mouth rests at a stop, and how likely a voice is to pause
/// there: a voice often runs through a comma, rarely through a full stop.
const _pauses = <String, (double, double)>{
  ',': (0.22, 0.5),
  ';': (0.25, 0.8),
  ':': (0.25, 0.8),
  '.': (0.38, 1.2),
  '!': (0.38, 1.2),
  '?': (0.38, 1.2),
  '\n': (0.38, 1.5),
};
