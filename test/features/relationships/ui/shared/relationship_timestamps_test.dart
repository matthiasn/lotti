// Explicit date/time components are the point of a timestamp-formatting test:
// `DateTime(2026, 8, 15, 9, 0)` reads as 09:00 on a specific day, while
// trimming the defaults leaves a bare hour that has to be decoded.
// ignore_for_file: avoid_redundant_argument_values

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';

void main() {
  final now = DateTime(2026, 8, 18, 14, 20);

  group('relationshipTimestampLabel', () {
    test('same day reads "Today HH:MM"', () {
      withClock(Clock.fixed(now), () {
        final earlier = DateTime(2026, 8, 18, 9, 5);
        expect(relationshipTimestampLabel(earlier), 'Today 09:05');
      });
    });

    // The most common non-today value on this surface: a check-in logged the
    // previous evening. Rendering it as a date makes the reader work out what
    // yesterday's date was.
    test('the previous calendar day reads "Yesterday HH:MM"', () {
      withClock(Clock.fixed(now), () {
        expect(
          relationshipTimestampLabel(DateTime(2026, 8, 17, 18)),
          'Yesterday 18:00',
        );
      });
    });

    // "Yesterday" is a calendar-day question, not a 24-hour one: 00:01 and
    // 23:59 yesterday are both yesterday, however many hours ago they were.
    test('yesterday holds across the whole calendar day', () {
      withClock(Clock.fixed(now), () {
        expect(
          relationshipTimestampLabel(DateTime(2026, 8, 17, 0, 1)),
          'Yesterday 00:01',
        );
        expect(
          relationshipTimestampLabel(DateTime(2026, 8, 17, 23, 59)),
          'Yesterday 23:59',
        );
      });
    });

    // The previous day is built from calendar components, so it crosses a
    // month boundary — and survives a DST shift, where subtracting 24 hours
    // can land back on the same date.
    test('yesterday crosses a month boundary', () {
      expect(
        relationshipTimestampLabel(
          DateTime(2026, 8, 31, 21, 30),
          now: DateTime(2026, 9, 1, 8),
        ),
        'Yesterday 21:30',
      );
    });

    test('two days back reads "Www D Mon HH:MM"', () {
      withClock(Clock.fixed(now), () {
        // 2026-08-16 is a Sunday — two days before the fixed now.
        expect(
          relationshipTimestampLabel(DateTime(2026, 8, 16, 19, 5)),
          'Sun 16 Aug 19:05',
        );
      });
    });

    test('a different day reads "Www D Mon HH:MM"', () {
      withClock(Clock.fixed(now), () {
        // 2026-08-21 is a Friday.
        final fri = DateTime(2026, 8, 21, 19, 5);
        expect(relationshipTimestampLabel(fri), 'Fri 21 Aug 19:05');
      });
    });

    test('honours an explicit now override', () {
      withClock(Clock.fixed(DateTime(2020, 1, 1)), () {
        // 2026-08-15 is a Saturday.
        final at = DateTime(2026, 8, 15, 19, 5);
        // A now on the next day is exactly the "Yesterday" case.
        expect(
          relationshipTimestampLabel(at, now: DateTime(2026, 8, 16, 8)),
          'Yesterday 19:05',
        );
        // Two days on, the date comes back.
        expect(
          relationshipTimestampLabel(at, now: DateTime(2026, 8, 17, 8)),
          'Sat 15 Aug 19:05',
        );
        // A now on the same day collapses to "Today".
        expect(
          relationshipTimestampLabel(at, now: DateTime(2026, 8, 15, 20)),
          'Today 19:05',
        );
      });
    });
  });

  group('relationshipTimeLabel', () {
    test('renders HH:MM with leading zeros', () {
      expect(relationshipTimeLabel(DateTime(2026, 8, 18, 7, 9)), '07:09');
      expect(relationshipTimeLabel(DateTime(2026, 8, 18, 14, 20)), '14:20');
    });
  });

  group('relationshipWeekdayLabel', () {
    test('returns the 3-letter weekday abbreviation', () {
      expect(relationshipWeekdayLabel(DateTime(2026, 8, 17)), 'Mon');
      expect(relationshipWeekdayLabel(DateTime(2026, 8, 18)), 'Tue');
      expect(relationshipWeekdayLabel(DateTime(2026, 8, 21)), 'Fri');
    });
  });

  group('cadenceDueDate', () {
    test('returns null when there is no cadence', () {
      expect(
        cadenceDueDate(
          lastCheckInAt: now,
          trackingStartedAt: now,
          cadenceDays: null,
        ),
        isNull,
      );
      expect(
        cadenceDueDate(
          lastCheckInAt: now,
          trackingStartedAt: now,
          cadenceDays: 0,
        ),
        isNull,
      );
    });

    test('is cadenceDays after the last check-in', () {
      withClock(Clock.fixed(now), () {
        final last = DateTime(2026, 8, 11, 10, 0);
        expect(
          cadenceDueDate(
            lastCheckInAt: last,
            trackingStartedAt: now,
            cadenceDays: 7,
          ),
          DateTime(2026, 8, 18, 10, 0),
        );
      });
    });

    test('falls back to tracking start when no check-in exists yet', () {
      withClock(Clock.fixed(now), () {
        final started = DateTime(2026, 8, 1, 9, 0);
        expect(
          cadenceDueDate(
            lastCheckInAt: null,
            trackingStartedAt: started,
            cadenceDays: 14,
          ),
          DateTime(2026, 8, 15, 9, 0),
        );
      });
    });

    test('falls back to now when neither date is known', () {
      withClock(Clock.fixed(now), () {
        expect(
          cadenceDueDate(
            lastCheckInAt: null,
            trackingStartedAt: null,
            cadenceDays: 7,
          ),
          now.add(const Duration(days: 7)),
        );
      });
    });
  });

  group('cadenceOverdueDays', () {
    test('null when there is no cadence', () {
      expect(
        cadenceOverdueDays(
          lastCheckInAt: now,
          trackingStartedAt: now,
          cadenceDays: null,
        ),
        isNull,
      );
    });

    test('positive when the cadence is overdue', () {
      withClock(Clock.fixed(now), () {
        // Last check-in 10 days ago with a weekly cadence → due 3 days ago.
        final overdue = cadenceOverdueDays(
          lastCheckInAt: DateTime(2026, 8, 8, 10, 0),
          trackingStartedAt: now,
          cadenceDays: 7,
        );
        expect(overdue, 3);
      });
    });

    test('negative when the cadence is still ahead', () {
      withClock(Clock.fixed(now), () {
        final ahead = cadenceOverdueDays(
          lastCheckInAt: DateTime(2026, 8, 16, 10, 0),
          trackingStartedAt: now,
          cadenceDays: 7,
        );
        expect(ahead, -5);
      });
    });

    test('zero on the due day', () {
      withClock(Clock.fixed(now), () {
        final due = cadenceOverdueDays(
          lastCheckInAt: DateTime(2026, 8, 11, 14, 20),
          trackingStartedAt: now,
          cadenceDays: 7,
        );
        expect(due, 0);
      });
    });
  });

  group('quietStreakDays', () {
    test('whole days since the last check-in', () {
      withClock(Clock.fixed(now), () {
        expect(
          quietStreakDays(
            lastCheckInAt: DateTime(2026, 8, 9, 10, 0),
            trackingStartedAt: now,
          ),
          9,
        );
      });
    });

    test('same-day check-in is 0, not 1', () {
      withClock(Clock.fixed(now), () {
        expect(
          quietStreakDays(
            lastCheckInAt: DateTime(2026, 8, 18, 6, 0),
            trackingStartedAt: now,
          ),
          0,
        );
      });
    });

    test('falls back to tracking start when no check-in exists', () {
      withClock(Clock.fixed(now), () {
        expect(
          quietStreakDays(
            lastCheckInAt: null,
            trackingStartedAt: DateTime(2026, 8, 9, 10, 0),
          ),
          9,
        );
      });
    });

    test('zero when neither date is known', () {
      withClock(Clock.fixed(now), () {
        expect(
          quietStreakDays(lastCheckInAt: null, trackingStartedAt: null),
          0,
        );
      });
    });

    test('never negative when the check-in is in the future', () {
      withClock(Clock.fixed(now), () {
        expect(
          quietStreakDays(
            lastCheckInAt: now.add(const Duration(days: 2)),
            trackingStartedAt: now,
          ),
          0,
        );
      });
    });
  });
}
