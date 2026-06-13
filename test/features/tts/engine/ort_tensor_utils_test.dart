import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/tts/engine/ort_tensor_utils.dart';

void main() {
  group('flattenList<double>', () {
    test('flattens nested lists depth-first', () {
      expect(
        flattenList<double>([
          [1.0, 2.0],
          [3.0],
        ]),
        [1.0, 2.0, 3.0],
      );
    });

    test('coerces integer leaves to double', () {
      expect(
        flattenList<double>([
          [1, 2],
          [3],
        ]),
        [1.0, 2.0, 3.0],
      );
    });

    test('handles an already-flat list', () {
      expect(flattenList<double>([1.5, 2.5]), [1.5, 2.5]);
    });
  });

  group('safeCast<double>', () {
    test('returns a matching typed list unchanged', () {
      final input = <double>[1, 2, 3];
      expect(safeCast<double>(input), same(input));
    });

    test('flattens a nested list', () {
      expect(
        safeCast<double>([
          [1.0, 2.0],
          [3.0, 4.0],
        ]),
        [1.0, 2.0, 3.0, 4.0],
      );
    });

    test('coerces a flat numeric list to doubles', () {
      expect(safeCast<double>([1, 2, 3]), [1.0, 2.0, 3.0]);
    });

    test('throws when the value is not a list', () {
      expect(() => safeCast<double>(42), throwsArgumentError);
    });
  });
}
