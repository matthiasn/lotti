import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// One mouth shape from its `start`, in seconds, on.
typedef VisemeCue = ({double start, Viseme viseme});

/// The mouth on the words: the text is read letter by letter into the nine
/// Rhubarb mouth shapes, timed at a steady speaking rate.
///
/// A pure-Dart stand-in for Rhubarb (a native binary the app cannot ship):
/// spelling is not sound, but the closed lips of m/b/p, the bite of f/v, the
/// pucker of o/w and the open vowels land where they should, which is most of
/// what reads as speech. Commas and full stops close the mouth for a breath.
class TextLipSync implements MouthTrack {
  /// The cues for [text], spoken at [rate] times the natural pace.
  factory TextLipSync(String text, {double rate = 1}) {
    final cues = <VisemeCue>[];
    var t = 0.0;
    void add(Viseme v, double seconds) {
      if (cues.isEmpty || cues.last.viseme != v) {
        cues.add((start: t, viseme: v));
      }
      t += seconds / rate;
    }

    final s = text.toLowerCase();
    var i = 0;
    while (i < s.length) {
      final two = i + 1 < s.length ? s.substring(i, i + 2) : '';
      final ch = s[i];
      if (_digraphs.containsKey(two)) {
        add(_digraphs[two]!, 0.1);
        i += 2;
        continue;
      }
      if (ch == ' ') {
        // A word break keeps the shape it has; only time passes.
        t += 0.03 / rate;
      } else if (_pauses.containsKey(ch)) {
        add(Viseme.x, _pauses[ch]!);
      } else if (_vowels.containsKey(ch)) {
        add(_vowels[ch]!, 0.085);
      } else if (_consonants.containsKey(ch)) {
        add(_consonants[ch]!, 0.055);
      } else if (RegExp('[a-z0-9]').hasMatch(ch)) {
        add(Viseme.b, 0.055);
      }
      i++;
    }
    add(Viseme.x, 0.2);
    return TextLipSync._(cues, t);
  }

  TextLipSync._(this.cues, this._end);

  final List<VisemeCue> cues;
  final double _end;

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

  @override
  MouthShape mouthAt(Duration position) {
    final t = position.inMicroseconds / 1e6;
    if (t < 0 || t >= _end || cues.isEmpty) return Viseme.x.shape;
    var idx = 0;
    for (var k = 0; k < cues.length; k++) {
      if (cues[k].start <= t) idx = k;
    }
    final current = cues[idx].viseme.shape;
    final previous = idx > 0 ? cues[idx - 1].viseme.shape : Viseme.x.shape;
    return previous.blend(
      current,
      smoothstep((t - cues[idx].start) / blendSeconds),
    );
  }

  /// How open the mouth is, standing in for the voice's loudness.
  @override
  double loudnessAt(Duration position) =>
      clampUnit(mouthAt(position).open / Viseme.d.shape.open);
}

const Map<String, Viseme> _digraphs = {
  'th': Viseme.h,
  'oo': Viseme.f,
  'ee': Viseme.b,
  'ou': Viseme.f,
  'ow': Viseme.f,
  'sh': Viseme.e,
  'ch': Viseme.e,
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

/// Seconds the mouth rests at a stop.
const _pauses = {
  ',': 0.22,
  ';': 0.25,
  ':': 0.25,
  '.': 0.38,
  '!': 0.38,
  '?': 0.38,
  '\n': 0.38,
};
