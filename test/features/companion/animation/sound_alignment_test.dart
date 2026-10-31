import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/companion/animation/pause_alignment.dart';
import 'package:lotti/features/companion/animation/sound_alignment.dart';
import 'package:lotti/features/companion/animation/text_lip_sync.dart';

const _fps = 60;

/// Windows of a voice: loud and dark for a vowel, quiet and bright for a
/// hiss, nothing for silence — the readings `SoundFeatures` gives.
({List<double> levels, List<double> brightness}) _voice(
  List<(SoundClass, int)> parts,
) {
  final levels = <double>[];
  final brightness = <double>[];
  for (final (sound, windows) in parts) {
    for (var i = 0; i < windows; i++) {
      final (level, bright) = switch (sound) {
        SoundClass.vowel => (1.0, 600.0),
        SoundClass.fricative => (0.2, 6000.0),
        SoundClass.pause => (0.0, 0.0),
        SoundClass.stop => (0.05, 300.0),
        SoundClass.nasal => (0.5, 300.0),
        SoundClass.approximant => (0.6, 450.0),
      };
      levels.add(level);
      brightness.add(bright);
    }
  }
  return (levels: levels, brightness: brightness);
}

Phrase _phrase(double textEnd, double voiceEnd) =>
    (textStart: 0, textEnd: textEnd, voiceStart: 0, voiceEnd: voiceEnd);

double _never(double _) => fail('fell back');

