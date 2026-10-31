import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/sound_features.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/voiced_text_track.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';
import 'package:lotti/features/tts/engine/wav_writer.dart';

import '../companion_test_utils.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  // 0.5 s of silence, 1 s of voice, 0.5 s of silence.
  final envelope = SpeechEnvelope([
    for (var i = 0; i < 30; i++) 0.0,
    for (var i = 0; i < 60; i++) 1.0,
    for (var i = 0; i < 30; i++) 0.0,
  ]);

  test('takes its length and loudness from the voice', () {
    final track = VoicedTextTrack(envelope, 'mama');
    expect(track.length, envelope.length);
    expect(track.loudnessAt(_ms(1000)), 1);
    expect(track.loudnessAt(_ms(100)), 0);
  });

  test('the lips close wherever the voice is silent', () {
    final track = VoicedTextTrack(envelope, 'aaaa');
    expect(track.mouthAt(_ms(200)).open, 0);
    expect(track.mouthAt(_ms(1800)).open, 0);
  });

  test("the words' shapes are stretched over the voiced part", () {
    // "a" then m/b: open first, closed lips by the end of the voice.
    final track = VoicedTextTrack(envelope, 'aaaaaaaa mbmbmbmb');
    expect(track.mouthAt(_ms(600)).open, greaterThan(5));
    expect(track.mouthAt(_ms(1350)).open, lessThan(0.5));
  });

  test('the last word reaches the end of the voice', () {
    // The text's closing rest is not stretched over the voice: an open
    // vowel ending the line is still open just before the voice stops,
    // rather than the lips closing early on a rest the voice does not have.
    final track = VoicedTextTrack(envelope, 'mbmbmbmb aaaaaaaa');
    expect(track.mouthAt(_ms(1450)).open, greaterThan(5));
  });

  test('a clip with no voice at all never opens the mouth', () {
    final silent = SpeechEnvelope(List.filled(30, 0));
    final track = VoicedTextTrack(silent, 'hello');
    expect(track.mouthAt(_ms(200)).open, Viseme.x.shape.open);
  });

  group('pinned to the pauses of a real voice', () {
    // The voiced stretches of a cloud voice speaking [line], measured from
    // the clip at 60 windows a second: it pauses 0.43 s at the comma and
    // 0.6 s at the full stop; the shorter dips are closures inside words.
    const line = 'The penguin waddles to the water, then dives. It swims fast!';
    const runs = [
      (0.033, 0.133),
      (0.267, 0.7),
      (0.733, 1.167),
      (1.267, 1.833),
      (2.267, 2.533),
      (2.6, 2.933),
      (3.533, 3.633),
      (3.683, 3.8),
      (3.833, 4.133),
      (4.25, 4.517),
      (4.567, 4.667),
    ];
    final voice = SpeechEnvelope([
      for (var i = 0; i < 293; i++)
        if (runs.any(
          (r) => i >= (r.$1 * 60).round() && i < (r.$2 * 60).round(),
        ))
          1.0
        else
          0.0,
    ]);
    final track = VoicedTextTrack(voice, line);

    test('pins the comma and the full stop to where the voice paused', () {
      expect(track.alignment.matches, [
        (text: 0, voice: 0),
        (text: 1, voice: 1),
      ]);
    });

    test('each phrase starts as the voice resumes', () {
      // A single stretch over the clip put "then" at 2.55 s and "It" at
      // 3.75 s — a quarter to half a second late.
      expect(
        track.timeOf(line.indexOf('then')).inMilliseconds,
        closeTo(2267, 20),
      );
      expect(
        track.timeOf(line.indexOf('It')).inMilliseconds,
        closeTo(3533, 20),
      );
    });

    test('the mouth shapes "then" while the voice says it', () {
      // 2.33 s, just into "then": the tongue of its "th", where a single
      // stretch still held the comma's closed lips.
      final mouth = track.mouthAt(_ms(2330));
      expect(mouth.tongueUp, greaterThan(0.5));
      expect(mouth.open, greaterThan(3));
    });
  });

  group('timed by the sound of the voice', () {
    // "ma sa": the voice says "ma" for 0.2 s, hisses its s for 0.6 s, and
    // ends on a 0.2 s "a". The letters give the s barely a sixth of that.
    final wav = encodeWavBytes(
      synthSpeech([
        (Sound.vowel, 0.2),
        (Sound.hiss, 0.6),
        (Sound.vowel, 0.2),
      ]),
      24000,
    );
    const text = 'ma sa';

    test('the hiss starts where the voice starts hissing', () {
      final track = VoicedTextTrack.fromWav(wav, text);
      expect(
        track.timeOf(text.indexOf('s')).inMilliseconds,
        closeTo(200, 40),
      );
      // The last vowel starts as the voice turns back to a vowel.
      expect(
        track.timeOf(text.lastIndexOf('a')).inMilliseconds,
        closeTo(800, 40),
      );
    });

    test('mid-hiss the mouth shows the s, not the vowel before it', () {
      final mouth = VoicedTextTrack.fromWav(wav, text).mouthAt(_ms(500));
      // Teeth together, barely open; one stretch over the voice still
      // held the first "a" wide open here.
      expect(mouth.teethTop, greaterThan(0.5));
      expect(mouth.open, lessThan(Viseme.b.shape.open + 0.01));
    });

    test('with the sound, a comma is placed by it rather than pinned', () {
      // A comma and a full stop, each with a silence in the voice.
      final levels = SpeechEnvelope([
        for (var i = 0; i < 20; i++) 1.0,
        for (var i = 0; i < 20; i++) 0.0,
        for (var i = 0; i < 20; i++) 1.0,
        for (var i = 0; i < 20; i++) 0.0,
        for (var i = 0; i < 20; i++) 1.0,
      ]);
      const line = 'ma, ma. ma';
      final plain = VoicedTextTrack(levels, line);
      final sounded = VoicedTextTrack(
        levels,
        line,
        sound: SoundFeatures(List.filled(100, 500)),
      );
      expect(plain.alignment.matches, hasLength(2));
      // Only the full stop may pin: it is the first such pause.
      expect(sounded.alignment.matches, [(text: 0, voice: 1)]);
      // The comma's silence still lands where the voice is silent.
      expect(
        sounded.timeOf(line.indexOf(' ma.') + 1).inMilliseconds,
        closeTo(667, 40),
      );
    });
  });

  test("the words' times are stretched over the voiced part too", () {
    const text = 'mama papa';
    final track = VoicedTextTrack(envelope, text);
    // The first word starts with the voice, at 0.5 s.
    expect(track.timeOf(0), _ms(500));
    final papa = track.timeOf(text.indexOf('papa'));
    expect(papa, greaterThan(_ms(500)));
    expect(papa, lessThan(_ms(1500)));
    // The end of the words is the end of the voice, never past it.
    expect(track.timeOf(text.length), lessThanOrEqualTo(_ms(1500)));
  });
}
