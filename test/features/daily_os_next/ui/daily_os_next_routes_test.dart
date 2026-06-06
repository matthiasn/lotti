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
  });

  group('DailyOS Next route helpers', () {
    test('builds stable route paths with normalized local dates', () {
      final date = DateTime(2026, 5, 6, 23, 59);

      expect(dailyOsNextRouteDate(date), '2026-05-06');
      expect(
        dailyOsNextRoutePath(DailyOsNextRouteTarget.refine, date),
        '/calendar/refine/2026-05-06',
      );
      expect(
        dailyOsNextRoutePath(DailyOsNextRouteTarget.commit, date),
        '/calendar/commit/2026-05-06',
      );
      expect(
        dailyOsNextRoutePath(DailyOsNextRouteTarget.shutdown, date),
        '/calendar/shutdown/2026-05-06',
      );
    });

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
  });
}
