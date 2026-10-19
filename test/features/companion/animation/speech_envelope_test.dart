import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/tts/engine/wav_writer.dart';

/// Half a second of silence, half a second of a loud tone, at 24 kHz: the
/// format the on-device voice writes.
Uint8List _quietThenLoud() {
  const rate = 24000;
  return encodeWavBytes([
    for (var i = 0; i < rate ~/ 2; i++) 0.0,
    for (var i = 0; i < rate ~/ 2; i++)
      0.8 * math.sin(2 * math.pi * 220 * i / rate),
  ], rate);
}

void main() {
  group('SpeechEnvelope.fromWav', () {
    test('one level per 1/60 s, silent then loud, normalised to 1', () {
      final env = SpeechEnvelope.fromWav(_quietThenLoud());
      expect(env.levels, hasLength(60));
      expect(env.length.inMilliseconds, 1000);
      expect(env.loudnessAt(const Duration(milliseconds: 200)), 0);
      expect(
        env.loudnessAt(const Duration(milliseconds: 800)),
        closeTo(1, 0.05),
      );
      for (final l in env.levels) {
        expect(l, inInclusiveRange(0, 1));
      }
    });

    test('is silent outside the clip', () {
      final env = SpeechEnvelope.fromWav(_quietThenLoud());
      expect(env.loudnessAt(const Duration(milliseconds: -10)), 0);
      expect(env.loudnessAt(const Duration(seconds: 2)), 0);
      expect(env.mouthAt(const Duration(seconds: 2)).open, 0);
    });

    test('averages the channels of a stereo file', () {
      final mono = _quietThenLoud();
      final data = ByteData.sublistView(mono);
      final frames = (mono.length - 44) ~/ 2;
      final stereo = ByteData(44 + frames * 4);
      for (var i = 0; i < 44; i++) {
        stereo.setUint8(i, mono[i]);
      }
      stereo
        ..setUint16(22, 2, Endian.little)
        ..setUint32(40, frames * 4, Endian.little);
      for (var f = 0; f < frames; f++) {
        final v = data.getInt16(44 + f * 2, Endian.little);
        stereo
          ..setInt16(44 + f * 4, v, Endian.little)
          ..setInt16(46 + f * 4, 0, Endian.little);
      }
      final env = SpeechEnvelope.fromWav(stereo.buffer.asUint8List());
      expect(env.levels, hasLength(60));
      expect(
        env.loudnessAt(const Duration(milliseconds: 800)),
        closeTo(1, 0.05),
      );
    });

    test('rejects what is not 16-bit PCM WAV', () {
      expect(
        () => SpeechEnvelope.fromWav(Uint8List.fromList([1, 2, 3])),
        throwsFormatException,
      );
      final float = _quietThenLoud();
      ByteData.sublistView(float).setUint16(20, 3, Endian.little);
      expect(() => SpeechEnvelope.fromWav(float), throwsFormatException);
    });

    test('an empty clip has no levels and never opens the mouth', () {
      final env = SpeechEnvelope.fromWav(encodeWavBytes(const [], 24000));
      expect(env.levels, isEmpty);
      expect(env.mouthAt(Duration.zero).open, 0);
    });
  });

  group('mouthForLoudness', () {
    test('rests when quiet and opens wider as it gets louder', () {
      expect(mouthForLoudness(0).open, Viseme.x.shape.open);
      expect(mouthForLoudness(0.05).open, 0);
      var last = -1.0;
      for (var l = 0.1; l <= 1.0; l += 0.05) {
        final open = mouthForLoudness(l).open;
        expect(open, greaterThanOrEqualTo(last));
        last = open;
      }
      expect(mouthForLoudness(1).open, closeTo(Viseme.d.shape.open, 1e-9));
    });
  });

  test('a voice alone has no words to time', () {
    expect(SpeechEnvelope([1, 1]).timeOf(0), isNull);
  });
}
