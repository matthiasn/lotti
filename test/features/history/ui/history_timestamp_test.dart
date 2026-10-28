import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/features/history/ui/history_timestamp.dart';
import 'package:lotti/l10n/app_localizations_de.dart';
import 'package:lotti/l10n/app_localizations_en.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('de');
  });

  final now = DateTime(2026, 3, 15, 10);
  final en = AppLocalizationsEn();

  String label(DateTime at, {String locale = 'en'}) => historyTimestampLabel(
    at,
    now: now,
    messages: locale == 'de' ? AppLocalizationsDe() : en,
    locale: locale,
  );

  test('a visit today reads as today with the time', () {
    expect(label(DateTime(2026, 3, 15, 0, 5)), 'Today, 12:05 AM');
  });

  test('the calendar day before reads as yesterday, however recent', () {
    expect(label(DateTime(2026, 3, 14, 23, 59)), 'Yesterday, 11:59 PM');
    expect(label(DateTime(2026, 3, 14, 0, 1)), 'Yesterday, 12:01 AM');
  });

  test('earlier this year carries the date without the year', () {
    expect(label(DateTime(2026, 3, 13, 15, 45)), 'Mar 13 3:45 PM');
  });

  test('a previous year carries the year too', () {
    expect(label(DateTime(2025, 12, 31, 15, 45)), 'Dec 31, 2025 3:45 PM');
  });

  test('the clock and words follow the locale', () {
    expect(
      label(DateTime(2026, 3, 14, 15, 45), locale: 'de'),
      'Gestern, 15:45',
    );
  });

  test('yesterday across a month boundary', () {
    expect(
      historyTimestampLabel(
        DateTime(2026, 2, 28, 15, 45),
        now: DateTime(2026, 3, 1, 9),
        messages: en,
        locale: 'en',
      ),
      'Yesterday, 3:45 PM',
    );
  });
}
