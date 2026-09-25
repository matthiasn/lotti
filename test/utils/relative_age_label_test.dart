import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late AppLocalizations messages;

  setUpAll(() async {
    // In the app the localization delegates load the date symbols; a bare
    // unit test has to do it itself.
    await initializeDateFormatting();
    messages = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('under a minute is "just now"', () {
    expect(relativeAgoLabel(messages, Duration.zero), 'just now');
    expect(relativeAgoLabel(messages, const Duration(seconds: 59)), 'just now');
  });

  test('under an hour counts minutes', () {
    expect(relativeAgoLabel(messages, const Duration(minutes: 1)), '1 min ago');
    expect(
      relativeAgoLabel(messages, const Duration(minutes: 59, seconds: 30)),
      '59 min ago',
    );
  });

  test('under a day counts hours', () {
    expect(relativeAgoLabel(messages, const Duration(hours: 1)), '1 h ago');
    expect(
      relativeAgoLabel(messages, const Duration(hours: 23, minutes: 59)),
      '23 h ago',
    );
  });

  test('from a day on counts days', () {
    expect(relativeAgoLabel(messages, const Duration(days: 1)), '1 day ago');
    expect(relativeAgoLabel(messages, const Duration(days: 12)), '12 days ago');
  });

  group('relativeAgeOrDateLabel', () {
    final now = DateTime(2026, 9, 25, 12);

    test('is relative for the first week', () {
      expect(
        relativeAgeOrDateLabel(
          messages,
          at: now.subtract(const Duration(minutes: 20)),
          now: now,
        ),
        '20 min ago',
      );
      expect(
        relativeAgeOrDateLabel(
          messages,
          at: now.subtract(const Duration(days: 6, hours: 23)),
          now: now,
        ),
        '6 days ago',
      );
    });

    test(
      'names the date from a week on, with the year only when it differs',
      () {
        expect(
          relativeAgeOrDateLabel(
            messages,
            at: now.subtract(relativeAgeDateThreshold),
            now: now,
          ),
          'Sep 18',
        );
        expect(
          relativeAgeOrDateLabel(
            messages,
            at: DateTime(2025, 12, 30),
            now: now,
          ),
          'Dec 30, 2025',
        );
      },
    );

    test('follows the catalog locale', () async {
      final german = await AppLocalizations.delegate.load(const Locale('de'));
      expect(
        relativeAgeOrDateLabel(german, at: DateTime(2026, 9, 2), now: now),
        '2. Sept.',
      );
    });
  });

  group('untilNextAgeBucket', () {
    test('within the first hour, the next minute boundary plus a second', () {
      expect(
        untilNextAgeBucket(const Duration(seconds: 58)),
        const Duration(seconds: 3),
      );
      expect(
        untilNextAgeBucket(const Duration(minutes: 3, seconds: 10)),
        const Duration(seconds: 51),
      );
    });

    test('within the first day, the next hour boundary', () {
      expect(
        untilNextAgeBucket(const Duration(hours: 1, minutes: 59)),
        const Duration(seconds: 61),
      );
    });

    test('from a day on, the next day boundary', () {
      expect(
        untilNextAgeBucket(const Duration(days: 2, hours: 23)),
        const Duration(hours: 1, seconds: 1),
      );
    });

    test('the wait always lands in the next bucket', () {
      for (final age in [
        const Duration(seconds: 1),
        const Duration(seconds: 59),
        const Duration(minutes: 59, seconds: 59),
        const Duration(hours: 5),
        const Duration(days: 1),
      ]) {
        final before = relativeAgoLabel(messages, age);
        final after = relativeAgoLabel(messages, age + untilNextAgeBucket(age));
        expect(after, isNot(before), reason: '$age');
      }
    });
  });

  group('untilNextAgeBucket properties', () {
    // Ages up to three days, with sub-second jitter, and biased to the
    // minute, hour and day boundaries.
    final age = glados.any.combine2(
      glados.any.oneOf([
        glados.any.intInRange(0, 3 * 86400),
        glados.any.choose([0, 59, 60, 3599, 3600, 86399, 86400]),
      ]),
      glados.any.intInRange(0, 1000),
      (int seconds, int millis) =>
          Duration(seconds: seconds, milliseconds: millis),
    );

    glados.Glados(age, glados.ExploreConfig(numRuns: 400)).test(
      'the label holds until the next boundary and changes by the deadline',
      (a) {
        final wait = untilNextAgeBucket(a);
        final label = relativeAgoLabel(messages, a);
        expect(wait, greaterThan(Duration.zero));
        expect(wait, lessThanOrEqualTo(const Duration(days: 1, seconds: 1)));

        // The boundary sits one second of slack before the deadline, less
        // the sub-second part of the age the bucket arithmetic ignores.
        final boundary =
            a +
            wait -
            const Duration(seconds: 1) -
            Duration(microseconds: a.inMicroseconds % 1000000);
        expect(
          relativeAgoLabel(
            messages,
            boundary - const Duration(microseconds: 1),
          ),
          label,
        );
        expect(relativeAgoLabel(messages, boundary), isNot(label));
        expect(relativeAgoLabel(messages, a + wait), isNot(label));
      },
      tags: 'glados',
    );
  });
}
