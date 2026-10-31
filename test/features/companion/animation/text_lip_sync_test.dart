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

  test('ph, wh, ck and ng each read as one sound', () {
    List<Viseme> shapes(String text) =>
        TextLipSync(text).cues.map((c) => c.viseme).toList();
    expect(shapes('ph'), [Viseme.g, Viseme.x]);
    expect(shapes('wh'), [Viseme.f, Viseme.x]);
    expect(shapes('ck'), [Viseme.b, Viseme.x]);
    // One sound's time, not two letters'.
    expect(
      TextLipSync('ck').spokenLength,
      lessThan(TextLipSync('ct').spokenLength),
    );
    expect(shapes('ng'), [Viseme.b, Viseme.x]);
  });

  test('a silent final e takes no shape and no time', () {
    // "have" ends on the bite of its v, not an open e.
    final have = TextLipSync('have').cues.map((c) => c.viseme).toList();
    expect(have, [Viseme.b, Viseme.d, Viseme.g, Viseme.x]);
    expect(TextLipSync('have').spokenLength, TextLipSync('hav').spokenLength);
    expect(
      TextLipSync('time, then').spokenLength,
      TextLipSync('tim, then').spokenLength,
    );
    // Short words keep their e, and so does a vowel's e.
    expect(TextLipSync('the').cues.map((c) => c.viseme), contains(Viseme.c));
    expect(
      TextLipSync('free').spokenLength,
      greaterThan(TextLipSync('fr').spokenLength),
    );
    expect(
      TextLipSync('canoe').spokenLength,
      greaterThan(TextLipSync('cano').spokenLength),
    );
  });

  test('the pauses are kept where the mouth rests, a run of stops as one', () {
    final track = TextLipSync('Hi, you?! Me.');
    expect(track.pauses, hasLength(3));
    final comma = track.pauses[0];
    expect(comma.weight, 0.5);
    // "?!" is one pause, as long as both stops and as sure as the surer.
    // The space after a stop belongs to its pause.
    expect(comma.end - comma.start, closeTo(0.25, 1e-9));
    final question = track.pauses[1];
    expect(question.end - question.start, closeTo(0.79, 1e-9));
    expect(question.weight, 1.2);
    // A trailing stop begins where the words end.
    expect(track.pauses[2].start, track.spokenSeconds);
    // Each pause starts where its rest begins.
    expect(track.mouthAtSeconds(comma.start + 0.1).open, 0);
    expect(TextLipSync('no stops here').pauses, isEmpty);
  });

  test('each sound is kept with its broad class, in order', () {
    final sync = TextLipSync('ship, me');
    expect(sync.sounds.map((u) => u.sound), [
      SoundClass.fricative,
      SoundClass.vowel,
      SoundClass.stop,
      SoundClass.pause,
      SoundClass.nasal,
      SoundClass.vowel,
    ]);
    for (var i = 1; i < sync.sounds.length; i++) {
      expect(
        sync.sounds[i].start,
        greaterThanOrEqualTo(sync.sounds[i - 1].end),
      );
    }
    // "th" is the dark, voiced sound of "the", not a hiss.
    expect(TextLipSync('the').sounds.first.sound, SoundClass.approximant);
    expect(TextLipSync('wall').sounds.last.sound, SoundClass.approximant);
  });

  test('a doubled consonant is one sound', () {
    expect(
      TextLipSync('waddle').sounds,
      hasLength(TextLipSync('wadle').sounds.length),
    );
    expect(TextLipSync('ll').spokenLength, TextLipSync('l').spokenLength);
    // Vowels are not merged: "aa" is still two.
    expect(TextLipSync('aa').sounds, hasLength(2));
  });

  test('the e of a final -es or -ed is silent where English drops it', () {
    Duration spoken(String w) => TextLipSync(w).spokenLength;
    expect(spoken('dives'), spoken('divs'));
    expect(spoken('walked'), spoken('walkd'));
    expect(spoken('waddles'), spoken('wadls'));
    // Said after a hiss, or after t or d, and in short words.
    expect(spoken('faces'), greaterThan(spoken('facs')));
    expect(spoken('boxes'), greaterThan(spoken('boxs')));
    expect(spoken('wanted'), greaterThan(spoken('wantd')));
    expect(spoken('uses'), greaterThan(spoken('uss')));
  });

  test('the cue at a time is held to the line', () {
    final sync = TextLipSync('ma');
    expect(sync.cueAtSeconds(-1).current, Viseme.a);
    expect(sync.cueAtSeconds(-1).previous, Viseme.x);
    final rest = sync.cueAtSeconds(99);
    expect(rest.current, Viseme.x);
    expect(rest.previous, Viseme.d);
    expect(rest.start, sync.spokenSeconds);
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

  group('timeOf', () {
    const text = 'Good morning. Four things today.';
    final sync = TextLipSync(text);

    test('starts at zero and never runs backwards', () {
      expect(sync.timeOf(0), Duration.zero);
      var last = Duration.zero;
      for (var i = 0; i <= text.length; i++) {
        expect(sync.timeOf(i), greaterThanOrEqualTo(last), reason: '$i');
        last = sync.timeOf(i);
      }
    });

    test('a later word is reached later, after the full stop rests', () {
      final four = sync.timeOf(text.indexOf('Four'));
      expect(four, greaterThan(sync.timeOf(text.indexOf('morning'))));
      // The full stop's pause lies between "morning" and "Four".
      expect(
        four - sync.timeOf(text.indexOf('.')),
        greaterThanOrEqualTo(const Duration(milliseconds: 380)),
      );
    });

    test('offsets past either end are the ends of the words', () {
      expect(sync.timeOf(-5), Duration.zero);
      expect(sync.timeOf(999), sync.timeOf(text.length));
      expect(sync.timeOf(text.length), lessThanOrEqualTo(sync.length));
    });

    test('runs at the rate the shapes do', () {
      final fast = TextLipSync(text, rate: 2);
      expect(
        fast.timeOf(text.length).inMicroseconds,
        closeTo(sync.timeOf(text.length).inMicroseconds / 2, 2),
      );
    });
  });
}
