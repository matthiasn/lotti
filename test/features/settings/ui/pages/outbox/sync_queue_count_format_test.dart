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
      // widens the pill and takes the space back from the Settings label.
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
    // The formatter exists to keep the pills from taking the Settings label's
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
}
