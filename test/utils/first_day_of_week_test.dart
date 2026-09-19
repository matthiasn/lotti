import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/utils/first_day_of_week.dart';

void main() {
  group('properties', () {
    glados.Glados3(
      glados.any.intInRange(1900, 2200),
      glados.any.intInRange(1, 13),
      glados.any.intInRange(0, 7),
      glados.ExploreConfig(numRuns: 300),
    ).test(
      'blank cells put the 1st under its own weekday column',
      (year, month, firstDay) {
        final blanks = leadingBlankDayCount(
          year: year,
          month: month,
          firstDayOfWeekIndex: firstDay,
        );
        expect(blanks, inInclusiveRange(0, 6));
        // Sunday-based index (0 = Sunday … 6 = Saturday) of the 1st.
        final firstOfMonth = DateTime.utc(year, month).weekday % 7;
        expect((blanks + firstDay) % 7, firstOfMonth);
      },
      tags: 'glados',
    );

    final language = glados.any.choose(['en', 'de', 'zh', 'fil', 'C']);
    final region = glados.any.choose(['DE', 'us', 'Gb', 'hK', null]);
    final script = glados.any.choose(['Hant', 'Latn', null]);
    final separator = glados.any.choose(['_', '-']);
    final suffix = glados.any.choose(['', '.UTF-8', '@euro', '.utf8@euro']);

    glados.Glados(
      glados.any.combine5(
        language,
        script,
        region,
        separator,
        suffix,
        (String lang, String? script, String? region, String sep, String sfx) =>
            (
              name: [lang, ?script, ?region].join(sep) + sfx,
              region: region?.toUpperCase(),
            ),
      ),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'the region is the two-letter subtag, upper-cased, suffix ignored',
      (locale) {
        final extracted = regionFromLocaleName(locale.name);
        expect(extracted, locale.region, reason: locale.name);
        if (extracted != null) {
          expect(extracted, matches(RegExp(r'^[A-Z]{2}$')));
        }
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.stringOf('adeghksuzAEGSUZ'),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'every country code maps to Sunday, Monday or Saturday, any case',
      (code) {
        final index = firstDayOfWeekIndexForCountry(code);
        expect(index, isIn(const {0, 1, 6}));
        expect(firstDayOfWeekIndexForCountry(code.toLowerCase()), index);
      },
      tags: 'glados',
    );
  });

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
