import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/demo/dance_playback_stepper.dart';
import 'package:lotti/features/character/model/beat_map.dart';
import 'package:lotti/features/character/model/face.dart';

BeatMap _beatMap() => BeatMap(
  beatTimesSec: [for (var i = 0; i < 13; i++) i * 0.5],
  downbeatIndices: const [0, 4, 8, 12],
);

DancePerformance _perf({List<DanceWord> words = const []}) {
  final map = _beatMap();
  return DancePerformance(
    map: map,
    binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
    sections: const [
      (start: 0, end: 6, label: 'A', energetic: true, level: 1),
    ],
    sectionSpans: const [],
    trackDurationSec: 6,
    words: words,
  );
}

void main() {
  group('DancePlaybackStepper', () {
    test(
      'before the track loads (null perf) the trio idles and shot holds',
      () {
        final stepper = DancePlaybackStepper()
          ..advance(null, const [], 1, 0.016);
        expect(stepper.stage?.lead.name, 'idle');
        expect(stepper.leadMouth, 0);
        expect(stepper.bgMouth, 0);
        // No director context → the camera holds its neutral framing.
        expect(stepper.shot, (zoom: 1.0, dx: 0.0, dy: 0.0));
      },
    );

    test('an active lip-sync cue opens the frontman mouth', () {
      // 'D' is the widest viseme (open 0.6); no lyrics → the frontman lip-syncs.
      const cues = [(start: 0.0, end: 1.0, shape: 'D')];
      final stepper = DancePlaybackStepper()..advance(_perf(), cues, 0.5, 0.06);
      expect(stepper.leadMouth, greaterThan(0.4));
      expect(stepper.leadShape, MouthShape.singAh);
    });

    test('the mouth eases back toward shut once the cue ends', () {
      const cues = [(start: 0.0, end: 0.4, shape: 'D')];
      final perf = _perf();
      final stepper = DancePlaybackStepper()..advance(perf, cues, 0.3, 0.06);
      final opened = stepper.leadMouth;
      stepper.advance(perf, cues, 0.6, 0.06); // past the cue → target 0
      expect(stepper.leadMouth, lessThan(opened));
    });

    test('the stage tracks the performance derivation', () {
      final stepper = DancePlaybackStepper()
        ..advance(_perf(), const [], 2, 0.06);
      // Energetic section at full level → the unison Buga hit.
      expect(stepper.stage?.lead.name, 'buga');
    });

    test('in an energetic section the camera moves off its neutral hold', () {
      final perf = _perf();
      final stepper = DancePlaybackStepper();
      for (var i = 0; i < 30; i++) {
        stepper.advance(perf, const [], 0.5 + i * 0.06, 0.06);
      }
      final shot = stepper.shot;
      expect(
        shot.zoom != 1.0 || shot.dx != 0.0 || shot.dy != 0.0,
        isTrue,
        reason: 'the director drives the framing away from the neutral hold',
      );
    });

    test('background-only words leave the frontman silent', () {
      const cues = [(start: 0.0, end: 1.0, shape: 'D')];
      final perf = _perf(
        words: const [
          (start: 0, end: 2, word: 'la', voice: 'background', section: 'verse'),
        ],
      );
      final stepper = DancePlaybackStepper()..advance(perf, cues, 0.5, 0.06);
      // The lead has lyrics but isn't singing now → frontman mouth rests.
      expect(stepper.leadMouth, 0);
      // The backup IS singing → its mouth opens.
      expect(stepper.bgMouth, greaterThan(0.4));
    });

    test(
      'a lead word drives the frontman via voiceActive (not words.isEmpty)',
      () {
        const cues = [(start: 0.0, end: 1.0, shape: 'D')];
        final perf = _perf(
          words: const [
            (start: 0, end: 2, word: 'go', voice: 'lead', section: 'verse'),
          ],
        );
        final stepper = DancePlaybackStepper()..advance(perf, cues, 0.5, 0.06);
        expect(stepper.leadMouth, greaterThan(0.4));
        // A verse (not a group hook) → the backups stay shut.
        expect(stepper.bgMouth, 0);
      },
    );

    test('on a group-hook section the backups join the lead word', () {
      const cues = [(start: 0.0, end: 1.0, shape: 'D')];
      final perf = _perf(
        words: const [
          (start: 0, end: 2, word: 'oh', voice: 'lead', section: 'chorus'),
        ],
      );
      final stepper = DancePlaybackStepper()..advance(perf, cues, 0.5, 0.06);
      expect(stepper.leadMouth, greaterThan(0.4));
      // 'chorus' is a group hook → the backups sing the lead word too.
      expect(stepper.bgMouth, greaterThan(0.4));
    });
  });
}
