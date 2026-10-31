import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/pause_alignment.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// A recorded voice with its words: the words give the mouth its shapes, the
/// voice gives the timing and how far it opens.
///
/// The voice's own pauses — silences of at least [minGapSeconds] between its
/// first sound and its last — are pinned to the text's punctuation pauses
/// ([PauseAlignment]), and each phrase of the words is stretched over its own
/// stretch of voice. A single stretch over the whole clip let the guessed
/// letter timing drift: the lips trailed the voice by 0.3 s after the first
/// comma, still closed for it while the voice spoke the next phrase.
/// The voice's loudness then gates the shapes: silent, the lips close; loud,
/// the shape opens fully. This is what the on-device and cloud voices can
/// feed, since they know the text they spoke.
class VoicedTextTrack implements MouthTrack {
  VoicedTextTrack(this.envelope, String text) : words = TextLipSync(text) {
    final levels = envelope.levels;
    final fps = envelope.fps;
    final first = levels.indexWhere((l) => l >= _quiet);
    final last = levels.lastIndexWhere((l) => l >= _quiet);
    _voiced = first >= 0;
    final from = _voiced ? first / fps : 0.0;
    final to = _voiced ? (last + 1) / fps : 0.0;
    alignment = PauseAlignment.align(
      textEnd: words.spokenSeconds,
      textPauses: words.pauses,
      voiceFrom: from,
      voiceTo: to,
      voiceGaps: _voiced ? _gaps(levels, first, last, fps) : const [],
    );
  }

  /// Below this loudness the voice is silent and the lips close.
  static const _quiet = 0.08;

  /// The shortest silence taken for a pause rather than a stop consonant's
  /// closure inside a word, which is under a tenth of a second.
  static const minGapSeconds = 0.15;

  final SpeechEnvelope envelope;
  final TextLipSync words;

  /// How the words' clock maps onto the voice's.
  late final PauseAlignment alignment;
  late final bool _voiced;

  @override
  Duration get length => envelope.length;

  @override
  double loudnessAt(Duration position) => envelope.loudnessAt(position);

  /// When the voice reaches the character at [offset]: the words' own time
  /// for it, carried onto the voice as the shapes are.
  @override
  Duration timeOf(int offset) => _duration(
    alignment.voiceTimeOf(words.secondsOf(offset)),
  );

  @override
  MouthShape mouthAt(Duration position) {
    final l = envelope.loudnessAt(position);
    if (l < _quiet || !_voiced) return Viseme.x.shape;
    final shape = words.mouthAtSeconds(
      alignment.textTimeOf(position.inMicroseconds / 1e6),
    );
    return Viseme.x.shape.blend(shape, smoothstep(l / 0.35));
  }

  static Duration _duration(double seconds) =>
      Duration(microseconds: (seconds * 1e6).round());

  /// The silences of at least [minGapSeconds] strictly between the voice's
  /// first sounding window [first] and its last [last].
  static List<SilentSpan> _gaps(
    List<double> levels,
    int first,
    int last,
    int fps,
  ) {
    final minFrames = (minGapSeconds * fps).ceil();
    final gaps = <SilentSpan>[];
    int? start;
    for (var i = first; i <= last; i++) {
      final silent = levels[i] < _quiet;
      if (silent) {
        start ??= i;
      } else if (start != null) {
        if (i - start >= minFrames) {
          gaps.add((start: start / fps, end: i / fps));
        }
        start = null;
      }
    }
    return gaps;
  }
}
