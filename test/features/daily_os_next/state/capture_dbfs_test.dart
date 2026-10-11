import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/state/capture_dbfs.dart';
import 'package:lotti/features/daily_os_next/state/capture_state.dart';

void main() {
  group('sanitizeVisualDbfs', () {
    test('mirrors CaptureState.defaultDbfs as the floor', () {
      expect(minVisualDbfs, CaptureState.defaultDbfs);
    });

    test('clamps below the floor to the floor', () {
      expect(sanitizeVisualDbfs(minVisualDbfs - 100), minVisualDbfs);
    });

    test('clamps positive values to 0', () {
      expect(sanitizeVisualDbfs(5), 0);
    });

    test('passes through an in-range value unchanged', () {
      const inRange = minVisualDbfs / 2;
      expect(sanitizeVisualDbfs(inRange), inRange);
    });

    test('NaN and infinities collapse to the floor', () {
      expect(sanitizeVisualDbfs(double.nan), minVisualDbfs);
      expect(sanitizeVisualDbfs(double.infinity), minVisualDbfs);
      expect(sanitizeVisualDbfs(double.negativeInfinity), minVisualDbfs);
    });

    glados.Glados<double>(
      glados.any.doubleInRange(-200, 50),
    ).test('always stays within [minVisualDbfs, 0]', (dbfs) {
      final result = sanitizeVisualDbfs(dbfs);
      expect(result, inInclusiveRange(minVisualDbfs, 0), reason: 'dbfs=$dbfs');
    }, tags: 'glados');
  });
}
