import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/relationships/model/relationship_calendar.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// A single process has one zone, and CI's is UTC, where a local value's
// components are its UTC components and `.toUtc()` can never disagree with
// them. `TZDateTime` carries its own zone, so a stamp read in Berlin and the
// same components read in Tokyo exist side by side here — the two devices of
// `specs/tla/RelationshipCadence.tla` — and the cases discriminate on any
// host, UTC runners included.
void main() {
  setUpAll(tz_data.initializeTimeZones);

  late tz.Location berlin;
  late tz.Location tokyo;
  late tz.Location newYork;

  setUp(() {
    berlin = tz.getLocation('Europe/Berlin');
    tokyo = tz.getLocation('Asia/Tokyo');
    newYork = tz.getLocation('America/New_York');
  });

  group('relationshipStoredInstant', () {
    // Written in Berlin at 09:20 summer time, read by any device: the
    // components and the recorded offset name 07:20 UTC wherever the reader
    // sits, which the device's own zone could not.
    test('turns stored components and their offset into one instant', () {
      expect(
        relationshipStoredInstant(DateTime(2026, 8, 15, 9, 20, 5, 7, 9), 120),
        DateTime.utc(2026, 8, 15, 7, 20, 5, 7, 9),
      );
      expect(
        relationshipStoredInstant(DateTime(2026, 8, 15, 1, 30), -300),
        DateTime.utc(2026, 8, 15, 6, 30),
      );
    });

    test('names the same instant whichever zone parsed the components', () {
      // "2026-08-18T00:30" as Berlin and Tokyo each parse it, beside the
      // writer's offset of +02:00.
      final inBerlin = tz.TZDateTime(berlin, 2026, 8, 18, 0, 30);
      final inTokyo = tz.TZDateTime(tokyo, 2026, 8, 18, 0, 30);
      expect(inBerlin.toUtc().isAtSameMomentAs(inTokyo.toUtc()), isFalse);

      final meant = DateTime.utc(2026, 8, 17, 22, 30);
      expect(relationshipStoredInstant(inBerlin, 120), meant);
      expect(relationshipStoredInstant(inTokyo, 120), meant);
    });

    test('takes a UTC value, or one without an offset, as it is', () {
      final utc = DateTime.utc(2026, 8, 15, 9, 20);
      final local = DateTime(2026, 8, 15, 9, 20);

      expect(relationshipStoredInstant(utc, 120), utc);
      expect(relationshipStoredInstant(local, null), local.toUtc());
    });
  });

  group('relationshipCalendarDay', () {
    test("is the day the components name, not the instant's UTC day", () {
      // 00:30 in Berlin is 22:30 UTC the day before; the writer's calendar
      // says the 18th, and so must every reader.
      final inBerlin = tz.TZDateTime(berlin, 2026, 8, 18, 0, 30);
      final inTokyo = tz.TZDateTime(tokyo, 2026, 8, 18, 0, 30);
      final inNewYork = tz.TZDateTime(newYork, 2026, 8, 18, 0, 30);
      final day = DateTime.utc(2026, 8, 18);

      expect(relationshipCalendarDay(inBerlin), day);
      expect(relationshipCalendarDay(inTokyo), day);
      expect(relationshipCalendarDay(inNewYork), day);
      expect(relationshipCalendarDay(DateTime(2026, 8, 18, 0, 30)), day);
      expect(relationshipCalendarDay(day).isUtc, isTrue);
    });

    test('a UTC value names its UTC day', () {
      expect(
        relationshipCalendarDay(DateTime.utc(2026, 8, 17, 23, 59)),
        DateTime.utc(2026, 8, 17),
      );
    });
  });

  group('relationshipDueDay', () {
    test('is the calendar day plus the cadence, across a month end', () {
      expect(
        relationshipDueDay(tz.TZDateTime(tokyo, 2026, 8, 28, 22), 5),
        DateTime.utc(2026, 9, 2),
      );
      expect(
        relationshipDueDay(DateTime(2026, 8, 14, 20), 7),
        DateTime.utc(2026, 8, 21),
      );
    });

    test('counts days on the calendar, not hours — a DST transition in '
        'between moves nothing', () {
      // Berlin springs forward on 2026-03-29: a week of 167 hours. Adding
      // seven times twenty-four hours to 23:30 on the 22nd lands at 00:30
      // on the 30th; the calendar says the 29th.
      final late = tz.TZDateTime(berlin, 2026, 3, 22, 23, 30);
      expect(late.add(const Duration(days: 7)).day, 30);
      expect(relationshipDueDay(late, 7), DateTime.utc(2026, 3, 29));
    });
  });

  group('relationshipCalendarDaysBetween', () {
    test('zero on the same day whatever the hours, signed either way', () {
      expect(
        relationshipCalendarDaysBetween(
          DateTime(2026, 8, 14, 23, 59),
          DateTime(2026, 8, 14, 0, 1),
        ),
        0,
      );
      expect(
        relationshipCalendarDaysBetween(
          DateTime(2026, 8, 11, 14, 20),
          DateTime(2026, 8, 18, 9),
        ),
        7,
      );
      expect(
        relationshipCalendarDaysBetween(
          DateTime(2026, 8, 18, 9),
          DateTime(2026, 8, 11, 14, 20),
        ),
        -7,
      );
    });

    test('the 23-hour day of a spring-forward is one day, not zero', () {
      // Local midnights 23 hours apart floor to zero days under `inDays`;
      // on the calendar the 29th follows the 28th.
      final before = tz.TZDateTime(berlin, 2026, 3, 28, 10);
      final after = tz.TZDateTime(berlin, 2026, 3, 29, 10);
      expect(after.difference(before).inHours, 23);
      expect(relationshipCalendarDaysBetween(before, after), 1);

      final eve = tz.TZDateTime(newYork, 2026, 3, 8);
      final morning = tz.TZDateTime(newYork, 2026, 3, 9);
      expect(morning.difference(eve).inHours, 23);
      expect(relationshipCalendarDaysBetween(eve, morning), 1);
    });

    // Every day of 2026 in zones with and without DST, spans of up to forty
    // days either way, the hours chosen so the two instants straddle local
    // midnights: the day keys count exactly the calendar days, and the due
    // day of one is the calendar day of the other.
    final day = glados.any.combine3(
      glados.any.choose(['Europe/Berlin', 'America/New_York', 'Asia/Tokyo']),
      glados.any.intInRange(1, 366),
      glados.any.intInRange(0, 24),
      (String zone, int dayOfYear, int hour) =>
          (zone: zone, dayOfYear: dayOfYear, hour: hour),
    );
    glados.Glados2(
      day,
      glados.any.intInRange(-40, 41),
      glados.ExploreConfig(numRuns: 200),
    ).test(
      'a day key difference agrees with the calendar on every day of the '
      'year, in zones with and without DST',
      (start, span) {
        final location = tz.getLocation(start.zone);
        final from = tz.TZDateTime(
          location,
          2026,
          1,
          start.dayOfYear,
          start.hour,
        );
        final to = tz.TZDateTime(
          location,
          2026,
          1,
          start.dayOfYear + span,
          23 - start.hour,
        );
        expect(relationshipCalendarDaysBetween(from, to), span);
        expect(relationshipDueDay(from, span), relationshipCalendarDay(to));
      },
    );
  });
}
