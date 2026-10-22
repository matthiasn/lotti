import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/companion/animation/speech_envelope.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/animation/tone_track.dart';
import 'package:lotti/features/companion/model/companion_reaction.dart';

Duration _ms(int ms) => Duration(milliseconds: ms);

void main() {
  final track = ToneTrack([
    (start: _ms(0), approval: null, beat: null),
    (start: _ms(1000), approval: 2, beat: SassBeat.exclaim),
    (start: _ms(2000), approval: -1, beat: null),
  ]);

  test('the approval is the latest cue at or before the position', () {
    expect(track.approvalAt(_ms(500)), isNull);
    expect(track.approvalAt(_ms(1000)), 2);
    expect(track.approvalAt(_ms(1999)), 2);
    expect(track.approvalAt(_ms(5000)), -1);
  });

  test('before the first cue there is no tone', () {
    expect(
      ToneTrack([
        (start: _ms(100), approval: 1, beat: null),
      ]).approvalAt(_ms(50)),
      isNull,
    );
    expect(ToneTrack(const []).approvalAt(_ms(50)), isNull);
  });

  test('the index is the latest cue at or before the position', () {
    expect(track.indexAt(_ms(0)), 0);
    expect(track.indexAt(_ms(1500)), 1);
    expect(track.indexAt(_ms(9000)), 2);
    expect(
      ToneTrack([
        (start: _ms(100), approval: 1, beat: null),
      ]).indexAt(_ms(50)),
      -1,
    );
  });

  test('read carries each beat to the time the voice reaches it', () {
    const text = 'Four things today. Did you look at them?';
    final mouth = TextLipSync(text);
    final tone = ToneTrack.read(text, mouth);
    expect(tone.cues.map((c) => c.beat), [null, SassBeat.question]);
    expect(tone.cues.last.start, mouth.timeOf(text.indexOf(' Did')));
  });

  test('read knows when the words are over; a built track does not', () {
    const text = 'Four things today. Did you look at them?';
    final mouth = TextLipSync(text);
    expect(ToneTrack.read(text, mouth).end, mouth.timeOf(text.length));
    expect(ToneTrack([]).end, isNull);
    expect(ToneTrack([], end: _ms(900)).end, _ms(900));
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
