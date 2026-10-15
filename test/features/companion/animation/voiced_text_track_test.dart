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
}
