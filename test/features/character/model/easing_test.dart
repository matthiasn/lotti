import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/character/model/easing.dart';

void main() {
  group('Ease', () {
    test('all curves pin the 0 and 1 endpoints', () {
      for (final ease in Ease.values) {
        expect(ease.apply(0), closeTo(0, 1e-9), reason: '$ease at 0');
        expect(ease.apply(1), closeTo(1, 1e-9), reason: '$ease at 1');
      }
    });

    test('all curves clamp out-of-range input', () {
      for (final ease in Ease.values) {
        expect(ease.apply(-5), closeTo(0, 1e-9));
        expect(ease.apply(5), closeTo(1, 1e-9));
      }
    });

    test('linear is the identity', () {
      expect(Ease.linear.apply(0.3), closeTo(0.3, 1e-9));
    });

    test('easeInOut is symmetric around the midpoint', () {
      expect(Ease.easeInOut.apply(0.5), closeTo(0.5, 1e-9));
      final a = Ease.easeInOut.apply(0.25);
      final b = Ease.easeInOut.apply(0.75);
      expect(a + b, closeTo(1, 1e-9));
    });

    test('easeIn starts slow, easeOut ends slow', () {
      expect(Ease.easeIn.apply(0.5), lessThan(0.5));
      expect(Ease.easeOut.apply(0.5), greaterThan(0.5));
    });

    test('curves are monotonically non-decreasing', () {
      for (final ease in Ease.values) {
        var prev = ease.apply(0);
        for (var i = 1; i <= 20; i++) {
          final v = ease.apply(i / 20);
          expect(v, greaterThanOrEqualTo(prev - 1e-9), reason: '$ease');
          prev = v;
        }
      }
    });
  });
}
