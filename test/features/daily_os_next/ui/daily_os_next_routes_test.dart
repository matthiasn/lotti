import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/daily_os_next/ui/daily_os_next_routes.dart';

void main() {
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
