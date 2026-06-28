import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/drone_show_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

void main() {
  group('droneShowTimelineAt', () {
    test('uses a physically slow cycle for aircraft-scale motion', () {
      expect(kDroneShowCycleSeconds, greaterThanOrEqualTo(120));
    });

    test('resolves launch, beam, fan, and formation phases', () {
      expect(droneShowTimelineAt(0).phase, DroneShowPhase.launch);
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.50).phase,
        DroneShowPhase.beam,
      );
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.65).phase,
        DroneShowPhase.fan,
      );
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.86).phase,
        DroneShowPhase.formation,
      );
    });

    test('keeps phase progress in bounds and wraps deterministically', () {
      for (final t in const [-10.0, 0.0, 2.5, 8.2, 15.9, 36.2]) {
        final timeline = droneShowTimelineAt(t);
        expect(timeline.progress, inInclusiveRange(0, 1), reason: '$t');
        expect(timeline.cycleProgress, inInclusiveRange(0, 1), reason: '$t');
      }

      final a = droneShowTimelineAt(3.25);
      final b = droneShowTimelineAt(3.25 + kDroneShowCycleSeconds);
      expect(b.phase, a.phase);
      expect(b.progress, closeTo(a.progress, 1e-12));
      expect(b.cycleProgress, closeTo(a.cycleProgress, 1e-12));
    });
  });

  group('droneShowFormationPoints', () {
    test('uses the exact final label', () {
      expect(kDroneShowFinalText, 'Omah Lay');
      expect(kDroneShowDroneCount, greaterThanOrEqualTo(200));
    });

    test('generates the requested number of normalized text points', () {
      final points = droneShowFormationPoints(count: 64);

      expect(points, hasLength(64));
      for (final point in points) {
        expect(point.dx, inInclusiveRange(0, 1));
        expect(point.dy, inInclusiveRange(0, 1));
      }
    });

    test('lays out a modest sky text formation', () {
      final points = droneShowFormationPoints();
      final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

      expect(minX, greaterThanOrEqualTo(0.15));
      expect(maxX, lessThanOrEqualTo(0.85));
      expect(minY, greaterThanOrEqualTo(0.14));
      expect(maxY, lessThanOrEqualTo(0.34));
      expect(maxX - minX, greaterThan(0.58));
    });
  });

  group('sampleDroneShow', () {
    test('is deterministic for the same time', () {
      final a = sampleDroneShow(7.125, count: 48);
      final b = sampleDroneShow(7.125, count: 48);

      expect(a, hasLength(b.length));
      for (var i = 0; i < a.length; i++) {
        expect(a[i].phase, b[i].phase);
        expect(a[i].position.dx, closeTo(b[i].position.dx, 1e-12));
        expect(a[i].position.dy, closeTo(b[i].position.dy, 1e-12));
        expect(a[i].opacity, closeTo(b[i].opacity, 1e-12));
        expect(a[i].radius, closeTo(b[i].radius, 1e-12));
      }
    });

    test('starts all along the cable-stayed bridge deck', () {
      final samples = sampleDroneShow(0, count: 80);
      final minX = samples
          .map((s) => s.position.dx)
          .reduce((a, b) => a < b ? a : b);
      final maxX = samples
          .map((s) => s.position.dx)
          .reduce((a, b) => a > b ? a : b);
      final minY = samples
          .map((s) => s.position.dy)
          .reduce((a, b) => a < b ? a : b);
      final maxY = samples
          .map((s) => s.position.dy)
          .reduce((a, b) => a > b ? a : b);

      expect(minX, greaterThanOrEqualTo(0.47));
      expect(maxX, lessThanOrEqualTo(0.76));
      expect(maxX - minX, greaterThan(0.24));
      expect(minY, greaterThanOrEqualTo(0.49));
      expect(maxY, lessThanOrEqualTo(0.52));
    });

    test('settles into text early and holds the formation', () {
      final settled = sampleDroneShow(kDroneShowCycleSeconds * 0.78, count: 80);
      final held = sampleDroneShow(kDroneShowCycleSeconds * 0.95, count: 80);

      expect(
        settled.map((s) => s.phase),
        everyElement(DroneShowPhase.formation),
      );
      for (var i = 0; i < settled.length; i++) {
        expect(settled[i].position.dx, closeTo(held[i].position.dx, 1e-12));
        expect(settled[i].position.dy, closeTo(held[i].position.dy, 1e-12));
      }
    });

    test('reduced motion returns a static formation frame', () {
      final a = sampleDroneShow(1, reducedMotion: true, count: 40);
      final b = sampleDroneShow(99, reducedMotion: true, count: 40);

      expect(a.map((s) => s.phase), everyElement(DroneShowPhase.formation));
      for (var i = 0; i < a.length; i++) {
        expect(a[i].position.dx, closeTo(b[i].position.dx, 1e-12));
        expect(a[i].position.dy, closeTo(b[i].position.dy, 1e-12));
        expect(a[i].opacity, closeTo(b[i].opacity, 1e-12));
      }
    });

    test('reduced motion respects custom cycle lengths', () {
      final samples = sampleDroneShow(
        1,
        reducedMotion: true,
        count: 12,
        cycleSeconds: 6,
      );

      expect(
        samples.map((s) => s.phase),
        everyElement(DroneShowPhase.formation),
      );
    });

    test('keeps sampled drones in basic sky bounds', () {
      for (final time in const [0.0, 2.0, 5.5, 9.5, 14.5, 17.5]) {
        final samples = sampleDroneShow(time, count: 80);
        expect(samples, hasLength(80));
        for (final sample in samples) {
          expect(sample.position.dx, inInclusiveRange(0.15, 0.85));
          expect(sample.position.dy, inInclusiveRange(0.10, 0.65));
          expect(sample.opacity, inInclusiveRange(0, 1));
          expect(sample.radius, inInclusiveRange(0.0015, 0.0035));
        }
      }
    });
  });

  group('DroneShowLayer.paint', () {
    test('does not throw and uses the BackdropLayer contract', () {
      const layer = DroneShowLayer(droneCount: 16);
      const asLayer = layer as BackdropLayer;
      final recorder = ui.PictureRecorder();

      expect(
        () => asLayer.paint(
          ui.Canvas(recorder),
          const BackdropContext(
            size: ui.Size(320, 180),
            timeSeconds: 8,
            palette: kBlueHourPalette,
          ),
        ),
        returnsNormally,
      );
      recorder.endRecording().dispose();
    });
  });
}
