import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/settings/ui/pages/outbox/sync_queue_count_format.dart';
import 'package:lotti/l10n/app_localizations.dart';

void main() {
  // The real English catalog, so the test exercises the same ARB entries the
  // app resolves rather than a stand-in pattern that could drift from them.
  late AppLocalizations messages;
  setUpAll(() async {
    messages = await AppLocalizations.delegate.load(const Locale('en'));
  });

  String format(int count) => formatSyncQueueCount(count, messages);

  group('formatSyncQueueCount below the thousands step', () {
    test('renders counts under 1000 exactly', () {
      expect(format(0), '0');
      expect(format(7), '7');
      expect(format(342), '342');
    });

    test('999 is the last exact value', () {
      expect(format(999), '999');
      expect(format(1000), '1K');
    });
  });

  group('formatSyncQueueCount thousands', () {
    test('drops a trailing .0 so a whole unit carries no fraction', () {
      expect(format(1000), '1K');
      expect(format(2000), '2K');
    });

    test('keeps one decimal below 10K', () {
      expect(format(1200), '1.2K');
      expect(format(9900), '9.9K');
    });

    test('rounds the hidden digits to the nearest tenth', () {
      expect(format(1249), '1.2K');
      expect(format(1250), '1.3K');
      expect(format(9949), '9.9K');
    });

    test('a half-tenth below the 10K step still reads as 9.9K', () {
      // 9950 / 1000 is not exactly 9.95 in binary — the nearest double sits
      // just below it, so this rounds down. Pinned because the arithmetic is
      // deterministic and the alternative reading ("10K") is the one a person
      // would guess.
      expect(format(9950), '9.9K');
    });

    test('carries into a whole unit when the decimal rounds up', () {
      // 9.999 → one decimal → 10.0 → the trailing .0 is then dropped, so the
      // 10K boundary is reached from below without printing "10.0K".
      expect(format(9999), '10K');
    });

    test('drops the decimal from 10K up, where a tenth is noise', () {
      expect(format(10000), '10K');
      expect(format(18342), '18K');
      expect(format(999499), '999K');
    });
  });

  group('formatSyncQueueCount millions', () {
    test('promotes before formatting so 1000K is never printed', () {
      expect(format(999500), '1M');
      expect(format(999999), '1M');
    });

    test('applies the same one-decimal shape to millions', () {
      expect(format(1000000), '1M');
      expect(format(1234567), '1.2M');
      expect(format(18000000), '18M');
    });
  });

  group('formatSyncQueueCount localization', () {
    test('takes the unit suffix from the catalog, not from a literal', () async {
      // Every shipped catalog must resolve the pattern — a locale missing the
      // entry would fall back to English silently, which is the failure this
      // guards. Asserting the digits survive is what proves the placeholder is
      // wired rather than the pattern being returned verbatim.
      for (final locale in AppLocalizations.supportedLocales) {
        final localized = await AppLocalizations.delegate.load(locale);
        final thousands = formatSyncQueueCount(18342, localized);
        final millions = formatSyncQueueCount(1234567, localized);

        expect(
          thousands,
          contains('18'),
          reason: '$locale dropped the value from the thousands pattern',
        );
        expect(
          millions,
          contains('1.2'),
          reason: '$locale dropped the value from the millions pattern',
        );
        expect(
          thousands,
          isNot(contains('{value}')),
          reason: '$locale left the placeholder unsubstituted',
        );
      }
    });

    test('keeps every catalog inside the row width budget', () async {
      // The suffix is translatable, so a future translation is where the
      // width guarantee would quietly break — a catalog switching to "Tsd."
      // widens the count and takes the space back from the Settings label.
      // Five characters is the budget the sidebar row was measured against.
      for (final locale in AppLocalizations.supportedLocales) {
        final localized = await AppLocalizations.delegate.load(locale);
        for (final count in [1000, 1200, 9999, 18342, 999499, 1234567]) {
          final formatted = formatSyncQueueCount(count, localized);
          expect(
            formatted.length,
            lessThanOrEqualTo(5),
            reason:
                '$locale formats $count as "$formatted", '
                'which exceeds the sidebar row budget',
          );
        }
      }
    });
  });

  group('formatSyncQueueCount width bound', () {
    // The formatter exists to keep the counts from taking the Settings label's
    // width. That guarantee is a property of the output length, so assert it
    // directly rather than trusting the examples above to be representative.
    test('never exceeds five characters across the plausible range', () {
      for (final count in [
        0,
        1,
        999,
        1000,
        1200,
        9999,
        10000,
        18342,
        999499,
        999500,
        1000000,
        1234567,
        999999999,
      ]) {
        expect(
          format(count).length,
          lessThanOrEqualTo(5),
          reason: '$count formatted to ${format(count)}',
        );
      }
    });

    test('is monotonic — a larger queue never formats to a shorter number', () {
      var previous = 0.0;
      for (var count = 0; count <= 2000000; count += 977) {
        final formatted = format(count);
        final magnitude = switch (formatted[formatted.length - 1]) {
          'K' => 1000.0,
          'M' => 1000000.0,
          _ => 1.0,
        };
        final digits = magnitude == 1.0
            ? formatted
            : formatted.substring(0, formatted.length - 1);
        final value = double.parse(digits) * magnitude;
        expect(
          value,
          greaterThanOrEqualTo(previous),
          reason: '$count formatted to $formatted, which decreased',
        );
        previous = value;
      }
    });
  });

  group('SyncQueueDirection', () {
    test('each direction carries the arrow that identifies it', () {
      expect(SyncQueueDirection.incoming.arrow, '↓');
      expect(SyncQueueDirection.outgoing.arrow, '↑');
    });

    test('the two directions are distinguishable to the reader', () {
      // The arrow is the only thing telling incoming from outgoing — the
      // counts themselves are interchangeable digits.
      expect(
        SyncQueueDirection.incoming.arrow,
        isNot(SyncQueueDirection.outgoing.arrow),
      );
    });
  });

  group('syncQueueArrowGap', () {
    test('is the narrow no-break space, not an ordinary word space', () {
      // The whole point of the character: a word space made the arrow read as
      // a separate token from its number. Pinned by codepoint because the two
      // are visually near-identical in a diff, so an accidental revert to
      // U+0020 would otherwise pass every other assertion here.
      expect(syncQueueArrowGap, ' ');
      expect(syncQueueArrowGap, isNot(' '));
    });

    test('is a single character, so it cannot smuggle in extra width', () {
      expect(syncQueueArrowGap.length, 1);
    });
  });

  group('formatSyncQueueLabel', () {
    test(
      'composes arrow, narrow no-break space and count for each direction',
      () {
        expect(
          formatSyncQueueLabel(SyncQueueDirection.incoming, 3, messages),
          '↓ 3',
        );
        expect(
          formatSyncQueueLabel(SyncQueueDirection.outgoing, 4, messages),
          '↑ 4',
        );
      },
    );

    test('separates the arrow from the count with nothing wider', () {
      // Guards the actual regression this change makes possible: someone
      // reinstating '↓ $count' at the call site would still render, just with
      // the loose gap the design moved away from.
      final label = formatSyncQueueLabel(
        SyncQueueDirection.incoming,
        18342,
        messages,
      );
      expect(label, isNot(contains(' ')));
      expect(label.substring(1, 2), syncQueueArrowGap);
    });

    test('carries the compacted count, not the raw figure', () {
      expect(
        formatSyncQueueLabel(SyncQueueDirection.incoming, 18342, messages),
        endsWith('18K'),
      );
      expect(
        formatSyncQueueLabel(SyncQueueDirection.outgoing, 1204, messages),
        endsWith('1.2K'),
      );
    });

    test('stays within the row budget the arrow and gap add to', () {
      // Five characters for the count, plus the arrow and the narrow no-break space.
      for (final count in [0, 999, 1000, 18342, 999500, 1234567]) {
        for (final direction in SyncQueueDirection.values) {
          final label = formatSyncQueueLabel(direction, count, messages);
          expect(
            label.length,
            lessThanOrEqualTo(7),
            reason: '$direction $count formatted to "$label"',
          );
        }
      }
    });

    test('keeps the arrow first, so direction is read before magnitude', () {
      for (final direction in SyncQueueDirection.values) {
        expect(
          formatSyncQueueLabel(direction, 42, messages),
          startsWith(direction.arrow),
        );
      }
    });
  });
}
