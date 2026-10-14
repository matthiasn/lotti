import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// A recorded voice with its words: the words give the mouth its shapes, the
/// voice gives the timing and how far it opens.
///
/// The text's spoken shapes (up to [TextLipSync.spokenLength], without the
/// closing rest) are stretched over the voiced part of the clip (from the
/// first sound to the last), and the voice's loudness gates them: silent, the
/// lips close; loud, the shape opens fully. This is what the on-device voice
/// can feed, since it knows the text it spoke.
class VoicedTextTrack implements MouthTrack {
  VoicedTextTrack(this.envelope, String text) : words = TextLipSync(text) {
    final levels = envelope.levels;
    final first = levels.indexWhere((l) => l >= _quiet);
    final last = levels.lastIndexWhere((l) => l >= _quiet);
    _from = first < 0 ? 0 : first / envelope.fps;
    _to = last < 0 ? 0 : (last + 1) / envelope.fps;
  }

  static const _quiet = 0.08;

  final SpeechEnvelope envelope;
  final TextLipSync words;
  late final double _from;
  late final double _to;

  @override
  Duration get length => envelope.length;

  @override
  double loudnessAt(Duration position) => envelope.loudnessAt(position);

  @override
  MouthShape mouthAt(Duration position) {
    final l = envelope.loudnessAt(position);
    if (l < _quiet || _to <= _from) return Viseme.x.shape;
    final t = position.inMicroseconds / 1e6;
    final spoken = words.spokenLength.inMicroseconds / 1e6;
    final u = clampUnit((t - _from) / (_to - _from));
    final shape = words.mouthAt(
      Duration(microseconds: (u * spoken * 1e6).round()),
    );
    return Viseme.x.shape.blend(shape, smoothstep(l / 0.35));
  }
}
