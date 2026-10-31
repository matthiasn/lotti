import 'dart:math' as math;
import 'dart:typed_data';

import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/wav_pcm.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/companion/rig/rig_math.dart';

/// The mouth on a recorded voice: the clip's loudness, computed once before
/// it plays, opens the mouth.
///
/// The loudness is the RMS of each 1/[fps] s window, normalised to the 97th
/// percentile, the same method as the pitch videos' `motion.py`. It is enough
/// to read as talking; proper mouth shapes per sound need the words (see
/// `TextLipSync`).
class SpeechEnvelope implements MouthTrack {
  SpeechEnvelope(this.levels, {this.fps = 60});

  /// Reads a 16-bit PCM WAV (any channel count; channels are averaged), the
  /// format both voices write.
  factory SpeechEnvelope.fromWav(Uint8List bytes, {int fps = 60}) =>
      SpeechEnvelope.fromPcm(readPcm16(bytes), fps: fps);

  /// The loudness of [pcm], one level per 1/[fps] s window.
  factory SpeechEnvelope.fromPcm(Pcm pcm, {int fps = 60}) {
    final per = math.max(1, pcm.sampleRate ~/ fps);
    final raw = <double>[];
    for (var i = 0; i < pcm.samples.length; i += per) {
      final end = math.min(pcm.samples.length, i + per);
      var sum = 0.0;
      for (var k = i; k < end; k++) {
        sum += pcm.samples[k] * pcm.samples[k];
      }
      raw.add(math.sqrt(sum / (end - i)));
    }
    if (raw.isEmpty) return SpeechEnvelope(const [], fps: fps);
    final sorted = [...raw]..sort();
    final peak =
        sorted[(sorted.length * 0.97).floor().clamp(0, sorted.length - 1)];
    final norm = peak <= 0 ? 1.0 : peak;
    // A three-window average, so the jaw does not chatter on every cycle.
    final levels = [
      for (var i = 0; i < raw.length; i++)
        math
            .min(
              1,
              (raw[math.max(0, i - 1)] +
                      raw[i] +
                      raw[math.min(raw.length - 1, i + 1)]) /
                  3 /
                  norm,
            )
            .toDouble(),
    ];
    return SpeechEnvelope(levels, fps: fps);
  }

  /// Loudness per window, 0..1.
  final List<double> levels;
  final int fps;

  /// A voice alone has no words to place.
  @override
  Duration? timeOf(int offset) => null;

  @override
  Duration get length => Duration(microseconds: levels.length * 1000000 ~/ fps);

  @override
  double loudnessAt(Duration position) {
    final i = position.inMicroseconds * fps ~/ 1000000;
    if (position.isNegative || i >= levels.length) return 0;
    return levels[i];
  }

  /// Rest when quiet, then teeth-together, open and wide as it gets louder.
  @override
  MouthShape mouthAt(Duration position) =>
      mouthForLoudness(loudnessAt(position));
}

/// The mouth for a loudness of [l] in 0..1.
MouthShape mouthForLoudness(double l) {
  if (l < 0.08) return Viseme.x.shape;
  if (l < 0.3) {
    return Viseme.x.shape.blend(Viseme.b.shape, smoothstep((l - 0.08) / 0.22));
  }
  if (l < 0.6) {
    return Viseme.b.shape.blend(Viseme.c.shape, smoothstep((l - 0.3) / 0.3));
  }
  return Viseme.c.shape.blend(Viseme.d.shape, smoothstep((l - 0.6) / 0.4));
}
