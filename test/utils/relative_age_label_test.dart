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
}
