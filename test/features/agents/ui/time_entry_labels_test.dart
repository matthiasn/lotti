import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/features/agents/ui/time_entry_labels.dart';

void main() {
  setUpAll(() async {
    for (final locale in ['en', 'en_GB', 'de', 'da', 'cs']) {
      await initializeDateFormatting(locale);
    }
  });

  // Thursday. Every expectation below is read against this "today", so the
  // year rule is pinned rather than drifting with the calendar.
  final now = DateTime(2026, 7, 16, 21);

  T at<T>(T Function() body) => withClock(Clock.fixed(now), body);

  // The day's own spaces are no-break spaces (asserted on its own below);
  // everywhere else the labels are compared with ordinary ones, so an
  // expectation reads as the row does.
  String plain(String label) => label.replaceAll('\u00A0', ' ');
  String moment(String locale, DateTime at_) =>
      plain(at(() => timeEntryMomentLabel(locale, at_)));

  group('timeEntryMomentLabel', () {
    test('leads with the weekday and day, then the time', () {
      expect(
        moment('en', DateTime(2026, 7, 8, 9)),
        'Wed, Jul 8, 09:00',
      );
    });

    test('names the day even when it is today', () {
      // A proposal can sit unconfirmed past midnight; a row that dropped
      // "today" would silently start meaning a different day.
      expect(
        moment('en', DateTime(2026, 7, 16, 14, 5)),
        'Thu, Jul 16, 14:05',
      );
    });

    test('adds the year once it is not the current one', () {
      expect(
        moment('en', DateTime(2025, 12, 30, 10)),
        'Tue, Dec 30, 2025, 10:00',
      );
      expect(
        moment('en', DateTime(2027, 1, 4, 8, 30)),
        'Mon, Jan 4, 2027, 08:30',
      );
    });

    test('the year rule follows the clock, not the entry', () {
      final entry = DateTime(2026, 7, 8, 9);
      expect(
        plain(
          withClock(
            Clock.fixed(DateTime(2027, 1, 2)),
            () => timeEntryMomentLabel('en', entry),
          ),
        ),
        'Wed, Jul 8, 2026, 09:00',
      );
    });

    group('is written the way each locale writes a date and a time', () {
      final at_ = DateTime(2026, 7, 8, 9);
      const expected = {
        // Day before month, no comma after the weekday.
        'en_GB': 'Wed 8 Jul, 09:00',
        'de': 'Mi., 8. Juli, 09:00',
        // Danish joins date and time with a space and writes 09.00.
        'da': 'ons. 8. jul. 09.00',
        // Czech has no leading zero on the hour.
        'cs': 'st 8. 7. 9:00',
      };
      for (final MapEntry(key: locale, value: label) in expected.entries) {
        test(locale, () {
          expect(moment(locale, at_), label);
        });
      }
    });
  });

  group('timeEntryMomentLabel keeps the day on one line', () {
    test('no ordinary space is left inside the day', () {
      // A narrow row would otherwise end a line on "Tue," and start the next
      // with "Dec 30, 2025".
      expect(
        at(() => timeEntryMomentLabel('en', DateTime(2025, 12, 30, 10))),
        'Tue,\u00A0Dec\u00A030,\u00A02025, 10:00',
      );
      expect(
        at(() => timeEntryMomentLabel('de', DateTime(2026, 7, 8, 9))),
        'Mi.,\u00A08.\u00A0Juli, 09:00',
      );
    });

    test('the line may still break between the day and the time', () {
      final label = at(
        () => timeEntryMomentLabel('en', DateTime(2026, 7, 8, 9)),
      );
      expect(label.split(' '), ['Wed,\u00A0Jul\u00A08,', '09:00']);
    });
  });

  group('timeEntryRangeLabels', () {
    ({String? start, String? end, bool endNamesDay}) labels(
      Object? startTime,
      Object? endTime, {
      String locale = 'en',
    }) {
      final result = at(
        () => timeEntryRangeLabels(
          locale,
          startTime: startTime,
          endTime: endTime,
        ),
      );
      return (
        start: result.start == null ? null : plain(result.start!),
        end: result.end == null ? null : plain(result.end!),
        endNamesDay: result.endNamesDay,
      );
    }

    test('a same-day session names the day once, on the start', () {
      expect(
        labels('2026-07-08T09:00:00', '2026-07-08T12:30:00'),
        (start: 'Wed, Jul 8, 09:00', end: '12:30', endNamesDay: false),
      );
    });

    test('a session across midnight names both days', () {
      expect(
        labels('2026-07-10T22:30:00', '2026-07-11T01:15:00'),
        (
          start: 'Fri, Jul 10, 22:30',
          end: 'Sat, Jul 11, 01:15',
          endNamesDay: true,
        ),
      );
    });

    test('the same day of another month or year is not the same day', () {
      expect(
        labels('2026-07-08T09:00:00', '2026-08-08T10:00:00').end,
        'Sat, Aug 8, 10:00',
      );
      expect(
        labels('2025-07-08T09:00:00', '2026-07-08T10:00:00').end,
        'Wed, Jul 8, 10:00',
      );
    });

    test('an end without a start carries its own day', () {
      expect(
        labels(null, '2026-07-08T12:30:00'),
        (start: null, end: 'Wed, Jul 8, 12:30', endNamesDay: true),
      );
    });

    test('an end after an unparseable start carries its own day', () {
      expect(
        labels('yesterday', '2026-07-08T12:30:00'),
        (start: 'yesterday', end: 'Wed, Jul 8, 12:30', endNamesDay: true),
      );
    });

    test('a start without an end leaves the end absent', () {
      expect(
        labels('2026-07-08T09:00:00', null),
        (start: 'Wed, Jul 8, 09:00', end: null, endNamesDay: false),
      );
    });

    test('an unparseable end is kept verbatim', () {
      expect(
        labels('2026-07-08T09:00:00', 'noon-ish'),
        (start: 'Wed, Jul 8, 09:00', end: 'noon-ish', endNamesDay: false),
      );
    });

    test('a timezone-qualified or date-only value is not an accepted '
        'timestamp, so it is kept verbatim rather than shifted', () {
      expect(
        labels('2026-07-08T09:00:00Z', '2026-07-08'),
        (
          start: '2026-07-08T09:00:00Z',
          end: '2026-07-08',
          endNamesDay: false,
        ),
      );
    });

    test('a non-string argument is absent, whatever it holds', () {
      expect(labels(42, false), (start: null, end: null, endNamesDay: false));
      expect(labels(null, null), (start: null, end: null, endNamesDay: false));
    });

    test('the end time alone follows the locale too', () {
      expect(
        labels('2026-07-08T09:00:00', '2026-07-08T12:30:00', locale: 'da'),
        (start: 'ons. 8. jul. 09.00', end: '12.30', endNamesDay: false),
      );
    });
  });
}
