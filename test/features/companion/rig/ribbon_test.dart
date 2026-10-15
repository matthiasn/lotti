import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/companion/rig/ribbon.dart';

void main() {
  const arm = [Offset.zero, Offset(40, 0), Offset(80, 30), Offset(100, 80)];
  const widths = [8.0, 7.0, 6.0, 5.0];

  group('ribbonCentre', () {
    test('passes through every joint', () {
      for (var i = 0; i < arm.length; i++) {
        final s = i == arm.length - 1 ? arm.length - 1.0 : i.toDouble();
        final c = ribbonCentre(arm, s, const [0.5, 0.5, 0.5, 0.5]);
        expect((c.point - arm[i]).distance, lessThan(1e-9));
      }
    });

    test('returns a unit tangent, even for coincident joints', () {
      final c = ribbonCentre(arm, 1.5, const [0.5, 0.5, 0.5, 0.5]);
      expect(c.tangent.distance, closeTo(1, 1e-9));
      final flat = ribbonCentre(
        const [Offset.zero, Offset.zero],
        0.5,
        const [0.5, 0.5],
      );
      expect(flat.tangent.distance, closeTo(1, 1e-9));
    });
  });

  group('ribbonEdges', () {
    test('samples ten steps per segment, edges at the half widths', () {
      final smp = ribbonEdges(arm, widths, 0, 3);
      expect(smp, hasLength(31));
      expect((smp.first.front - smp.first.centre).distance, closeTo(8, 1e-9));
      expect((smp.last.back - smp.last.centre).distance, closeTo(5, 1e-9));
    });

    test('a negative back width puts the back edge across the centre', () {
      final smp = ribbonEdges(
        arm,
        widths,
        0.5,
        1.5,
        back: [for (final w in widths) -w * 0.5],
      );
      for (final s in smp) {
        final toFront = s.front - s.centre;
        final toBack = s.back - s.centre;
        // Both edges on the same side of the centre line.
        expect(toFront.dx * toBack.dx + toFront.dy * toBack.dy, greaterThan(0));
      }
    });
  });

  glados.Glados(
    glados.any.intInRange(-60, 60),
    glados.ExploreConfig(numRuns: 120),
  ).test('the outline contains its own centre line', (bend) {
    final pts = [
      Offset.zero,
      const Offset(50, 0),
      Offset(90, bend.toDouble()),
    ];
    final path = ribbonPath(pts, const [6, 6, 6], 0, 2);
    for (final s in ribbonEdges(pts, const [6, 6, 6], 0.1, 1.9)) {
      expect(path.contains(s.centre), isTrue);
    }
  }, tags: 'glados');

  test('caps round the ends; without caps the ends are flat', () {
    final capped = ribbonPath(arm, widths, 0, 3).getBounds();
    final flat = ribbonPath(
      arm,
      widths,
      0,
      3,
      capStart: false,
      capEnd: false,
    ).getBounds();
    // The round start cap reaches behind the first joint.
    expect(capped.left, lessThan(flat.left));
  });
}
