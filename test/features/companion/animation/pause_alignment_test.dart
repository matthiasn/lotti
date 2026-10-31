import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/companion/animation/pause_alignment.dart';

TextPause _pause(double start, double end, [double weight = 1.2]) =>
    (start: start, end: end, weight: weight);

SilentSpan _gap(double start, double end) => (start: start, end: end);

void main() {
  group('PauseAlignment', () {
    test('pins a pause to the gap where the voice paused, not where the '
        'letters guessed', () {
      // Words: 1 s, a 0.3 s stop, 1 s. Voice: from 0.5 s, a short first
      // phrase (0.6 s), a 0.5 s gap, then a long second one (1.4 s).
      final alignment = PauseAlignment.align(
        textEnd: 2.3,
        textPauses: [_pause(1, 1.3)],
        voiceFrom: 0.5,
        voiceTo: 3,
        voiceGaps: [_gap(1.1, 1.6)],
      );

      expect(alignment.matches, [(text: 0, voice: 0)]);
      // The last word before the stop ends as the voice falls silent, and
      // the first one after it starts as the voice resumes.
      expect(alignment.voiceTimeOf(0.999), closeTo(1.1, 0.01));
      expect(alignment.voiceTimeOf(1.3), closeTo(1.6, 1e-9));
      // Each phrase is stretched over its own stretch of voice.
      expect(alignment.voiceTimeOf(0.5), closeTo(0.8, 1e-9));
      expect(alignment.voiceTimeOf(1.8), closeTo(2.3, 1e-9));
    });

    test('inside a gap the words wait at their pause', () {
      final alignment = PauseAlignment.align(
        textEnd: 2.3,
        textPauses: [_pause(1, 1.3)],
        voiceFrom: 0,
        voiceTo: 2.5,
        voiceGaps: [_gap(1, 1.5)],
      );

      expect(alignment.textTimeOf(1.2), closeTo(1.3, 1e-9));
      expect(alignment.textTimeOf(1.45), closeTo(1.3, 1e-9));
      expect(alignment.textTimeOf(1.75), closeTo(1.55, 1e-9));
    });

    test('a comma the voice ran through is left unpinned', () {
      // Comma at 0.5 s of speech, full stop at 1.5 s; the voice only
      // paused once, about three quarters of the way in.
      final alignment = PauseAlignment.align(
        textEnd: 2.5,
        textPauses: [_pause(0.5, 0.7, 0.5), _pause(1.7, 2)],
        voiceFrom: 0,
        voiceTo: 2.4,
        voiceGaps: [_gap(1.5, 1.9)],
      );

      expect(alignment.matches, [(text: 1, voice: 0)]);
    });

    test('a breath the text gave no reason for is left unpinned', () {
      final alignment = PauseAlignment.align(
        textEnd: 2.3,
        textPauses: [_pause(1, 1.3)],
        voiceFrom: 0,
        voiceTo: 2.6,
        voiceGaps: [_gap(0.45, 0.62), _gap(1, 1.4)],
      );

      expect(alignment.matches, [(text: 0, voice: 1)]);
    });

    test('with nothing to pin, the words are stretched over the speech, '
        'gaps squeezed out', () {
      final alignment = PauseAlignment.align(
        textEnd: 1,
        textPauses: const [],
        voiceFrom: 1,
        voiceTo: 3,
        voiceGaps: const [],
      );

      expect(alignment.matches, isEmpty);
      expect(alignment.voiceTimeOf(0), 1);
      expect(alignment.voiceTimeOf(0.5), closeTo(2, 1e-9));
      expect(alignment.voiceTimeOf(1), closeTo(3, 1e-9));
      expect(alignment.textTimeOf(0), 0);
      expect(alignment.textTimeOf(4), closeTo(1, 1e-9));
    });

    test('no words, or no voice, maps everything to the start', () {
      final noWords = PauseAlignment.align(
        textEnd: 0,
        textPauses: const [],
        voiceFrom: 0.5,
        voiceTo: 1.5,
        voiceGaps: const [],
      );
      expect(noWords.textTimeOf(1), 0);

      final noVoice = PauseAlignment.align(
        textEnd: 1,
        textPauses: [_pause(0.4, 0.6)],
        voiceFrom: 0,
        voiceTo: 0,
        voiceGaps: const [],
      );
      expect(noVoice.matches, isEmpty);
      expect(noVoice.voiceTimeOf(0.5), 0);
    });

    test('pauses before the first word or after the last pin nothing', () {
      final alignment = PauseAlignment.align(
        textEnd: 1.4,
        textPauses: [_pause(0, 0.4), _pause(1.4, 1.8)],
        voiceFrom: 0,
        voiceTo: 1,
        voiceGaps: const [],
      );

      expect(alignment.matches, isEmpty);
      // The leading pause is squeezed out: the first word starts with the
      // voice.
      expect(alignment.voiceTimeOf(0.4), 0);
      expect(alignment.textTimeOf(0), closeTo(0.4, 1e-9));
    });

    glados.Glados2(
      glados.any.listWithLengthInRange(0, 8, glados.any.doubleInRange(0, 1)),
      glados.any.listWithLengthInRange(0, 8, glados.any.doubleInRange(0, 1)),
      glados.ExploreConfig(numRuns: 200),
    ).test('both maps run forward and stay inside the speech', (
      pauseSeeds,
      gapSeeds,
    ) {
      // Pauses and gaps laid end to end from the seeds, never overlapping.
      final pauses = <TextPause>[];
      var t = 0.0;
      for (final seed in pauseSeeds) {
        t += 0.1 + seed;
        pauses.add(_pause(t, t + 0.2 + seed / 2, 0.5 + seed));
        t += 0.2 + seed / 2;
      }
      final textEnd = t + 0.3;
      final gaps = <SilentSpan>[];
      var v = 0.4;
      for (final seed in gapSeeds) {
        v += 0.1 + seed;
        gaps.add(_gap(v, v + 0.15 + seed / 3));
        v += 0.15 + seed / 3;
      }
      final voiceTo = v + 0.3;

      final alignment = PauseAlignment.align(
        textEnd: textEnd,
        textPauses: pauses,
        voiceFrom: 0.4,
        voiceTo: voiceTo,
        voiceGaps: gaps,
      );

      var lastText = alignment.textTimeOf(-1);
      for (var x = -0.5; x <= voiceTo + 0.5; x += 0.01) {
        final mapped = alignment.textTimeOf(x);
        expect(mapped, greaterThanOrEqualTo(lastText - 1e-9));
        expect(mapped, inInclusiveRange(0, textEnd + 1e-9));
        lastText = mapped;
      }
      var lastVoice = alignment.voiceTimeOf(-1);
      for (var x = -0.5; x <= textEnd + 0.5; x += 0.01) {
        final mapped = alignment.voiceTimeOf(x);
        expect(mapped, greaterThanOrEqualTo(lastVoice - 1e-9));
        expect(mapped, inInclusiveRange(0.4, voiceTo + 1e-9));
        lastVoice = mapped;
      }
      for (var k = 1; k < alignment.matches.length; k++) {
        expect(
          alignment.matches[k].text,
          greaterThan(alignment.matches[k - 1].text),
        );
        expect(
          alignment.matches[k].voice,
          greaterThan(alignment.matches[k - 1].voice),
        );
      }
    }, tags: 'glados');
  });
}
