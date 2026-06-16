import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/journal/ui/widgets/entry_details/entry_datetime_range.dart';

void main() {
  group('EntryDateTimeRange.fromBounds', () {
    test('same-day entry opens in shared-date mode', () {
      final r = EntryDateTimeRange.fromBounds(
        DateTime(2024, 6, 15, 14, 30),
        DateTime(2024, 6, 15, 15, 15),
      );

      expect(r.differentDates, isFalse);
      expect(r.overnightAuto, isFalse);
      expect(r.endDateOverride, isNull);
      expect(r.dateFrom, DateTime(2024, 6, 15, 14, 30));
      expect(r.dateTo, DateTime(2024, 6, 15, 15, 15));
      expect(r.duration, const Duration(minutes: 45));
      expect(r.valid, isTrue);
    });

    test(
      'plain overnight span stays shared-date with an auto next-day roll',
      () {
        final r = EntryDateTimeRange.fromBounds(
          DateTime(2024, 6, 15, 23, 30),
          DateTime(2024, 6, 16, 0, 30),
        );

        // End clock (00:30) is before start clock (23:30) and the end day is the
        // next day, so it is reproduced by the auto-roll, not different-dates.
        expect(r.differentDates, isFalse);
        expect(r.overnightAuto, isTrue);
        expect(r.endDateOverride, isNull);
        expect(r.dateTo, DateTime(2024, 6, 16, 0, 30));
        expect(r.duration, const Duration(hours: 1));
        expect(r.valid, isTrue);
      },
    );

    test(
      'exactly-24h same-clock next-day entry opens in different-dates mode',
      () {
        // End clock is NOT before start clock, so the auto-roll cannot reproduce
        // it — it must open with an explicit end date.
        final r = EntryDateTimeRange.fromBounds(
          DateTime(2024, 6, 15, 9),
          DateTime(2024, 6, 16, 9),
        );

        expect(r.differentDates, isTrue);
        expect(r.endDateOverride, DateTime(2024, 6, 16));
        expect(r.dateTo, DateTime(2024, 6, 16, 9));
        expect(r.duration, const Duration(hours: 24));
        expect(r.valid, isTrue);
      },
    );

    test(
      'multi-day span opens in different-dates mode with the real end date',
      () {
        final r = EntryDateTimeRange.fromBounds(
          DateTime(2024, 6, 14, 9),
          DateTime(2024, 6, 16, 11),
        );

        expect(r.differentDates, isTrue);
        expect(r.startDate, DateTime(2024, 6, 14));
        expect(r.endDateOverride, DateTime(2024, 6, 16));
        expect(r.dateFrom, DateTime(2024, 6, 14, 9));
        expect(r.dateTo, DateTime(2024, 6, 16, 11));
        expect(r.duration, const Duration(days: 2, hours: 2));
        expect(r.valid, isTrue);
      },
    );
  });

  group('derivation', () {
    test(
      'shared mode rolls the end to the next day when end clock < start clock',
      () {
        final start = EntryDateTimeRange(
          startDate: _date,
          startTime: const TimeOfDay(hour: 22, minute: 0),
          endTime: const TimeOfDay(hour: 1, minute: 0),
          differentDates: false,
        );

        expect(start.overnightAuto, isTrue);
        expect(start.dateTo, DateTime(2024, 6, 16, 1));
        expect(start.duration, const Duration(hours: 3));
        expect(start.valid, isTrue);
      },
    );

    test('different-dates mode derives dateTo from the override day', () {
      final r = EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 8, minute: 0),
        differentDates: true,
        endDateOverride: _datePlus2,
      );

      // End clock is earlier than start clock but on a later day, so it is
      // still valid and spans two days.
      expect(r.overnightAuto, isFalse);
      expect(r.dateTo, DateTime(2024, 6, 17, 8));
      expect(r.valid, isTrue);
    });

    test('an end date before the start date is invalid', () {
      final r = EntryDateTimeRange(
        startDate: _date,
        startTime: const TimeOfDay(hour: 9, minute: 0),
        endTime: const TimeOfDay(hour: 9, minute: 0),
        differentDates: true,
        endDateOverride: _datePlusMinus, // earlier than startDate
      );

      expect(r.valid, isFalse);
    });
  });

  group('copyWith', () {
    final base = EntryDateTimeRange(
      startDate: _date,
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime: const TimeOfDay(hour: 10, minute: 0),
      differentDates: false,
    );

    test('replaces only the requested field', () {
      final next = base.copyWith(
        endTime: const TimeOfDay(hour: 11, minute: 30),
      );
      expect(next.startTime, const TimeOfDay(hour: 9, minute: 0));
      expect(next.endTime, const TimeOfDay(hour: 11, minute: 30));
      expect(next.differentDates, isFalse);
    });

    test('differentDates without an end-date override falls back to the start '
        'day instead of crashing', () {
      final r = base.copyWith(differentDates: true);
      expect(r.endDateOverride, isNull);
      // dateTo/valid/duration must not throw on the missing override.
      expect(r.dateTo, DateTime(2024, 6, 15, 10));
      expect(r.valid, isTrue);
      expect(r.duration, const Duration(hours: 1));
    });

    test('clearOverride nulls the end date override', () {
      final withOverride = base.copyWith(
        differentDates: true,
        endDateOverride: _datePlus2,
      );
      expect(withOverride.endDateOverride, _datePlus2);

      final cleared = withOverride.copyWith(
        differentDates: false,
        clearOverride: true,
      );
      expect(cleared.endDateOverride, isNull);
    });
  });

  // Glados property: fromBounds() round-trips any start <= end pair back to the
  // same two timestamps (at minute precision), and the result is always valid —
  // regardless of whether it lands in shared, overnight, or different-dates mode.
  group('properties', () {
    final base = DateTime(2024);

    glados.Glados3(
      glados.IntAnys(glados.any).intInRange(0, 400), // day offset
      glados.IntAnys(glados.any).intInRange(0, 1439), // start minute of day
      glados.IntAnys(glados.any).intInRange(0, 6000), // duration minutes
      glados.ExploreConfig(numRuns: 200),
    ).test('fromBounds round-trips dateFrom/dateTo and is always valid', (
      dayOffset,
      startMinute,
      durationMinutes,
    ) {
      final dateFrom = base.add(
        Duration(days: dayOffset, minutes: startMinute),
      );
      final dateTo = dateFrom.add(Duration(minutes: durationMinutes));

      final r = EntryDateTimeRange.fromBounds(dateFrom, dateTo);

      expect(r.dateFrom, dateFrom);
      expect(r.dateTo, dateTo);
      expect(r.duration, dateTo.difference(dateFrom));
      expect(r.valid, isTrue);
    }, tags: 'glados');
  });
}

final _date = DateTime(2024, 6, 15);
final _datePlus2 = DateTime(2024, 6, 17);
final _datePlusMinus = DateTime(2024, 6, 14);
