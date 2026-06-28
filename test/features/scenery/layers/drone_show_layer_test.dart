import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/scenery/layers/backdrop_layer.dart';
import 'package:lotti/features/scenery/layers/drone_show_layer.dart';
import 'package:lotti/features/scenery/model/backdrop_palette.dart';

void main() {
  group('droneShowTimelineAt', () {
    test('uses a physically slow cycle for aircraft-scale motion', () {
      expect(kDroneShowCycleSeconds, inInclusiveRange(130, 150));
    });

    test('resolves launch, beam, fan, and formation phases', () {
      expect(droneShowTimelineAt(0).phase, DroneShowPhase.launch);
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.26).phase,
        DroneShowPhase.beam,
      );
      expect(
        droneShowTimelineAt(kDroneShowCycleSeconds * 0.46).phase,
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
      expect(kDroneShowOpeningText, 'Omah Lay');
      expect(kDroneShowFinalText, 'Moving');
      expect(kDroneShowDroneCount, greaterThanOrEqualTo(260));
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

      expect(minX, greaterThanOrEqualTo(0.34));
      expect(maxX, lessThanOrEqualTo(0.66));
      expect(minY, greaterThanOrEqualTo(0.20));
      expect(maxY, lessThanOrEqualTo(0.30));
      expect(maxX - minX, inInclusiveRange(0.25, 0.33));
    });

    test('can lay out the final Moving message', () {
      final points = droneShowFormationPoints(
        text: kDroneShowFinalText,
      );
      final minX = points.map((p) => p.dx).reduce((a, b) => a < b ? a : b);
      final maxX = points.map((p) => p.dx).reduce((a, b) => a > b ? a : b);
      final minY = points.map((p) => p.dy).reduce((a, b) => a < b ? a : b);
      final maxY = points.map((p) => p.dy).reduce((a, b) => a > b ? a : b);

      expect(points, hasLength(kDroneShowDroneCount));
      expect(minX, greaterThanOrEqualTo(0.34));
      expect(maxX, lessThanOrEqualTo(0.66));
      expect(minY, greaterThanOrEqualTo(0.20));
      expect(maxY, lessThanOrEqualTo(0.30));
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

    test('starts evenly along the cable-stayed bridge road', () {
      final samples = sampleDroneShow(0, count: 80);
      final xs = samples.map((s) => s.position.dx).toList();
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

      expect(minX, greaterThanOrEqualTo(0.44));
      expect(maxX, lessThanOrEqualTo(0.691));
      expect(maxX - minX, inInclusiveRange(0.21, 0.23));
      final step = xs[1] - xs[0];
      for (var i = 2; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], closeTo(step, 1e-12));
      }
      expect(minY, greaterThanOrEqualTo(0.472));
      expect(maxY, lessThanOrEqualTo(0.48));
      for (final sample in samples) {
        expect(sample.opacity, closeTo(0.86, 1e-12));
        expect(sample.radius, closeTo(0.00255, 1e-12));
      }
    });

    test('uses a dense default launch row without visible spacing gaps', () {
      final samples = sampleDroneShow(0);
      final xs = samples.map((s) => s.position.dx).toList();

      final step = xs[1] - xs[0];
      expect(step, lessThan(0.001));
      for (var i = 2; i < xs.length; i++) {
        expect(xs[i] - xs[i - 1], closeTo(step, 1e-12));
      }
    });

    test('rises vertically before converging into the beam', () {
      final start = sampleDroneShow(0, count: 40);
      final rising = sampleDroneShow(
        kDroneShowCycleSeconds * 0.15,
        count: 40,
      );

      for (var i = 0; i < start.length; i++) {
        expect(rising[i].phase, DroneShowPhase.launch);
        expect(rising[i].position.dx, closeTo(start[i].position.dx, 1e-12));
        expect(rising[i].position.dy, lessThan(start[i].position.dy));
      }
    });

    test('shows Omah Lay first, then Moving', () {
      final opening = sampleDroneShow(kDroneShowCycleSeconds * 0.68, count: 80);
      final openingTarget = droneShowFormationPoints(count: 80);
      final finalText = sampleDroneShow(
        kDroneShowCycleSeconds * 0.9,
        count: 80,
      );
      final finalTarget = droneShowFormationPoints(
        count: 80,
        text: kDroneShowFinalText,
      );

      for (var i = 0; i < opening.length; i++) {
        expect(opening[i].position.dx, closeTo(openingTarget[i].dx, 1e-12));
        expect(opening[i].position.dy, closeTo(openingTarget[i].dy, 1e-12));
        expect(finalText[i].position.dx, closeTo(finalTarget[i].dx, 1e-12));
        expect(finalText[i].position.dy, closeTo(finalTarget[i].dy, 1e-12));
      }
    });

    test('uses a coordinated staging line between text messages', () {
      final midTransition = sampleDroneShow(
        kDroneShowCycleSeconds * 0.83,
        count: 80,
      );
      final minY = midTransition
          .map((s) => s.position.dy)
          .reduce((a, b) => a < b ? a : b);
      final maxY = midTransition
          .map((s) => s.position.dy)
          .reduce((a, b) => a > b ? a : b);

      expect(
        midTransition.map((s) => s.phase),
        everyElement(DroneShowPhase.formation),
      );
      expect(maxY - minY, lessThan(0.03));
    });

    test('limits one-second travel so drones do not read as particles', () {
      const maxNormalizedStepPerSecond = 0.018;

      for (var t = 0.0; t < kDroneShowCycleSeconds - 1; t += 1) {
        final a = sampleDroneShow(t, count: 80);
        final b = sampleDroneShow(t + 1, count: 80);

        for (var i = 0; i < a.length; i++) {
          final dx = b[i].position.dx - a[i].position.dx;
          final dy = b[i].position.dy - a[i].position.dy;
          final distance = math.sqrt(dx * dx + dy * dy);
          expect(
            distance,
            lessThanOrEqualTo(maxNormalizedStepPerSecond),
            reason: 'drone $i at t=$t',
          );
        }
      }
    });

    test('settles into final text and holds the formation', () {
      final settled = sampleDroneShow(kDroneShowCycleSeconds * 0.9, count: 80);
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
      final finalTarget = droneShowFormationPoints(
        count: 40,
        text: kDroneShowFinalText,
      );
      for (var i = 0; i < a.length; i++) {
        expect(a[i].position.dx, closeTo(b[i].position.dx, 1e-12));
        expect(a[i].position.dy, closeTo(b[i].position.dy, 1e-12));
        expect(a[i].position.dx, closeTo(finalTarget[i].dx, 1e-12));
        expect(a[i].position.dy, closeTo(finalTarget[i].dy, 1e-12));
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
    test('can split launch-road and sky phases for scene compositing', () {
      const launchLayer = DroneShowLayer.launchRoad();
      const skyLayer = DroneShowLayer.sky();

      expect(launchLayer.visiblePhases, {DroneShowPhase.launch});
      expect(skyLayer.visiblePhases, isNot(contains(DroneShowPhase.launch)));
      expect(skyLayer.visiblePhases, contains(DroneShowPhase.beam));
      expect(skyLayer.visiblePhases, contains(DroneShowPhase.fan));
      expect(skyLayer.visiblePhases, contains(DroneShowPhase.formation));
    });

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
