import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/companion/animation/text_lip_sync.dart';
import 'package:lotti/features/companion/model/mouth_shape.dart';

Duration _s(double seconds) => Duration(microseconds: (seconds * 1e6).round());

void main() {
  test('closed lips for m, the bite for f, an open mouth for a', () {
    final cues = TextLipSync('maf').cues.map((c) => c.viseme).toList();
    expect(cues, [Viseme.a, Viseme.d, Viseme.g, Viseme.x]);
  });

  test('digraphs read as one sound', () {
    final cues = TextLipSync('oo').cues.map((c) => c.viseme).toList();
    expect(cues, [Viseme.f, Viseme.x]);
    expect(TextLipSync('the').cues.first.viseme, Viseme.h);
  });

  test('a full stop rests the mouth longer than a word break', () {
    final word = TextLipSync('ma ma').length;
    final stop = TextLipSync('ma. ma').length;
    expect(stop - word, greaterThan(const Duration(milliseconds: 300)));
  });

  test('a faster rate says the same line in less time', () {
    const line = 'Four things today.';
    final slow = TextLipSync(line).length;
    final fast = TextLipSync(line, rate: 1.5).length;
    expect(fast.inMicroseconds, closeTo(slow.inMicroseconds / 1.5, 2));
  });

  test('the mouth rests outside the line and moves inside it', () {
    final track = TextLipSync('Good morning, Lotti!');
    expect(track.mouthAt(_s(-0.1)).open, 0);
    expect(track.mouthAt(track.length).open, 0);
    final opens = [
      for (var t = 0.0; t < track.length.inMicroseconds / 1e6; t += 0.02)
        track.mouthAt(_s(t)).open,
    ];
    expect(opens.reduce((a, b) => a > b ? a : b), greaterThan(5));
    expect(opens.where((o) => o < 0.5), isNotEmpty);
  });

  test('the spoken span ends where the closing rest begins', () {
    // "ma": 0.055 s of m, 0.085 s of a, then the 0.2 s closing rest.
    final track = TextLipSync('ma');
    expect(track.spokenLength.inMicroseconds, closeTo(140000, 1));
    expect(
      (track.length - track.spokenLength).inMicroseconds,
      closeTo(200000, 1),
    );
    // A trailing full stop's pause is rest too, not speech.
    final stopped = TextLipSync('ma.');
    expect(stopped.spokenLength, track.spokenLength);
    expect(stopped.length, greaterThan(track.length));
    expect(TextLipSync('').spokenLength, Duration.zero);
  });

  test('a new shape is blended in, not snapped', () {
    final track = TextLipSync('ma');
    final second = track.cues[1];
    final justAfter = track.mouthAt(_s(second.start + 0.01)).open;
    expect(justAfter, greaterThan(0));
    expect(justAfter, lessThan(Viseme.d.shape.open));
  });

  test('loudness stands in from how open the mouth is', () {
    final track = TextLipSync('aaa');
    expect(track.loudnessAt(_s(0.2)), closeTo(1, 1e-9));
    expect(track.loudnessAt(_s(-1)), 0);
  });

  glados.Glados(
    glados.any.letterOrDigits,
    glados.ExploreConfig(numRuns: 150),
  ).test('cues start in order and never repeat a shape back to back', (text) {
    final cues = TextLipSync(text).cues;
    for (var i = 1; i < cues.length; i++) {
      expect(cues[i].start, greaterThanOrEqualTo(cues[i - 1].start));
      expect(cues[i].viseme, isNot(cues[i - 1].viseme));
    }
    expect(cues.last.viseme, Viseme.x);
  }, tags: 'glados');
}
