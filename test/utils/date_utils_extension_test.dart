import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/date_utils_extension.dart';

void main() {
  group('DateUtilsExtension', () {
    final testDate = DateTime(2024, 7, 27, 18, 30, 15);

    test('dayAtNoon returns the same date at 12:00', () {
      final expected = DateTime(2024, 7, 27, 12);
      expect(testDate.dayAtNoon, expected);
    });

    test('dayAtMidnight returns the same date at 00:00', () {
      final expected = DateTime(2024, 7, 27);
      expect(testDate.dayAtMidnight, expected);
    });

    test('ymd returns date in YYYY-MM-DD format', () {
      expect(testDate.ymd, '2024-07-27');
    });

    group('edge cases', () {
      test('dayAtNoon for midnight date', () {
        // ignore: avoid_redundant_argument_values
        final midnight = DateTime(2024, 1, 1);
        expect(midnight.dayAtNoon, DateTime(2024, 1, 1, 12));
      });

      test('dayAtMidnight strips time component', () {
        final withTime = DateTime(2024, 12, 31, 23, 59, 59, 999);
        expect(withTime.dayAtMidnight, DateTime(2024, 12, 31));
      });

      test('ymd zero-pads single digit month and day', () {
        final date = DateTime(2024, 1, 5);
        expect(date.ymd, '2024-01-05');
      });
    });
  });
}