void main() {
  group('frameCost', () {
    test('each kind of window fits its own sound best', () {
      SoundClass best(double level, double bright) => SoundClass.values.reduce(
        (a, b) =>
            SoundAlignment.frameCost(a, level, bright) <=
                SoundAlignment.frameCost(b, level, bright)
            ? a
            : b,
      );
      expect(best(1, 700), SoundClass.vowel);
      expect(best(0.2, 6000), SoundClass.fricative);
      expect(best(0, 0), SoundClass.pause);
      expect(best(0.5, 300), SoundClass.nasal);
    });
  });

  group('SoundAlignment.knots', () {
    test('lays each sound over the windows that sound like it, against '
        "the letters' guess", () {
      // "a s": the letters give the vowel and the hiss nearly equal time,
      // but the voice holds the vowel for 10 windows and hisses for 50.
      final sync = TextLipSync('a s');
      final voice = _voice([
        (SoundClass.vowel, 10),
        (SoundClass.fricative, 50),
      ]);
      final knots = SoundAlignment.knots(
        sounds: sync.sounds,
        phrases: [_phrase(sync.spokenSeconds, 1)],
        levels: voice.levels,
        brightness: voice.brightness,
        fps: _fps,
        fallback: _never,
      );
      final s = sync.sounds.last;
      final hiss = knots.firstWhere((k) => k.text == s.start).voice;
      expect(hiss, closeTo(10 / _fps, 1.5 / _fps));
    });

    test('a breath the text has no comma for is a silence, not a stretched '
        'word', () {
      // "a a": vowel, a 30-window breath, vowel.
      final sync = TextLipSync('a a');
      final voice = _voice([
        (SoundClass.vowel, 10),
        (SoundClass.pause, 30),
        (SoundClass.vowel, 10),
      ]);
      final knots = SoundAlignment.knots(
        sounds: sync.sounds,
        phrases: [_phrase(sync.spokenSeconds, 50 / _fps)],
        levels: voice.levels,
        brightness: voice.brightness,
        fps: _fps,
        fallback: _never,
      );
      final second = sync.sounds.last;
      // The second vowel starts when the voice resumes, and the first is not
      // stretched over the breath: the word break's silence takes it.
      expect(
        knots.firstWhere((k) => k.text == second.start).voice,
        closeTo(40 / _fps, 1e-9),
      );
      final breath = knots.firstWhere(
        (k) => k.text == sync.sounds.first.end,
      );
      expect(breath.voice, closeTo(10 / _fps, 1e-9));
    });

    test('a phrase with more sounds than windows keeps the fallback', () {
      final sync = TextLipSync('abcdef');
      final voice = _voice([(SoundClass.vowel, 3)]);
      final asked = <double>[];
      final knots = SoundAlignment.knots(
        sounds: sync.sounds,
        phrases: [_phrase(sync.spokenSeconds, 3 / _fps)],
        levels: voice.levels,
        brightness: voice.brightness,
        fps: _fps,
        fallback: (t) {
          asked.add(t);
          return t / 10;
        },
      );
      expect(asked, [for (final u in sync.sounds) u.start]);
      // Knot 0 is the phrase's start; each sound's follows.
      expect(knots[2], (text: sync.sounds[1].start, voice: asked[1] / 10));
    });

    test('a phrase too long to search keeps the fallback', () {
      // Enough sounds and windows to pass the cap on the search's size.
      final sync = TextLipSync(List.filled(2000, 'ba').join(' '));
      final windows = SoundAlignment.maxSearchCells ~/ sync.sounds.length + 10;
      final voice = _voice([(SoundClass.vowel, windows)]);
      var fellBack = false;
      SoundAlignment.knots(
        sounds: sync.sounds,
        phrases: [_phrase(sync.spokenSeconds, windows / _fps)],
        levels: voice.levels,
        brightness: voice.brightness,
        fps: _fps,
        fallback: (t) {
          fellBack = true;
          return t;
        },
      );
      expect(fellBack, isTrue);
    });

    test('a pinned pause between phrases is not a sound of either', () {
      final sync = TextLipSync('a. a');
      final pause = sync.pauses.single;
      final voice = _voice([
        (SoundClass.vowel, 10),
        (SoundClass.pause, 20),
        (SoundClass.vowel, 10),
      ]);
      final knots = SoundAlignment.knots(
        sounds: sync.sounds,
        phrases: [
          (
            textStart: 0,
            textEnd: pause.start,
            voiceStart: 0,
            voiceEnd: 10 / 60,
          ),
          (
            textStart: pause.end,
            textEnd: sync.spokenSeconds,
            voiceStart: 30 / 60,
            voiceEnd: 40 / 60,
          ),
        ],
        levels: voice.levels,
        brightness: voice.brightness,
        fps: _fps,
        fallback: _never,
      );
      expect(knots.where((k) => k.text == pause.start), [
        (text: pause.start, voice: 10 / 60),
      ]);
      expect(knots.last, (text: sync.spokenSeconds, voice: 40 / 60));
    });
  });

  group('ClockWarp', () {
    final warp = ClockWarp([
      (text: 0, voice: 1),
      (text: 1, voice: 2),
      (text: 2, voice: 2),
      (text: 3, voice: 4),
    ]);

    test('maps both ways between knots, and holds still outside them', () {
      expect(warp.voiceOf(0.5), 1.5);
      expect(warp.textOf(3), 2.5);
      expect(warp.voiceOf(-1), 1);
      expect(warp.textOf(9), 3);
    });

    test('where the voice holds still, the words are already past it', () {
      expect(warp.textOf(2), 2);
      expect(warp.voiceOf(1.5), 2);
    });

    test('knots out of order are carried forward, never back', () {
      final w = ClockWarp([
        (text: 0, voice: 0),
        (text: 1, voice: 2),
        (text: 2, voice: 1),
      ]);
      expect(w.voiceOf(2), 2);
      expect(ClockWarp(const []).voiceOf(1), 0);
    });

    glados.Glados(
      glados.any.listWithLengthInRange(
        1,
        12,
        glados.any.doubleInRange(0, 1),
      ),
      glados.ExploreConfig(numRuns: 150),
    ).test('both maps run forward', (steps) {
      var t = 0.0;
      var v = 0.0;
      final knots = <ClockKnot>[];
      for (var i = 0; i < steps.length; i++) {
        t += steps[i];
        v += steps[(i + 1) % steps.length];
        knots.add((text: t, voice: v));
      }
      final w = ClockWarp(knots);
      var last = double.negativeInfinity;
      for (var x = -0.5; x <= t + 0.5; x += 0.01) {
        expect(w.voiceOf(x), greaterThanOrEqualTo(last));
        last = w.voiceOf(x);
      }
      last = double.negativeInfinity;
      for (var x = -0.5; x <= v + 0.5; x += 0.01) {
        expect(w.textOf(x), greaterThanOrEqualTo(last));
        last = w.textOf(x);
      }
    }, tags: 'glados');
  });
}
