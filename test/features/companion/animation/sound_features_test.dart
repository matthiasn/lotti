import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/sound_features.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';

import '../companion_test_utils.dart';

List<double> _tone(double hz, int rate, double seconds) => [
  for (var i = 0; i < (seconds * rate).round(); i++)
    0.5 * math.sin(2 * math.pi * hz * i / rate),
];

void main() {
  group('SoundFeatures.fromPcm', () {
    test('a pure tone reads as its own frequency, at any sample rate', () {
      for (final rate in [16000, 24000, 44100]) {
        for (final hz in [220.0, 1000.0, 4000.0]) {
          final f = SoundFeatures.fromPcm((
            sampleRate: rate,
            samples: _tone(hz, rate, 0.5),
          ));
          // Away from the clip's edges, where the windows are whole.
          expect(
            f.brightness[15],
            closeTo(hz, hz * 0.03),
            reason: '$hz Hz at $rate',
          );
        }
      }
    });

    test('a hiss is bright, a vowel dark, silence reads nothing', () {
      const rate = 24000;
      final f = SoundFeatures.fromPcm((
        sampleRate: rate,
        samples: synthSpeech([
          (Sound.vowel, 0.3),
          (Sound.hiss, 0.3),
          (Sound.silence, 0.3),
        ]),
      ));
      expect(f.brightness[9], lessThan(500));
      // White noise centres on a quarter of the sample rate.
      expect(f.brightness[27], closeTo(rate / 4, 600));
      expect(f.brightness[45], 0);
    });

    test('has one reading per window of the loudness envelope', () {
      final pcm = (
        sampleRate: 24000,
        samples: synthSpeech([(Sound.vowel, 0.505)]),
      );
      expect(
        SoundFeatures.fromPcm(pcm).brightness,
        hasLength(SpeechEnvelope.fromPcm(pcm).levels.length),
      );
    });
  });
}
