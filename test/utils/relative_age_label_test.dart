import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/utils/relative_age_label.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late AppLocalizations messages;

  setUpAll(() async {
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
}
