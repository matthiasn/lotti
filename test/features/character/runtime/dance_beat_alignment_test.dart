import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/runtime/character_scene.dart';
import 'package:lotti/features/character/runtime/temporal_motion_analyzer.dart';
import 'package:lotti/features/character/samples/cat_in_suit.dart';

/// Beat Alignment Score (BAS, after AIST++): does the authored dance land its
/// motion accents on the beat grid? "Motion beats" are local minima of the
/// extremities' speed — the instants the body decelerates/reverses on a hit;
/// "music beats" are the 12 beats of the authored phrase (3 bars of 4/4 at
/// 120 BPM). The warp (`BeatMap.clipSecondsAt`) then maps this grid onto any
/// track's detected beats, so on-grid authoring == on-beat playback.
void main() {
  test('dance lands its motion hits on the beat grid (BAS)', () {
    const samples = 192; // 16 per beat across the 12-beat phrase
    const beats = 12;

    final report = TemporalMotionAnalyzer(CharacterScene(buildCatInSuitRig()))
        .analyze(
          clip: CatClips.dance,
          samples: samples,
          boneIds: const [
            CatBones.head,
            CatBones.handL,
            CatBones.handR,
            CatBones.footL,
            CatBones.footR,
          ],
        );

    // Per-frame global speed = summed extremity displacement over that frame.
    final speed = List<double>.filled(samples + 1, 0);
    for (final seg in report.segments) {
      speed[seg.toFrame] += seg.distance;
    }
    final series = speed.sublist(1); // frames 1..samples
    final mean = series.reduce((a, b) => a + b) / series.length;

    // Motion beats = local minima below the mean (the body's "hits"), as phases.
    final motionPhases = <double>[];
    for (var i = 1; i < series.length - 1; i++) {
      if (series[i] < mean &&
          series[i] <= series[i - 1] &&
          series[i] <= series[i + 1]) {
        motionPhases.add((i + 1) / samples);
      }
    }

    // Circular distance on the looping phase [0, 1).
    double circDist(double a, double b) {
      final d = (a - b).abs() % 1.0;
      return d > 0.5 ? 1.0 - d : d;
    }

    // BAS: each music beat scored by its nearest motion beat, gaussian-weighted
    // (sigma = half a beat in phase units).
    const sigma = 0.5 / beats;
    var bas = 0.0;
    for (var k = 0; k < beats; k++) {
      final beatPhase = k / beats;
      var nearest = double.infinity;
      for (final mp in motionPhases) {
        nearest = math.min(nearest, circDist(beatPhase, mp));
      }
      if (nearest.isFinite) {
        bas += math.exp(-(nearest * nearest) / (2 * sigma * sigma));
      }
    }
    bas /= beats;

    // ignore: avoid_print
    print(
      'Dance BAS = ${bas.toStringAsFixed(3)}  '
      '(${motionPhases.length} motion beats vs $beats music beats)',
    );

    expect(
      motionPhases.length,
      greaterThanOrEqualTo(beats ~/ 2),
      reason: 'the dance should accent several beats per phrase',
    );
    expect(
      bas,
      greaterThan(0.3),
      reason: 'motion hits should cluster near the beat grid (BAS=$bas)',
    );
  });
}
