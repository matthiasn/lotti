import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/state/vu_meter.dart';

void main() {
  // Production wiring: 300 ms window / 20 ms sample interval = 15 samples.
  const productionWindow = defaultVuWindowMs ~/ 20;

  group('VuMeter.addSample', () {
    test('a silence-only window clamps to the -20 VU floor', () {
      final meter = VuMeter(windowSamples: productionWindow);
      double? vu;
      for (var i = 0; i < 20; i++) {
        vu = meter.addSample(-160);
      }
      expect(vu, -20.0);
    });

    test('a 0 dBFS-only window clamps to the +3 VU ceiling', () {
      // RMS of a constant 0 dBFS is 0 dB; +18 VU above the reference saturates
      // the meter, so the reading clamps to its +3 ceiling.
      final meter = VuMeter(windowSamples: productionWindow);
      double? vu;
      for (var i = 0; i < 20; i++) {
        vu = meter.addSample(0);
      }
      expect(vu, 3.0);
    });

    test('a constant -50 dBFS resolves below the floor and clamps to -20', () {
      // VU = RMS_dB - referenceDbfs = -50 - (-18) = -32 → clamped to -20.
      final meter = VuMeter(windowSamples: productionWindow);
      double? vu;
      for (var i = 0; i < 20; i++) {
        vu = meter.addSample(-50);
      }
      expect(vu, -20.0);
    });

    test('a louder sample raises the reading above a quieter one', () {
      // -30 dBFS → VU -12; -36 dBFS → VU -18: the louder level reads higher and
      // both sit inside the unclamped band, proving the mapping is monotonic.
      final loud = VuMeter(windowSamples: productionWindow);
      final quiet = VuMeter(windowSamples: productionWindow);
      late double loudVu;
      late double quietVu;
      for (var i = 0; i < productionWindow; i++) {
        loudVu = loud.addSample(-30);
        quietVu = quiet.addSample(-36);
      }
      expect(loudVu, greaterThan(quietVu));
      expect(loudVu, closeTo(-12, 0.001));
      expect(quietVu, closeTo(-18, 0.001));
    });

    test('old samples fall out of the sliding window', () {
      // Saturate the window at 0 dBFS (reads +3), then push in a full window of
      // silence: the loud samples are fully evicted and the reading collapses
      // to the floor.
      final meter = VuMeter(windowSamples: 4);
      for (var i = 0; i < 4; i++) {
        meter.addSample(0);
      }
      expect(meter.addSample(0), 3.0);
      double? vu;
      for (var i = 0; i < 4; i++) {
        vu = meter.addSample(-160);
      }
      expect(vu, -20.0);
    });

    test('reset() empties the window so loud history does not linger', () {
      final meter = VuMeter(windowSamples: productionWindow);
      for (var i = 0; i < productionWindow; i++) {
        meter.addSample(0);
      }
      meter.reset();
      // First sample after reset is the only one in the window.
      expect(meter.addSample(-160), -20.0);
    });

    test('referenceDbfs shifts the 0 VU point', () {
      // With reference 0 dBFS, a constant 0 dBFS sits exactly at 0 VU.
      final meter = VuMeter(windowSamples: productionWindow, referenceDbfs: 0);
      double? vu;
      for (var i = 0; i < productionWindow; i++) {
        vu = meter.addSample(0);
      }
      expect(vu, closeTo(0, 0.001));
    });
  });

  glados.Glados<List<int>>(
    glados.ListAnys(glados.any).listWithLengthInRange(
      1,
      25,
      glados.IntAnys(glados.any).intInRange(0, 160),
    ),
    glados.ExploreConfig(numRuns: 120),
  ).test(
    'every output stays clamped to [-20, 3] for any dBFS sequence',
    (seeds) {
      final meter = VuMeter(windowSamples: productionWindow);
      for (final seed in seeds) {
        final vu = meter.addSample(-seed.toDouble());
        expect(vu, greaterThanOrEqualTo(-20.0), reason: 'dBFS=-$seed');
        expect(vu, lessThanOrEqualTo(3.0), reason: 'dBFS=-$seed');
      }
    },
    tags: 'glados',
  );
}
