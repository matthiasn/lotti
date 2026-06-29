import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/demo/dance_performance.dart';
import 'package:lotti/features/character/model/beat_map.dart';

/// A synthetic 120 BPM grid: 13 beats 0.5 s apart (0..6 s), downbeats every 4.
BeatMap _beatMap() => BeatMap(
  beatTimesSec: [for (var i = 0; i < 13; i++) i * 0.5],
  downbeatIndices: const [0, 4, 8, 12],
);

DancePerformance _perf({
  List<DanceSection> sections = const [],
  List<DanceSectionSpan> spans = const [],
  List<DanceWord> words = const [],
  double duration = 6,
}) {
  final map = _beatMap();
  return DancePerformance(
    map: map,
    binding: BeatLoopBinding.barAligned(map, bars: kDancePhraseBars),
    sections: sections,
    sectionSpans: spans,
    trackDurationSec: duration,
    words: words,
  );
}

void main() {
  group('classifyDanceSections', () {
    test('without amplitudes every section is energetic at full level', () {
      final out = classifyDanceSections(
        [(start: 0, end: 5, label: 'A'), (start: 5, end: 10, label: 'B')],
        const [],
        10,
      );
      expect(out.map((s) => s.energetic), everyElement(isTrue));
      expect(out.map((s) => s.level), everyElement(1.0));
    });

    test('a long low-energy section is calm; the loud one stays energetic', () {
      final out = classifyDanceSections(
        [
          (start: 0, end: 5, label: 'quiet'),
          (start: 5, end: 10, label: 'loud'),
        ],
        // First half silent, second half loud.
        [0, 0, 0, 0, 0, 1, 1, 1, 1, 1],
        10,
      );
      expect(out[0].energetic, isFalse, reason: 'long + low energy → calm');
      expect(out[1].energetic, isTrue);
      expect(out[0].level, lessThan(out[1].level));
      expect(out[1].level, 1.0);
    });

    test('a short low-energy section stays energetic (no idle flicker)', () {
      final out = classifyDanceSections(
        [(start: 0, end: 2, label: 'dip'), (start: 2, end: 10, label: 'loud')],
        [0, 0, 1, 1, 1, 1, 1, 1, 1, 1],
        10,
      );
      // The dip is below threshold but only 2 s (< kMinCalmSeconds) → energetic.
      expect(out[0].energetic, isTrue);
    });
  });

  group('buildDanceSectionSpans', () {
    test('collapses words into contiguous spans trimmed to the next start', () {
      final spans = buildDanceSectionSpans(
        [
          (start: 0, end: 0.5, word: 'a', voice: 'lead', section: 'verse'),
          (start: 1, end: 1.5, word: 'b', voice: 'lead', section: 'verse'),
          (start: 2, end: 2.5, word: 'c', voice: 'lead', section: 'chorus'),
        ],
        10,
      );
      expect(spans, [
        (start: 0.0, end: 2.0, section: 'verse'),
        (start: 2.0, end: 10.0, section: 'chorus'),
      ]);
    });

    test('no words → no spans', () {
      expect(buildDanceSectionSpans(const [], 10), isEmpty);
    });
  });

  group('danceSectionDisplayName', () {
    test('maps known tags and title-cases the rest', () {
      expect(danceSectionDisplayName('pre-chorus'), 'Pre');
      expect(danceSectionDisplayName('post-chorus'), 'Post');
      expect(danceSectionDisplayName('chorus'), 'Chorus');
      expect(danceSectionDisplayName(''), '—');
      expect(danceSectionDisplayName('hook'), 'Hook');
    });
  });

  group('easeDanceMouth', () {
    test('attack reaches the target faster than release for the same dt', () {
      final opening = easeDanceMouth(0, 1, 0.06);
      final closing = easeDanceMouth(1, 0, 0.06);
      expect(opening, 1.0, reason: 'fast attack fully opens in one 60ms step');
      expect(closing, closeTo(0.5, 1e-9), reason: 'slow release lags');
      expect(opening, greaterThan(1 - closing));
    });

    test('never overshoots the target', () {
      expect(easeDanceMouth(0, 1, 10), 1.0);
      expect(easeDanceMouth(1, 0, 10), 0.0);
    });
  });

  group('danceIdleStage', () {
    test('rests all three cats on the idle clip at raw playback time', () {
      final stage = danceIdleStage(4.2);
      expect(stage.lead.name, 'idle');
      expect(stage.ensemble.map((c) => c.name), everyElement('idle'));
      expect(stage.seconds, 4.2);
      expect(stage.energetic, isFalse);
      expect(stage.synchronous, isTrue);
    });
  });

  group('DancePerformance.sectionAt', () {
    test('returns the covering section, or the last past the end', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 3, label: 'A', energetic: true, level: 1),
          (start: 3, end: 6, label: 'B', energetic: true, level: 1),
        ],
      );
      expect(perf.sectionAt(1)?.label, 'A');
      expect(perf.sectionAt(4)?.label, 'B');
      expect(perf.sectionAt(99)?.label, 'B', reason: 'clamps to last');
    });

    test('empty sections → null', () {
      expect(_perf().sectionAt(1), isNull);
    });
  });

  group('DancePerformance.sectionInfoAt / occurrence', () {
    final perf = _perf(
      spans: const [
        (start: 0, end: 2, section: 'verse'),
        (start: 2, end: 4, section: 'chorus'),
        (start: 4, end: 6, section: 'verse'),
      ],
    );

    test('reports the section label and 0..1 phase within the span', () {
      final info = perf.sectionInfoAt(3); // mid chorus span [2,4]
      expect(info.section, 'chorus');
      expect(info.phase, closeTo(0.5, 1e-9));
    });

    test('counts earlier same-label spans as the occurrence index', () {
      expect(perf.sectionOccurrenceAt(1, 'verse'), 0);
      expect(perf.sectionOccurrenceAt(5, 'verse'), 1, reason: '2nd verse');
    });
  });

  group('DancePerformance.choreoTrioForSection', () {
    // The dance-move getters recompile a fresh Clip with no value equality, so
    // assertions compare the stable `name` rather than instance identity.
    final perf = _perf();

    test('the chorus back half lands the unison Buga hit', () {
      final trio = perf.choreoTrioForSection('chorus', 0.6, 0.5, 0);
      expect(trio.lead.name, 'buga');
      expect(trio.ensemble.map((c) => c.name), everyElement('buga'));
    });

    test('the chorus front half rotates its lead by occurrence', () {
      expect(
        perf.choreoTrioForSection('chorus', 0.2, 0.5, 0).lead.name,
        'zanku',
      );
      expect(
        perf.choreoTrioForSection('chorus', 0.2, 0.5, 1).lead.name,
        'sekem',
      );
    });

    test('verses swap the lead on even/odd occurrence', () {
      expect(perf.choreoTrioForSection('verse', 0, 0.5, 0).lead.name, 'azonto');
      expect(perf.choreoTrioForSection('verse', 0, 0.5, 1).lead.name, 'shaku');
    });

    test('the bridge drops the whole trio to the Pouncing-Cat glide', () {
      final trio = perf.choreoTrioForSection('bridge', 0.5, 0.5, 0);
      expect(trio.lead.name, 'pouncingCat');
      expect(trio.ensemble.map((c) => c.name), everyElement('pouncingCat'));
    });

    test('untagged sections fall back to the energy-level map', () {
      expect(perf.choreoTrioForSection('', 0, 0.95, 0).lead.name, 'buga');
      expect(
        perf.choreoTrioForSection('', 0, 0.10, 0).lead.name,
        'pouncingCat',
      );
    });
  });

  group('DancePerformance.choreoTrioByLevel', () {
    final perf = _perf();
    test('builds from the glide up to the unison Buga hit by energy', () {
      expect(perf.choreoTrioByLevel(0.95).lead.name, 'buga');
      expect(perf.choreoTrioByLevel(0.80).lead.name, 'zanku');
      expect(perf.choreoTrioByLevel(0.50).lead.name, 'shaku');
      expect(perf.choreoTrioByLevel(0.30).lead.name, 'azonto');
      expect(perf.choreoTrioByLevel(0.05).lead.name, 'pouncingCat');
    });
  });

  group('DancePerformance.stageAt', () {
    test('an energetic section dances with a finite warped clock', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: true, level: 1),
        ],
      );
      final stage = perf.stageAt(2);
      expect(stage.lead.name, 'buga', reason: 'level 1 → Buga');
      expect(stage.energetic, isTrue);
      expect(stage.synchronous, isTrue);
      expect(stage.seconds.isFinite, isTrue);
      expect(stage.seconds, isNonNegative);
    });

    test('a dead-quiet calm section rests on idle at raw time', () {
      final perf = _perf(
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: false, level: 0.1),
        ],
      );
      final stage = perf.stageAt(2.5);
      expect(stage.lead.name, 'idle');
      expect(stage.seconds, 2.5, reason: 'idle runs on raw playback time');
    });

    test('the Pouncing-Cat glide dances in canon (not unison)', () {
      final perf = _perf(
        spans: const [(start: 0, end: 6, section: 'bridge')],
        sections: const [
          (start: 0, end: 6, label: 'A', energetic: true, level: 0.5),
        ],
      );
      expect(perf.stageAt(2).synchronous, isFalse);
    });
  });

  group('DancePerformance.beatPulse', () {
    final perf = _perf();
    test('spikes to 1 on a beat and decays to 0 within ~180 ms', () {
      expect(perf.beatPulse(0.5), 1.0, reason: 'exactly on beat 1');
      expect(perf.beatPulse(0.5 + 0.09), closeTo(0.25, 1e-6));
      expect(perf.beatPulse(0.5 + 0.2), 0.0, reason: 'fully decayed');
    });
  });

  group('DancePerformance.voiceActive', () {
    final perf = _perf(
      words: const [
        (start: 1, end: 1.5, word: 'hey', voice: 'lead', section: 'verse'),
      ],
    );
    test('true inside a word window (dilated by the slack), else false', () {
      expect(perf.voiceActive(1.2, (w) => w.voice == 'lead'), isTrue);
      expect(
        perf.voiceActive(1.7, (w) => w.voice == 'lead'),
        isTrue,
        reason: 'within slack past the word end',
      );
      expect(perf.voiceActive(3, (w) => w.voice == 'lead'), isFalse);
      expect(perf.voiceActive(1.2, (w) => w.voice == 'background'), isFalse);
    });
  });
}
