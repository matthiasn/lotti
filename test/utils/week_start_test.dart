import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/utils/week_start.dart';

void main() {
  group('firstDayOfWeekIndexForRegion', () {
    // Indices follow MaterialLocalizations.firstDayOfWeekIndex:
    // 0 = Sunday, 1 = Monday, 6 = Saturday.
    const sunday = 0;
    const monday = 1;
    const saturday = 6;

    // A sentinel fallback that is none of the three real results, so a test
    // failing into the fallback is unambiguous.
    const fallback = 3;

    test('maps Sunday-first regions to Sunday', () {
      for (final region in ['US', 'CA', 'JP', 'IL', 'BR']) {
        expect(
          firstDayOfWeekIndexForRegion(region, fallback: fallback),
          sunday,
          reason: '$region should start the week on Sunday',
        );
      }
    });

    test('maps Saturday-first regions to Saturday', () {
      for (final region in ['EG', 'SY', 'QA']) {
        expect(
          firstDayOfWeekIndexForRegion(region, fallback: fallback),
          saturday,
          reason: '$region should start the week on Saturday',
        );
      }
    });

    test('maps Monday-first / unlisted regions to Monday', () {
      // DE/GB/FR are Monday-first; ZZ is not a real region and must still
      // resolve to the world-default Monday rather than the fallback.
      for (final region in ['DE', 'GB', 'FR', 'ZZ']) {
        expect(
          firstDayOfWeekIndexForRegion(region, fallback: fallback),
          monday,
          reason: '$region should start the week on Monday',
        );
      }
    });

    test('follows CLDR v46 for regions that older snapshots got wrong', () {
      // These four were Sunday/Saturday in pre-v46 CLDR but are Monday in
      // v46 (AE moved to a Sat/Sun weekend in 2022). Pinning them guards the
      // region sets against silently regressing to a stale snapshot.
      for (final region in ['AU', 'CN', 'GT', 'AE']) {
        expect(
          firstDayOfWeekIndexForRegion(region, fallback: fallback),
          monday,
          reason: '$region is Monday-first in CLDR v46',
        );
      }
    });

    test('is case-insensitive on the region code', () {
      expect(firstDayOfWeekIndexForRegion('us', fallback: fallback), sunday);
      expect(firstDayOfWeekIndexForRegion('eg', fallback: fallback), saturday);
    });

    test('returns the fallback only when no region is available', () {
      expect(firstDayOfWeekIndexForRegion(null, fallback: fallback), fallback);
      expect(firstDayOfWeekIndexForRegion('', fallback: fallback), fallback);
    });

    test('the Sunday and Saturday region sets are disjoint', () {
      expect(
        sundayFirstRegions.intersection(saturdayFirstRegions),
        isEmpty,
      );
    });
  });
}
