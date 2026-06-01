import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/date_utils_extension.dart';

class _GeneratedDateTimeParts {
  const _GeneratedDateTimeParts({
    required this.year,
    required this.month,
    required this.daySeed,
    required this.hour,
    required this.minute,
    required this.second,
    required this.millisecond,
  });

  final int year;
  final int month;
  final int daySeed;
  final int hour;
  final int minute;
  final int second;
  final int millisecond;

  int get day => (daySeed % DateTime(year, month + 1, 0).day) + 1;

  DateTime get dateTime =>
      DateTime(year, month, day, hour, minute, second, millisecond);

  String get expectedYmd =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  String toString() {
    return '_GeneratedDateTimeParts('
        'dateTime: $dateTime, '
        'expectedYmd: $expectedYmd)';
  }
}

extension _AnyDateTimeParts on glados.Any {
  glados.Generator<_GeneratedDateTimeParts> get dateTimeParts =>
      glados.CombinableAny(this).combine7(
        glados.IntAnys(this).intInRange(2000, 2031),
        glados.IntAnys(this).intInRange(1, 13),
        glados.IntAnys(this).intInRange(0, 400),
        glados.IntAnys(this).intInRange(0, 24),
        glados.IntAnys(this).intInRange(0, 60),
        glados.IntAnys(this).intInRange(0, 60),
        glados.IntAnys(this).intInRange(0, 1000),
        (
          int year,
          int month,
          int daySeed,
          int hour,
          int minute,
          int second,
          int millisecond,
        ) => _GeneratedDateTimeParts(
          year: year,
          month: month,
          daySeed: daySeed,
          hour: hour,
          minute: minute,
          second: second,
          millisecond: millisecond,
        ),
      );
}

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

    glados.Glados(
      glados.any.dateTimeParts,
      glados.ExploreConfig(numRuns: 160),
    ).test(
      'normalizes generated dates to noon, midnight, and YYYY-MM-DD',
      (scenario) {
        final date = scenario.dateTime;

        expect(date.dayAtNoon, DateTime(date.year, date.month, date.day, 12));
        expect(date.dayAtMidnight, DateTime(date.year, date.month, date.day));
        expect(date.ymd, scenario.expectedYmd, reason: '$scenario');
      },
      tags: 'glados',
    );
  });
}
