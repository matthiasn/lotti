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
  });
}
