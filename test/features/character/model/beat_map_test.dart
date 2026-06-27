import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/character/model/beat_map.dart';

/// One round-trip case: a strictly-increasing beat grid (built from positive
/// inter-beat intervals so it is always valid) and a sample time inside it.
typedef _BeatCase = ({List<double> beats, double t});

extension _AnyBeatCase on glados.Any {
  glados.Generator<_BeatCase> get beatCase =>
      combine4<double, double, double, double, _BeatCase>(
        glados.DoubleAnys(this).doubleInRange(0.25, 1.2),
        glados.DoubleAnys(this).doubleInRange(0.25, 1.2),
        glados.DoubleAnys(this).doubleInRange(0.25, 1.2),
        glados.DoubleAnys(this).doubleInRange(0, 1),
        (i0, i1, i2, u) {
          final beats = <double>[0, i0, i0 + i1, i0 + i1 + i2];
          return (beats: beats, t: u * beats.last);
        },
      );
}

void main() {
  // A clean 120 BPM grid (one beat every 0.5 s) with bar downbeats every 4 beats.
  BeatMap steady() => BeatMap(
    beatTimesSec: const [0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0],
    downbeatIndices: const [0, 4, 8],
  );

  group('BeatMap.beatAt / timeAtBeat', () {
    test('maps wall-clock time to fractional beat index on a steady grid', () {
      final map = steady();
      expect(map.beatAt(0), closeTo(0, 1e-9));
      expect(map.beatAt(0.5), closeTo(1, 1e-9));
      expect(map.beatAt(0.75), closeTo(1.5, 1e-9));
      expect(map.beatAt(2), closeTo(4, 1e-9));
    });

    test('extrapolates past both ends with the edge inter-beat interval', () {
      final map = steady();
      // 0.25 s before beat 0 is half a beat early; 0.5 s after the last beat is
      // one beat later (index 8 -> 9).
      expect(map.beatAt(-0.25), closeTo(-0.5, 1e-9));
      expect(map.beatAt(4.5), closeTo(9, 1e-9));
      expect(map.timeAtBeat(9), closeTo(4.5, 1e-9));
      expect(map.timeAtBeat(-0.5), closeTo(-0.25, 1e-9));
    });

    test('round-trips through a variable-tempo grid', () {
      final map = BeatMap(
        beatTimesSec: const [0, 0.5, 1.1, 1.5, 2.4],
        downbeatIndices: const [0, 4],
      );
      for (final t in const [0.2, 0.5, 0.9, 1.3, 2.0, 2.4]) {
        expect(map.timeAtBeat(map.beatAt(t)), closeTo(t, 1e-9), reason: 't=$t');
      }
    });
  });

  group('BeatMap.clipSecondsAt', () {
    test('on a steady grid it matches constant-tempo loop phase', () {
      final map = steady();
      // 4-beat loop at 0.5 s/beat = a 2.0 s loop; clip authored over 2.0 s, so
      // clip-seconds == (t mod 2.0).
      const binding = BeatLoopBinding(loopLengthBeats: 4, anchorBeatIndex: 0);
      double cs(double t) =>
          map.clipSecondsAt(t, clipDuration: 2, binding: binding);
      expect(cs(0), closeTo(0, 1e-9));
      expect(cs(0.75), closeTo(0.75, 1e-9));
      expect(cs(2), closeTo(0, 1e-9)); // loop seam wraps back to frame 0
      expect(cs(2.3), closeTo(0.3, 1e-9));
    });

    test('a different clipDuration rescales the loop phase', () {
      final map = steady();
      const binding = BeatLoopBinding(loopLengthBeats: 4, anchorBeatIndex: 0);
      // Halfway through the 4-beat loop maps to halfway through any clipDuration.
      expect(
        map.clipSecondsAt(1, clipDuration: 6, binding: binding),
        closeTo(3.0, 1e-9),
      );
    });
  });

  group('BeatLoopBinding', () {
    test('barAligned spans whole bars and anchors on a real downbeat', () {
      final map = steady();
      final bar0 = BeatLoopBinding.barAligned(map, bars: 1);
      expect(bar0.loopLengthBeats, 4); // 1 bar * numerator 4
      expect(bar0.anchorBeatIndex, 0); // first downbeat

      final bar1 = BeatLoopBinding.barAligned(map, bars: 1, fromDownbeat: 1);
      expect(bar1.anchorBeatIndex, 4); // second downbeat (index into beats)

      // The phrase's frame 0 lands exactly on that downbeat's time (2.0 s).
      expect(
        map.clipSecondsAt(2, clipDuration: 2, binding: bar1),
        closeTo(0, 1e-9),
      );
    });

    test('barAligned degrades to a beat-0 anchor when no downbeats exist', () {
      final map = BeatMap(
        beatTimesSec: const [0, 0.5, 1.0, 1.5, 2.0],
        downbeatIndices: const [],
      );
      final b = BeatLoopBinding.barAligned(map, bars: 2);
      expect(b.anchorBeatIndex, 0);
      expect(b.loopLengthBeats, 8); // 2 bars * numerator 4
    });

    test('beatAligned keeps the requested beat anchor and length', () {
      final b = BeatLoopBinding.beatAligned(
        loopLengthBeats: 12,
        anchorBeatIndex: 3,
      );
      expect(b.loopLengthBeats, 12);
      expect(b.anchorBeatIndex, 3);
    });
  });

  group('BeatMap.fromJson', () {
    test('parses beats, downbeat indices, and the time signature', () {
      final map = BeatMap.fromJson(const {
        'beats': [
          {'index': 0, 'time_sec': 0.0, 'is_downbeat': true},
          {'index': 1, 'time_sec': 0.5, 'is_downbeat': false},
          {'index': 2, 'time_sec': 1.0, 'is_downbeat': false},
          {'index': 3, 'time_sec': 1.5, 'is_downbeat': false},
          {'index': 4, 'time_sec': 2.0, 'is_downbeat': true},
        ],
        'time_signature': {'numerator': 4, 'denominator': 4},
      });
      expect(map.beatTimesSec, const [0, 0.5, 1.0, 1.5, 2.0]);
      expect(map.downbeatIndices, const [0, 4]);
      expect(map.timeSignatureNumerator, 4);
      // And the parsed map drives a sane bar-aligned binding.
      final binding = BeatLoopBinding.barAligned(map, bars: 1);
      expect(binding.anchorBeatIndex, 0);
      expect(binding.loopLengthBeats, 4);
    });

    test('throws when there are fewer than two beats', () {
      expect(
        () => BeatMap.fromJson(const {
          'beats': [
            {'index': 0, 'time_sec': 0.0, 'is_downbeat': true},
          ],
        }),
        throwsFormatException,
      );
    });
  });

  // Property: warping time to a beat index and back is the identity inside the
  // detected range, for any (positive-interval) grid and any sample time. This
  // is the invariant the on-beat warp relies on — it must hold exactly, not just
  // for the hand-picked grids above.
  glados.Glados<_BeatCase>(
    glados.any.beatCase,
    glados.ExploreConfig(numRuns: 200),
  ).test('timeAtBeat(beatAt(t)) round-trips for arbitrary grids', (c) {
    final map = BeatMap(beatTimesSec: c.beats, downbeatIndices: const [0]);
    expect(
      map.timeAtBeat(map.beatAt(c.t)),
      closeTo(c.t, 1e-6),
      reason: 'beats=${c.beats} t=${c.t}',
    );
  }, tags: 'glados');
}
