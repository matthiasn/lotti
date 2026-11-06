import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lotti/utils/device_datetime.dart';
import 'package:material_ui/material_ui.dart';

import '../widget_test_utils.dart';

void main() {
  final at = DateTime(2026, 9, 20, 19, 8);

  /// Renders [build] under an app whose language is English, so every
  /// assertion below is about what the DEVICE contributes.
  Future<String> englishApp(
    WidgetTester tester,
    String Function(BuildContext context) build, {
    bool use24Hour = false,
  }) async {
    late String result;
    await tester.pumpWidget(
      makeTestableWidget(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(alwaysUse24HourFormat: use24Hour),
            child: Builder(
              builder: (inner) {
                result = build(inner);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    return result;
  }

  void onDevice(WidgetTester tester, Locale locale) {
    tester.platformDispatcher.localeTestValue = locale;
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
  }

  group('deviceFormatLocale', () {
    // intl files symbols under the closest name it has, so `de_DE` resolves
    // to `de`. A bare DateFormat.localeExists('de_DE') answers false, and the
    // fallback then hands a German phone English dates — the bug this
    // resolution exists to avoid.
    testWidgets('resolves a region the way intl stores it', (tester) async {
      await initializeDateFormatting('de_DE');
      onDevice(tester, const Locale('de', 'DE'));

      expect(await englishApp(tester, deviceFormatLocale), 'de');
    });

    testWidgets('falls back to the app when the device has no data', (
      tester,
    ) async {
      // A locale intl has never heard of.
      onDevice(tester, const Locale('zz', 'ZZ'));

      expect(await englishApp(tester, deviceFormatLocale), 'en');
    });
  });

  group('deviceDateLabel', () {
    testWidgets('takes the order from the phone, not the app', (tester) async {
      await initializeDateFormatting('de_DE');
      onDevice(tester, const Locale('de', 'DE'));

      expect(
        await englishApp(tester, (context) => deviceDateLabel(context, at)),
        '20.9.2026',
      );
    });

    testWidgets('an English phone still reads month first', (tester) async {
      onDevice(tester, const Locale('en', 'US'));

      expect(
        await englishApp(tester, (context) => deviceDateLabel(context, at)),
        '9/20/2026',
      );
    });
  });

  group('deviceClockLabel', () {
    // DateFormat.jm('en_US') is hard-wired to 12-hour, so this is the half
    // the locale alone cannot answer.
    testWidgets('a 24-hour phone gets a 24-hour clock', (tester) async {
      onDevice(tester, const Locale('en', 'US'));

      expect(
        await englishApp(
          tester,
          (context) => deviceClockLabel(context, at),
          use24Hour: true,
        ),
        '19:08',
      );
    });

    testWidgets('a 12-hour phone keeps the meridiem', (tester) async {
      onDevice(tester, const Locale('en', 'US'));

      final label = await englishApp(
        tester,
        (context) => deviceClockLabel(context, at),
      );

      expect(label, contains('7:08'));
      expect(label, contains('PM'));
    });
  });

  // The case that started this: an English app on a German phone.
  testWidgets('deviceTimestampLabel reads as the phone would write it', (
    tester,
  ) async {
    await initializeDateFormatting('de_DE');
    onDevice(tester, const Locale('de', 'DE'));

    expect(
      await englishApp(
        tester,
        (context) => deviceTimestampLabel(context, at),
        use24Hour: true,
      ),
      '20.9.2026 19:08',
    );
  });

  group('replaceIsoDays', () {
    String marked(DateTime day) => '<${day.month}/${day.day}>';

    test('writes each real ISO day as the format does', () {
      expect(
        replaceIsoDays('Due 2026-03-17, and 2026-12-01.', marked),
        'Due <3/17>, and <12/1>.',
      );
    });

    test('leaves a day that does not exist, a longer number and a link '
        'target alone', () {
      const text =
          '2026-02-30 2026-13-01 12026-03-17 2026-03-17-1 '
          '[the 2026-03-17 note](https://example.com/2026-03-17)';
      expect(
        replaceIsoDays(text, marked),
        '2026-02-30 2026-13-01 12026-03-17 2026-03-17-1 '
        '[the <3/17> note](https://example.com/2026-03-17)',
      );
    });

    test('leaves a date in any URL alone: a target with parentheses, an '
        'autolink, a bare one', () {
      const text =
          '[log](https://example.com/(wiki)/2026-03-17) '
          '<https://example.com/2026-03-17> '
          'https://example.com/2026-03-17 on 2026-03-17';
      expect(
        replaceIsoDays(text, marked),
        '[log](https://example.com/(wiki)/2026-03-17) '
        '<https://example.com/2026-03-17> '
        'https://example.com/2026-03-17 on <3/17>',
      );
    });
  });
}
