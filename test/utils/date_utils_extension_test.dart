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

    test('endOfDay returns the same date at 23:59:59.999', () {
      final expected = DateTime(2024, 7, 27, 23, 59, 59, 999);
      expect(testDate.endOfDay, expected);
    });

    test('ymd returns date in YYYY-MM-DD format', () {
      expect(testDate.ymd, '2024-07-27');
    });

    test('md returns abbreviated month and day', () {
      expect(testDate.md, isNotEmpty);
      // Jul 27 in ABBR_MONTH_DAY format
      expect(testDate.md, contains('27'));
    });

    test('ymwd returns year, month, weekday, and day', () {
      expect(testDate.ymwd, isNotEmpty);
      // Saturday, July 27, 2024 in YEAR_MONTH_WEEKDAY_DAY format
      expect(testDate.ymwd, contains('2024'));
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

      test('endOfDay for a date already at end of day', () {
        final endOfDay = DateTime(2024, 1, 1, 23, 59, 59, 999);
        expect(endOfDay.endOfDay, endOfDay);
      });

      test('ymd zero-pads single digit month and day', () {
        final date = DateTime(2024, 1, 5);
        expect(date.ymd, '2024-01-05');
      });

      test('md for different months', () {
        // ignore: avoid_redundant_argument_values
        final jan = DateTime(2024, 1, 1);
        final dec = DateTime(2024, 12, 25);
        expect(jan.md, isNotEmpty);
        expect(dec.md, isNotEmpty);
        expect(jan.md, isNot(equals(dec.md)));
      });

      test('ymwd for different weekdays', () {
        // Monday
        final monday = DateTime(2024, 3, 11);
        // Sunday
        final sunday = DateTime(2024, 3, 17);
        expect(monday.ymwd, isNot(equals(sunday.ymwd)));
      });
    });
  });
}
