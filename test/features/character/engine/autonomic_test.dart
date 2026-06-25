import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/engine/autonomic.dart';

void main() {
  group('AutonomicLayer', () {
    test('is deterministic for a given seed', () {
      final a = AutonomicLayer(seed: 42);
      final b = AutonomicLayer(seed: 42);
      for (final t in <double>[0, 0.4, 1.3, 2.7, 5.1]) {
        expect(a.sampleAt(t).eyeOpen, b.sampleAt(t).eyeOpen);
        expect(a.sampleAt(t).eyeDartX, b.sampleAt(t).eyeDartX);
        expect(a.sampleAt(t).breath, b.sampleAt(t).breath);
      }
    });

    test('different seeds diverge', () {
      final a = AutonomicLayer(seed: 7);
      final b = AutonomicLayer(seed: 2);
      // Compare blink schedules over a window; they should not be identical.
      final sameEverywhere = List.generate(50, (i) => i * 0.2).every(
        (t) => a.sampleAt(t).eyeOpen == b.sampleAt(t).eyeOpen,
      );
      expect(sameEverywhere, isFalse);
    });

    test('different seeds start their blink schedules independently', () {
      final a = AutonomicLayer(
        seed: 11,
        blinkIntervalBase: 1.7,
        blinkIntervalJitter: 1.1,
      );
      final b = AutonomicLayer(
        seed: 29,
        blinkIntervalBase: 1.7,
        blinkIntervalJitter: 1.1,
      );

      final divergedEarly = List.generate(40, (i) => i * 0.05).any(
        (t) => a.sampleAt(t).eyeOpen != b.sampleAt(t).eyeOpen,
      );
      expect(divergedEarly, isTrue);
    });

    test('eyeOpen stays within 0..1 and starts open', () {
      final layer = AutonomicLayer();
      expect(layer.sampleAt(0).eyeOpen, 1);
      for (var i = 0; i < 400; i++) {
        final v = layer.sampleAt(i * 0.05).eyeOpen;
        expect(v, inInclusiveRange(0, 1));
      }
    });

    test('at least one full blink occurs over a 30s window', () {
      final layer = AutonomicLayer();
      var minOpen = 1.0;
      for (var i = 0; i < 600; i++) {
        final v = layer.sampleAt(i * 0.05).eyeOpen;
        if (v < minOpen) minOpen = v;
      }
      expect(minOpen, lessThan(0.1), reason: 'eyelids should fully close');
    });

    test('resumed cursor matches a cold walk (forward and backward)', () {
      final warm = AutonomicLayer();
      // Warm the internal cursor with a monotonic forward sweep.
      for (var i = 0; i < 500; i++) {
        warm.sampleAt(i * 0.3);
      }
      final cold = AutonomicLayer();
      // Forward beyond the warmed range resumes; a backward seek restarts.
      // Either way the value must equal a from-scratch walk (pure in t).
      for (final t in <double>[0, 7.3, 51.2, 149.9, 500]) {
        expect(warm.sampleAt(t).eyeOpen, cold.sampleAt(t).eyeOpen);
      }
    });

    test('keeps blinking far into the future (no silent stop near old cap)', () {
      // ~83h in — past where the previous fixed 100k-iteration walk would have
      // silently stopped blinking.
      final layer = AutonomicLayer();
      var minOpen = 1.0;
      for (var i = 0; i < 6000; i++) {
        final v = layer.sampleAt(300000 + i * 0.005).eyeOpen;
        if (v < minOpen) minOpen = v;
      }
      expect(
        minOpen,
        lessThan(0.1),
        reason: 'eyelids should still fully close',
      );
    });

    test('breath oscillates within its amplitude', () {
      final layer = AutonomicLayer(breathAmplitude: 2);
      for (var i = 0; i < 200; i++) {
        final v = layer.sampleAt(i * 0.1).breath;
        expect(v, inInclusiveRange(-2.0001, 2.0001));
      }
    });

    test('eye-darts stay within their amplitude', () {
      final layer = AutonomicLayer(); // default eye-dart amplitude is 0.5
      for (var i = 0; i < 200; i++) {
        final s = layer.sampleAt(i * 0.1);
        expect(s.eyeDartX.abs(), lessThanOrEqualTo(0.5001));
        expect(s.eyeDartY.abs(), lessThanOrEqualTo(0.5001));
      }
    });
  });
}
