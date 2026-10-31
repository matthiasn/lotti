import 'dart:math' as math;

import 'package:lotti/features/companion/animation/wav_pcm.dart';

/// What a voice sounds like in each 1/[fps] s window, beyond how loud it is:
/// how bright it is.
///
/// Brightness is the voice's root-mean-square frequency in Hz, read from how
/// much the waveform changes from one sample to the next: a hiss (s, sh, f)
/// changes fast and sits around 4–6 kHz, a vowel near 1 kHz, a hummed m or n
/// lower still. It needs no Fourier transform — the energy of the differenced
/// signal over the signal's own energy is `4·sin²(πf/rate)` for a tone of
/// frequency `f` — so it is cheap, runs the same on every platform, and reads
/// alike at any sample rate.
class SoundFeatures {
  SoundFeatures(this.brightness, {this.fps = 60});

  /// Reads the windows of [pcm], the same windows as `SpeechEnvelope`.
  factory SoundFeatures.fromPcm(Pcm pcm, {int fps = 60}) {
    final samples = pcm.samples;
    final rate = pcm.sampleRate;
    final per = math.max(1, rate ~/ fps);
    final count = (samples.length + per - 1) ~/ per;
    final signal = List<double>.filled(count, 0);
    final change = List<double>.filled(count, 0);
    for (var w = 0; w < count; w++) {
      final end = math.min(samples.length, (w + 1) * per);
      for (var i = w * per; i < end; i++) {
        final x = samples[i];
        final d = i > 0 ? x - samples[i - 1] : 0.0;
        signal[w] += x * x;
        change[w] += d * d;
      }
    }
    // Each window is read with its neighbours, as the envelope's levels are,
    // so one window's noise does not flip its reading.
    final brightness = List<double>.filled(count, 0);
    for (var w = 0; w < count; w++) {
      var s = 0.0;
      var c = 0.0;
      for (var k = math.max(0, w - 1); k <= math.min(count - 1, w + 1); k++) {
        s += signal[k];
        c += change[k];
      }
      final ratio = s <= 0 ? 0.0 : math.min(4, c / s).toDouble();
      brightness[w] = rate / math.pi * math.asin(math.sqrt(ratio) / 2);
    }
    return SoundFeatures(brightness, fps: fps);
  }

  /// The root-mean-square frequency of each window, in Hz.
  final List<double> brightness;
  final int fps;
}
