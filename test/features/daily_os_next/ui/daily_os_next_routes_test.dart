import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';

/// Generates dates within a sensible calendar range.
extension _AnyRouteDate on glados.Any {
  glados.Generator<DateTime> get routeDate =>
      glados.CombinableAny(this).combine3(
        glados.any.intInRange(1000, 9999),
        glados.any.intInRange(1, 12),
        glados.any.intInRange(1, 28),
        DateTime.new,
      );
}

void main() {
  group('DailyOS Next route helpers — properties', () {
    glados.Glados(
      glados.any.routeDate,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'dailyOsNextRouteDate / parseDailyOsNextRouteDate round-trip',
      (date) {
        final encoded = dailyOsNextRouteDate(date);
        final decoded = parseDailyOsNextRouteDate(encoded);
        expect(decoded, isNotNull, reason: 'encoded=$encoded should parse');
        expect(
          decoded,
          equals(DateTime(date.year, date.month, date.day)),
          reason: 'decoded date must equal normalised input',
        );
      },
      tags: 'glados',
    );

    glados.Glados(
      glados.any.routeDate,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'dailyOsNextRouteDate produces yyyy-MM-dd formatted string',
      (date) {
        final encoded = dailyOsNextRouteDate(date);
        expect(
          encoded,
          matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
          reason: 'date string must match yyyy-MM-dd',
        );
      },
      tags: 'glados',
    );

    glados.Glados2<DailyOsNextRouteTarget, DateTime>(
      glados.AnyUtils(glados.any).choose(DailyOsNextRouteTarget.values),
      glados.any.routeDate,
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'dailyOsNextRoutePath always matches /calendar/<target>/<yyyy-MM-dd>',
      (target, date) {
        final path = dailyOsNextRoutePath(target, date);
        final segments = path.split('/');

        // A leading '/' yields an empty first segment, then exactly three
        // meaningful segments: 'calendar', the target name, and the date.
        expect(segments, hasLength(4), reason: 'path=$path');
        expect(segments.first, isEmpty);
        expect(segments[1], 'calendar');
        expect(segments[2], target.name);
        expect(segments[3], dailyOsNextRouteDate(date));
        expect(
          path,
          matches(RegExp(r'^/calendar/[a-z]+/\d{4}-\d{2}-\d{2}$')),
          reason: 'path=$path',
        );
      },
      tags: 'glados',
    );
  });

  group('DailyOS Next route helpers', () {
    test('normalizes a date with a time-of-day to local midnight', () {
      // The 23:59 time component must be dropped from the encoded segment.
      expect(dailyOsNextRouteDate(DateTime(2026, 5, 6, 23, 59)), '2026-05-06');
    });

    for (final target in DailyOsNextRouteTarget.values) {
      test('builds a $target route path with the lowercase enum name', () {
        final date = DateTime(2026, 5, 6, 23, 59);

        final path = dailyOsNextRoutePath(target, date);

        expect(path, '/calendar/${target.name}/2026-05-06');
        // Guard against the enum name accidentally diverging from the
        // lowercase member identity used in the route segment.
        expect(target.name, target.name.toLowerCase());
        expect(path.split('/'), ['', 'calendar', target.name, '2026-05-06']);
      });
    }

    test('parses route dates and rejects invalid values', () {
      expect(
        parseDailyOsNextRouteDate('2026-05-06'),
        DateTime(2026, 5, 6),
      );
      expect(parseDailyOsNextRouteDate('not-a-date'), isNull);
      expect(parseDailyOsNextRouteDate('2026-5-06'), isNull);
      expect(parseDailyOsNextRouteDate('2026-02-31'), isNull);
      expect(parseDailyOsNextRouteDate('2026-13-10'), isNull);
    });

    test('accepts a leap-year Feb 29 but rejects it in a common year', () {
      // 2024 is a leap year, so Feb 29 is a real calendar date.
      expect(
        parseDailyOsNextRouteDate('2024-02-29'),
        DateTime(2024, 2, 29),
      );
      // 2025 is a common year: DateTime(2025, 2, 29) overflows to Mar 1,
      // so the day-equality guard rejects it.
      expect(parseDailyOsNextRouteDate('2025-02-29'), isNull);
    });

    test('rejects regex-valid but calendar-invalid zero components', () {
      // Day 00: DateTime(2026, 1, 0) underflows to Dec 31 2025, so the
      // month/year guards reject it.
      expect(parseDailyOsNextRouteDate('2026-01-00'), isNull);
      // Month 00: DateTime(2026, 0, 1) underflows to Dec 1 2025, so the
      // year guard rejects it.
      expect(parseDailyOsNextRouteDate('2026-00-01'), isNull);
    });
  });
}
