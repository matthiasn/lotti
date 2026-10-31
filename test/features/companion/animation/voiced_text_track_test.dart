import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/voiced_text_track.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';

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
    // "a" then "m": open first, closed lips by the end of the voice.
    final track = VoicedTextTrack(envelope, 'aaaaaaaa mmmmmmmm');
    expect(track.mouthAt(_ms(600)).open, greaterThan(5));
    expect(track.mouthAt(_ms(1350)).open, lessThan(0.5));
  });

  test('the last word reaches the end of the voice', () {
    // The text's closing rest is not stretched over the voice: an open
    // vowel ending the line is still open just before the voice stops,
    // rather than the lips closing early on a rest the voice does not have.
    final track = VoicedTextTrack(envelope, 'mmmmmmmm aaaaaaaa');
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
