import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_lip_sync.dart';
import 'package:lotti/features/character/model/face.dart';

void main() {
  group('mouthForCue', () {
    // Each Rhubarb letter maps to a specific viseme + opening.
    const expected = <String, (MouthShape, double)>{
      'A': (MouthShape.singAh, 0), // closed rest
      'B': (MouthShape.singEe, 0.3),
      'C': (MouthShape.singAh, 0.46),
      'D': (MouthShape.singAh, 0.6),
      'E': (MouthShape.singOh, 0.4),
      'F': (MouthShape.singOh, 0.26),
      'G': (MouthShape.teethOnLip, 0.1),
      'H': (MouthShape.singAh, 0.4),
      'X': (MouthShape.singAh, 0), // idle
      '?': (MouthShape.singAh, 0), // unknown letters rest closed
    };

    test('maps every cue letter to its viseme + opening', () {
      expected.forEach((letter, want) {
        final got = mouthForCue(letter);
        expect((got.shape, got.open), want, reason: 'cue "$letter"');
      });
    });

    test('rest cues (A/X/unknown) are fully shut', () {
      for (final letter in ['A', 'X', 'q']) {
        expect(mouthForCue(letter).open, 0, reason: 'cue "$letter"');
      }
    });

    test('openings stay tasteful — the widest vowel never gapes', () {
      final widest = [
        'B',
        'C',
        'D',
        'E',
        'F',
        'H',
      ].map((l) => mouthForCue(l).open).reduce((a, b) => a > b ? a : b);
      expect(widest, lessThanOrEqualTo(0.6));
    });

    test('the F/V consonant is tight (near-closed), not a vowel gape', () {
      final fv = mouthForCue('G');
      expect(fv.shape, MouthShape.teethOnLip);
      expect(fv.open, lessThan(0.15));
    });
  });

  group('cueShapeAt', () {
    const cues = <DanceCue>[
      (start: 0, end: 0.5, shape: 'B'),
      (start: 0.5, end: 1, shape: 'C'),
      (start: 2, end: 2.5, shape: 'D'), // a gap before this one
    ];

    test('returns the cue covering pos (start inclusive, end exclusive)', () {
      expect(cueShapeAt(cues, 0.2), 'B');
      expect(cueShapeAt(cues, 0.5), 'C'); // boundary belongs to the next cue
      expect(cueShapeAt(cues, 2.4), 'D');
    });

    test('rests with X in gaps, before the first cue, and after the last', () {
      expect(cueShapeAt(cues, 1.5), 'X'); // gap between C and D
      expect(
        cueShapeAt(
          cues,
          3,
        ),
        'X',
      ); // after the last cue
      expect(cueShapeAt(const [], 1), 'X'); // no cues at all
    });
  });

  group('windowActiveAt', () {
    test('half-open window: start inclusive, end exclusive (no slack)', () {
      expect(windowActiveAt(1, 2, 1, 0), isTrue);
      expect(windowActiveAt(1, 2, 1.5, 0), isTrue);
      expect(windowActiveAt(1, 2, 2, 0), isFalse);
    });

    test('slack dilates the window on both sides to bridge short gaps', () {
      expect(windowActiveAt(1, 2, 0.8, 0.3), isTrue); // within slack before
      expect(windowActiveAt(1, 2, 2.2, 0.3), isTrue); // within slack after
      expect(windowActiveAt(1, 2, 0.6, 0.3), isFalse); // beyond slack before
      expect(windowActiveAt(1, 2, 2.4, 0.3), isFalse); // beyond slack after
    });
  });
}
