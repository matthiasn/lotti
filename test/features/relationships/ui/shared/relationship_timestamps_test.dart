// Explicit date/time components are the point of a timestamp-formatting test:
// `DateTime(2026, 8, 15, 9, 0)` reads as 09:00 on a specific day, while
// trimming the defaults leaves a bare hour that has to be decoded.
// ignore_for_file: avoid_redundant_argument_values

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/features/design_system/theme/design_tokens.dart';
import 'package:lotti/features/relationships/ui/shared/relationship_timestamps.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/themes/legacy_material_bridge.dart';
import 'package:material_ui/material_ui.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;


void main() {
  final now = DateTime(2026, 8, 18, 14, 20);

  setUpAll(initializeDateFormatting);
  setUpAll(tz_data.initializeTimeZones);

  // The relative words are the caller's to supply — every case below reads
  // them in English so the assertions stay legible; the locale-specific
  // behaviour has its own cases at the end.
  String label(DateTime at, {DateTime? now, String? locale}) =>
      relationshipTimestampLabel(
        at,
        todayLabel: 'Today',
        yesterdayLabel: 'Yesterday',
        locale: locale,
        now: now,
      );

  group('relationshipTimestampLabel', () {
    test('same day reads "Today HH:MM"', () {
      withClock(Clock.fixed(now), () {
        final earlier = DateTime(2026, 8, 18, 9, 5);
        expect(label(earlier), 'Today 09:05');
      });
    });

    // The most common non-today value on this surface: a check-in logged the
    // previous evening. Rendering it as a date makes the reader work out what
    // yesterday's date was.
    test('the previous calendar day reads "Yesterday HH:MM"', () {
      withClock(Clock.fixed(now), () {
        expect(
          label(DateTime(2026, 8, 17, 18)),
          'Yesterday 18:00',
        );
      });
    });

    // "Yesterday" is a calendar-day question, not a 24-hour one: 00:01 and
    // 23:59 yesterday are both yesterday, however many hours ago they were.
    test('yesterday holds across the whole calendar day', () {
      withClock(Clock.fixed(now), () {
        expect(
          label(DateTime(2026, 8, 17, 0, 1)),
          'Yesterday 00:01',
        );
        expect(
          label(DateTime(2026, 8, 17, 23, 59)),
          'Yesterday 23:59',
        );
      });
    });

    // The previous day is built from calendar components, so it crosses a
    // month boundary — and survives a DST shift, where subtracting 24 hours
    // can land back on the same date.
    test('yesterday crosses a month boundary', () {
      expect(
        label(
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
          label(DateTime(2026, 8, 16, 19, 5)),
          'Sun 16 Aug 19:05',
        );
      });
    });

    test('a different day reads "Www D Mon HH:MM"', () {
      withClock(Clock.fixed(now), () {
        // 2026-08-21 is a Friday.
        final fri = DateTime(2026, 8, 21, 19, 5);
        expect(label(fri), 'Fri 21 Aug 19:05');
      });
    });

    test('honours an explicit now override', () {
      withClock(Clock.fixed(DateTime(2020, 1, 1)), () {
        // 2026-08-15 is a Saturday.
        final at = DateTime(2026, 8, 15, 19, 5);
        // A now on the next day is exactly the "Yesterday" case.
        expect(
          label(at, now: DateTime(2026, 8, 16, 8)),
          'Yesterday 19:05',
        );
        // Two days on, the date comes back.
        expect(
          label(at, now: DateTime(2026, 8, 17, 8)),
          'Sat 15 Aug 19:05',
        );
        // A now on the same day collapses to "Today".
        expect(
          label(at, now: DateTime(2026, 8, 15, 20)),
          'Today 19:05',
        );
      });
    });
  });

  group('relationshipTimeLabel', () {
    test("is the feature's 24h clock, a pure function of the time — no "
        'device or locale input, so a chip and the note stamp under it '
        'speak one dialect', () {
      expect(relationshipTimeLabel(DateTime(2026, 8, 18, 14, 5)), '14:05');
      expect(relationshipTimeLabel(DateTime(2026, 8, 18, 9, 7)), '09:07');
      expect(relationshipTimeLabel(DateTime(2026, 8, 18)), '00:00');
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

    test('is the calendar day cadenceDays after the last check-in, at '
        'local midnight — a day, not an instant', () {
      withClock(Clock.fixed(now), () {
        final last = DateTime(2026, 8, 11, 10, 0);
        expect(
          cadenceDueDate(
            lastCheckInAt: last,
            trackingStartedAt: now,
            cadenceDays: 7,
          ),
          DateTime(2026, 8, 18),
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
          DateTime(2026, 8, 15),
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
          DateTime(2026, 8, 25),
        );
      });
    });

    test('counts days on the calendar, not hours: a DST transition in the '
        'week does not move the due day', () {
      // Berlin springs forward on 2026-03-29. Seven times twenty-four hours
      // after 23:30 on the 22nd is 00:30 on the 30th; the calendar says the
      // 29th — the day the agent derives too (`deriveCadenceFacts`).
      final late = tz.TZDateTime(
        tz.getLocation('Europe/Berlin'),
        2026,
        3,
        22,
        23,
        30,
      );
      withClock(Clock.fixed(now), () {
        expect(
          cadenceDueDate(
            lastCheckInAt: late,
            trackingStartedAt: now,
            cadenceDays: 7,
          ),
          DateTime(2026, 3, 29),
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

    test('the 23-hour day of a spring-forward counts as one day over, not '
        'zero', () {
      // Due on the 29th, the day Berlin springs forward; read on the 30th.
      // Local midnights 23 hours apart floor to zero days, which read "due
      // today" for a person a day over — on a host whose own zone switches
      // that night. Correct everywhere, discriminating off UTC.
      final berlin = tz.getLocation('Europe/Berlin');
      withClock(Clock.fixed(tz.TZDateTime(berlin, 2026, 3, 30, 10)), () {
        final over = cadenceOverdueDays(
          lastCheckInAt: tz.TZDateTime(berlin, 2026, 3, 22, 10),
          trackingStartedAt: null,
          cadenceDays: 7,
        );
        expect(over, 1);
      });
    });
  });

  group('locale', () {
    // The abbreviations used to be a hard-coded English table, which read as
    // "Fri 21 Aug" to a German reader looking at an otherwise German screen.
    test('the weekday and month abbreviations follow the locale', () {
      final at = DateTime(2026, 8, 21, 19, 5);

      expect(label(at, now: DateTime(2026, 8, 24, 9)), 'Fri 21 Aug 19:05');
      expect(
        label(at, now: DateTime(2026, 8, 24, 9), locale: 'de'),
        'Fr. 21 Aug. 19:05',
      );
      expect(
        label(at, now: DateTime(2026, 8, 24, 9), locale: 'fr'),
        'ven. 21 août 19:05',
      );
    });

    test('the cadence pill weekday follows the locale too', () {
      expect(relationshipWeekdayLabel(DateTime(2026, 8, 20)), 'Thu');
      expect(
        relationshipWeekdayLabel(DateTime(2026, 8, 20), locale: 'de'),
        'Do',
      );
    });

    // The time stays 24h in every locale: a mono column that switches to
    // "7:05 PM" in one language stops lining up (design plan §0.5).
    test('the time component stays 24h regardless of locale', () {
      final at = DateTime(2026, 8, 21, 19, 5);

      for (final locale in ['en', 'de', 'fr', 'sv']) {
        expect(
          label(at, now: DateTime(2026, 8, 24, 9), locale: locale),
          endsWith('19:05'),
          reason: '$locale must not fall back to a 12h clock',
        );
      }
    });
  });

  group('the context-resolved wrappers', () {
    Future<String> labelIn(WidgetTester tester, Locale locale) async {
      late String rendered;
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              rendered = relationshipTimestampLabelOf(
                context,
                DateTime(2026, 8, 17, 18),
                now: now,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return rendered;
    }

    testWidgets('read the relative day word off the widget tree', (
      tester,
    ) async {
      expect(await labelIn(tester, const Locale('en')), 'Yesterday 18:00');
      expect(await labelIn(tester, const Locale('de')), 'Gestern 18:00');
    });

    testWidgets('the weekday wrapper resolves the locale as well', (
      tester,
    ) async {
      late String rendered;
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          locale: const Locale('de'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              rendered = relationshipWeekdayLabelOf(
                context,
                DateTime(2026, 8, 20),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(rendered, 'Do');
    });
  });

  group('relationshipTimestampStyle', () {
    const tokens = dsTokensDark;

    test('is the caption token with tabular figures and the low-emphasis '
        'ink when the caller has no host line — and no monospace face', () {
      final style = relationshipTimestampStyle(tokens);
      expect(style.fontSize, tokens.typography.styles.others.caption.fontSize);
      expect(style.color, tokens.colors.text.lowEmphasis);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
      expect(style.fontFamily, isNot('Inconsolata'));
    });

    test('inside a line of prose it keeps the host size and takes the '
        "caller's colour — only the figures change", () {
      final host = tokens.typography.styles.body.bodyLarge;
      final style = relationshipTimestampStyle(
        tokens,
        base: host,
        color: tokens.colors.text.highEmphasis,
      );
      expect(style.fontSize, host.fontSize);
      expect(style.fontWeight, host.fontWeight);
      expect(style.color, tokens.colors.text.highEmphasis);
      expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    });
  });

  group('relationshipDurationLabelOf', () {
    Future<String?> labelFor(WidgetTester tester, Duration duration) async {
      late String? rendered;
      await tester.pumpWidget(
        MaterialApp(
          builder: LegacyMaterialBridge.builder,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            ...GlobalMaterialLocalizations.delegates,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              rendered = relationshipDurationLabelOf(context, duration);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      return rendered;
    }

    testWidgets('nothing for a zero or negative duration — a check-in with '
        'no length shows no duration at all', (tester) async {
      expect(await labelFor(tester, Duration.zero), isNull);
      expect(await labelFor(tester, const Duration(minutes: -5)), isNull);
    });

    testWidgets('minutes under an hour', (tester) async {
      expect(await labelFor(tester, const Duration(minutes: 11)), '11 min');
      expect(await labelFor(tester, const Duration(minutes: 59)), '59 min');
    });

    testWidgets('whole hours', (tester) async {
      expect(await labelFor(tester, const Duration(hours: 1)), '1 h');
      expect(await labelFor(tester, const Duration(hours: 3)), '3 h');
    });

    testWidgets('hours and minutes, minutes zero-padded', (tester) async {
      expect(
        await labelFor(tester, const Duration(hours: 1, minutes: 5)),
        '1 h 05',
      );
      expect(
        await labelFor(tester, const Duration(hours: 2, minutes: 30)),
        '2 h 30',
      );
    });

    testWidgets('seconds do not round up', (tester) async {
      expect(await labelFor(tester, const Duration(seconds: 59)), isNull);
      expect(
        await labelFor(tester, const Duration(minutes: 10, seconds: 59)),
        '10 min',
      );
    });
  });
}
