import 'dart:typed_data';

import 'package:lotti/features/companion/animation/mouth_track.dart';
import 'package:lotti/features/companion/animation/pause_alignment.dart';
import 'package:lotti/features/companion/animation/sound_alignment.dart';
import 'package:lotti/features/companion/animation/sound_features.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/animation/wav_pcm.dart';
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
/// Given how the voice sounds as well (`sound`), every sound of the words is
/// then pinned to where the voice makes it ([SoundAlignment]): inside a long
/// phrase the letters' guessed durations no longer drift.
/// The voice's loudness then gates the shapes: silent, the lips close; loud,
/// the shape opens fully. This is what the on-device and cloud voices can
/// feed, since they know the text they spoke.
class VoicedTextTrack implements MouthTrack {
  VoicedTextTrack(this.envelope, String text, {SoundFeatures? sound})
    : words = TextLipSync(text) {
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
      // Given the sound, only sentences are pinned: a voice often runs
      // through a comma and breathes a word later, and the sound places a
      // comma's silence far better than a guess at which gap it is.
      minWeight: sound == null ? 0 : SoundAlignment.minPinWeight,
    );
    _warp = sound == null || !_voiced
        ? null
        : ClockWarp(
            SoundAlignment.knots(
              sounds: words.sounds,
              phrases: alignment.phrases,
              levels: levels,
              brightness: sound.brightness,
              fps: fps,
              fallback: alignment.voiceTimeOf,
            ),
          );
  }

  /// The words of [text] on the 16-bit PCM WAV [bytes], timed by both the
  /// voice's pauses and its sounds.
  factory VoicedTextTrack.fromWav(Uint8List bytes, String text) {
    final pcm = readPcm16(bytes);
    return VoicedTextTrack(
      SpeechEnvelope.fromPcm(pcm),
      text,
      sound: SoundFeatures.fromPcm(pcm),
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

  /// Every sound pinned, when the voice's sound was given.
  late final ClockWarp? _warp;

  double _voiceOf(double text) =>
      _warp?.voiceOf(text) ?? alignment.voiceTimeOf(text);

  double _textOf(double voice) =>
      _warp?.textOf(voice) ?? alignment.textTimeOf(voice);

  @override
  Duration get length => envelope.length;

  @override
  double loudnessAt(Duration position) => envelope.loudnessAt(position);

  /// When the voice reaches the character at [offset]: the words' own time
  /// for it, carried onto the voice as the shapes are.
  @override
  Duration timeOf(int offset) => _duration(_voiceOf(words.secondsOf(offset)));

  @override
  MouthShape mouthAt(Duration position) {
    final l = envelope.loudnessAt(position);
    if (l < _quiet || !_voiced) return Viseme.x.shape;
    final now = position.inMicroseconds / 1e6;
    final cue = words.cueAtSeconds(_textOf(now));
    // Blended over the voice's own time since the shape began: its letters
    // may be stretched or squeezed to the sound, the lips' speed is not.
    final shape = cue.previous.shape.blend(
      cue.current.shape,
      smoothstep((now - _voiceOf(cue.start)) / TextLipSync.blendSeconds),
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
