import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/speech/state/recording_levels.dart';

void main() {
  group('normaliseDbfs', () {
    test('0 dBFS maps to the top of the range', () {
      expect(normaliseDbfs(0), closeTo(1, 1e-9));
    });

    test('the floor maps to 0', () {
      expect(normaliseDbfs(minDbfs), 0);
    });

    test('the midpoint maps to 0.5', () {
      expect(normaliseDbfs(minDbfs / 2), closeTo(0.5, 1e-9));
    });

    test('values below the floor clamp to 0', () {
      expect(normaliseDbfs(minDbfs - 50), 0);
    });

    test('positive values clamp to 1', () {
      expect(normaliseDbfs(12), 1);
    });

    test('NaN and infinities collapse to 0', () {
      expect(normaliseDbfs(double.nan), 0);
      expect(normaliseDbfs(double.infinity), 0);
      expect(normaliseDbfs(double.negativeInfinity), 0);
    });

    glados.Glados<double>(
      glados.any.doubleInRange(-120, 30),
    ).test('always returns a finite value within [0, 1]', (dbfs) {
      final result = normaliseDbfs(dbfs);
      expect(result, inInclusiveRange(0, 1), reason: 'dbfs=$dbfs');
    }, tags: 'glados');

    glados.Glados<double>(
      glados.any.doubleInRange(-120, 30),
    ).test('is monotonically non-decreasing in dBFS', (dbfs) {
      // A louder sample never normalises lower than a quieter one.
      expect(
        normaliseDbfs(dbfs + 1),
        greaterThanOrEqualTo(normaliseDbfs(dbfs) - 1e-9),
        reason: 'dbfs=$dbfs',
      );
    }, tags: 'glados');
  });
}
