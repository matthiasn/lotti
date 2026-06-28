import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/character/model/dance_dynamics.dart';
import 'package:lotti/features/character/model/easing.dart';

void main() {
  List<double> sample(EaseCurve f, {int n = 100}) => [
    for (var i = 0; i <= n; i++) f(i / n),
  ];

  double minOf(Iterable<double> xs) => xs.reduce((a, b) => a < b ? a : b);
  double maxOf(Iterable<double> xs) => xs.reduce((a, b) => a > b ? a : b);

  group('dynamicsCurve — neutral is regression-safe', () {
    test('neutral dynamics reproduces easeInOut exactly', () {
      final f = dynamicsCurve(DanceDynamics.neutral);
      for (var i = 0; i <= 100; i++) {
        final t = i / 100;
        expect(f(t), closeTo(Ease.easeInOut.apply(t), 1e-12));
      }
    });
  });

  group('dynamicsCurve — endpoints are exact', () {
    test('every curve passes through (0,0) and (1,1)', () {
      const cases = [
        DanceDynamics(weight: 1),
        DanceDynamics(weight: -1),
        DanceDynamics(time: 1),
        DanceDynamics(time: -1),
        DanceDynamics(flow: 1),
        DanceDynamics(flow: -1),
        DanceDynamics(weight: 1, time: 1, flow: 1),
        DanceDynamics(weight: -1, time: -1, flow: -1),
      ];
      for (final d in cases) {
        final f = dynamicsCurve(d);
        expect(f(0), closeTo(0, 1e-12), reason: 'start for $d');
        expect(f(1), closeTo(1, 1e-12), reason: 'end for $d');
      }
    });
  });

  group('dynamicsCurve — anticipation comes from Weight', () {
    test('a Strong accent dips below the start (wind-up)', () {
      final f = dynamicsCurve(const DanceDynamics(weight: 0.8));
      final earlyMin = minOf([for (var i = 1; i < 40; i++) f(i / 100)]);
      expect(
        earlyMin,
        lessThan(0),
        reason: 'the limb should pull back before driving to the peak',
      );
    });

    test('non-Strong accents never dip below the start', () {
      const cases = [
        DanceDynamics(weight: -0.8),
        DanceDynamics(time: 0.8),
        DanceDynamics(flow: 0.8),
      ];
      for (final d in cases) {
        expect(
          minOf(sample(dynamicsCurve(d))),
          greaterThan(-1e-9),
          reason: 'no wind-up expected for $d',
        );
      }
    });

    test('more Weight produces a deeper wind-up', () {
      double dip(double w) => minOf(
        [
          for (var i = 1; i < 40; i++)
            dynamicsCurve(DanceDynamics(weight: w))(i / 100),
        ],
      );
      expect(dip(0.9), lessThan(dip(0.4)));
      expect(dip(0.4), lessThan(0));
    });
  });

  group('dynamicsCurve — overshoot comes from Flow', () {
    test('a Free accent rises past the target then settles back', () {
      final f = dynamicsCurve(const DanceDynamics(flow: 0.8));
      final lateMax = maxOf([for (var i = 60; i < 100; i++) f(i / 100)]);
      expect(lateMax, greaterThan(1), reason: 'should overshoot past the peak');
      expect(f(1), closeTo(1, 1e-12), reason: 'and settle exactly on it');
    });

    test('non-Free accents never overshoot the target', () {
      const cases = [
        DanceDynamics(flow: -0.8),
        DanceDynamics(weight: 0.8),
        DanceDynamics(time: -0.8),
      ];
      for (final d in cases) {
        expect(
          maxOf(sample(dynamicsCurve(d))),
          lessThan(1 + 1e-9),
          reason: 'no overshoot expected for $d',
        );
      }
    });
  });

  group('dynamicsCurve — snap vs sustain comes from Time', () {
    // The steepest segment is where the joint moves fastest. A Sudden accent
    // should place it late (accelerate into the peak); a Sustained one early.
    double steepestAt(DanceDynamics d) {
      final f = dynamicsCurve(d);
      var bestX = 0.0;
      var bestSlope = double.negativeInfinity;
      for (var i = 0; i < 200; i++) {
        final x0 = i / 200;
        final x1 = (i + 1) / 200;
        final slope = (f(x1) - f(x0)) / (x1 - x0);
        if (slope > bestSlope) {
          bestSlope = slope;
          bestX = (x0 + x1) / 2;
        }
      }
      return bestX;
    }

    test('Sudden snaps late, Sustained eases early', () {
      expect(steepestAt(const DanceDynamics(time: 0.8)), greaterThan(0.5));
      expect(steepestAt(const DanceDynamics(time: -0.8)), lessThan(0.5));
    });

    test('neutral is symmetric — steepest at the middle', () {
      expect(steepestAt(DanceDynamics.neutral), closeTo(0.5, 0.06));
    });
  });

  group('dynamicsCurve — Glados invariants', () {
    final anyDynamics = glados.any
        .combine3<double, double, double, DanceDynamics>(
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          glados.DoubleAnys(glados.any).doubleInRange(-1, 1),
          (w, t, f) => DanceDynamics(weight: w, time: t, flow: f),
        );

    glados.Glados(anyDynamics, glados.ExploreConfig(numRuns: 300)).test(
      'endpoints exact, curve finite and bounded for any dials',
      (d) {
        final f = dynamicsCurve(d);
        expect(f(0), closeTo(0, 1e-9));
        expect(f(1), closeTo(1, 1e-9));
        for (var i = 0; i <= 50; i++) {
          final v = f(i / 50);
          expect(v.isFinite, isTrue);
          expect(v, inInclusiveRange(-0.5, 1.5));
        }
      },
      tags: 'glados',
    );
  });
}
