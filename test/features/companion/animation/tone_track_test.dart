import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/animation/tone_track.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  final track = ToneTrack([
    (start: _ms(0), approval: null),
    (start: _ms(1000), approval: 2),
    (start: _ms(2000), approval: -1),
  ]);

  test('the approval is the latest cue at or before the position', () {
    expect(track.approvalAt(_ms(500)), isNull);
    expect(track.approvalAt(_ms(1000)), 2);
    expect(track.approvalAt(_ms(1999)), 2);
    expect(track.approvalAt(_ms(5000)), -1);
  });

  test('before the first cue there is no tone', () {
    expect(
      ToneTrack([(start: _ms(100), approval: 1)]).approvalAt(_ms(50)),
      isNull,
    );
    expect(ToneTrack(const []).approvalAt(_ms(50)), isNull);
  });

  test('read times each tone where the mouth reaches its words', () {
    const text = 'Four things today. You finished it, well done!';
    final mouth = TextLipSync(text);
    final tone = ToneTrack.read(text, mouth);
    expect(tone.cues, hasLength(2));
    expect(tone.cues.first.start, Duration.zero);
    expect(tone.cues.last.start, mouth.timeOf(text.indexOf(' You')));
    // Praise only once the voice reaches it.
    expect(tone.approvalAt(tone.cues.last.start - _ms(1)), isNull);
    expect(tone.approvalAt(tone.cues.last.start), greaterThan(0));
  });

  test('a voice without words gives no tones', () {
    final tone = ToneTrack.read('Well done!', SpeechEnvelope([1, 1, 1]));
    expect(tone.cues, isEmpty);
  });
}
