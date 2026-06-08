import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/first_day_of_week.dart';

void main() {
  group('firstDayOfWeekIndexForCountry', () {
    test('European/Monday-default regions start on Monday', () {
      // DE/FR/GB are not in the Sunday or Saturday sets, so they fall to the
      // CLDR global default of Monday (index 1).
      for (final code in ['DE', 'FR', 'GB', 'RO', 'ES', 'CZ']) {
        expect(firstDayOfWeekIndexForCountry(code), 1, reason: code);
      }
    });

    test('Sunday-first regions return Sunday (0)', () {
      for (final code in ['US', 'CA', 'JP', 'BR', 'IN', 'SA']) {
        expect(firstDayOfWeekIndexForCountry(code), 0, reason: code);
      }
    });

    test('Saturday-first regions return Saturday (6)', () {
      for (final code in ['EG', 'AE', 'IR', 'QA']) {
        expect(firstDayOfWeekIndexForCountry(code), 6, reason: code);
      }
    });

    test('is case-insensitive', () {
      expect(firstDayOfWeekIndexForCountry('us'), 0);
      expect(firstDayOfWeekIndexForCountry('de'), 1);
    });

    test('null, empty, or unknown regions default to Monday', () {
      expect(firstDayOfWeekIndexForCountry(null), 1);
      expect(firstDayOfWeekIndexForCountry(''), 1);
      expect(firstDayOfWeekIndexForCountry('ZZ'), 1);
    });
  });

  group('regionFromLocaleName', () {
    test('extracts the region from common identifier shapes', () {
      expect(regionFromLocaleName('en_DE'), 'DE');
      expect(regionFromLocaleName('en_DE.UTF-8'), 'DE');
      expect(regionFromLocaleName('de-DE'), 'DE');
      expect(regionFromLocaleName('zh_Hant_HK'), 'HK');
      expect(regionFromLocaleName('en_US@calendar=gregorian'), 'US');
    });

    test('normalizes a lowercase region without matching the language', () {
      // Lowercase region is accepted and upper-cased...
      expect(regionFromLocaleName('en_us.UTF-8'), 'US');
      // ...but the two-letter language subtag is never taken for a region.
      expect(regionFromLocaleName('fr'), isNull);
    });

    test('returns null when no region is present', () {
      expect(regionFromLocaleName('en'), isNull);
      expect(regionFromLocaleName('de'), isNull);
      expect(regionFromLocaleName(''), isNull);
    });
  });

  group('leadingBlankDayCount', () {
    // 1 May 2026 is a Friday; 1 June 2026 is a Monday.
    test('Friday-starting month: 4 blanks for Monday-start, 5 for Sunday', () {
      expect(
        leadingBlankDayCount(year: 2026, month: 5, firstDayOfWeekIndex: 1),
        4,
      );
      expect(
        leadingBlankDayCount(year: 2026, month: 5, firstDayOfWeekIndex: 0),
        5,
      );
    });

    test('Monday-starting month: 0 blanks for Monday-start, 1 for Sunday', () {
      expect(
        leadingBlankDayCount(year: 2026, month: 6, firstDayOfWeekIndex: 1),
        0,
      );
      expect(
        leadingBlankDayCount(year: 2026, month: 6, firstDayOfWeekIndex: 0),
        1,
      );
    });
  });
}
