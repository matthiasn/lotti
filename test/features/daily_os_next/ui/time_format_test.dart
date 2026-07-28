import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/daily_os_next/ui/time_format.dart';

import '../../../widget_test_utils.dart';

void main() {
  group('formatMinutesCompact', () {
    test('formats minutes-only, whole-hour, and mixed durations', () {
      expect(formatMinutesCompact(0), '0m');
      expect(formatMinutesCompact(45), '45m');
      expect(formatMinutesCompact(60), '1h');
      expect(formatMinutesCompact(90), '1h 30m');
      expect(formatMinutesCompact(480), '8h');
    });

    test('negative durations keep a single leading sign', () {
      expect(formatMinutesCompact(-1), '-1m');
      expect(formatMinutesCompact(-60), '-1h');
      expect(formatMinutesCompact(-65), '-1h 5m');
    });

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(-24 * 60, 24 * 60 * 7),
      glados.ExploreConfig(numRuns: 120),
    ).test('round-trips back to the original minute count', (minutes) {
      final label = formatMinutesCompact(minutes);
      final match = RegExp(
        r'^(-)?(?:(\d+)h)?\s?(?:(\d+)m)?$',
      ).firstMatch(label);
      expect(match, isNotNull, reason: 'unparseable label "$label"');
      final sign = match!.group(1) == null ? 1 : -1;
      final hours = int.tryParse(match.group(2) ?? '') ?? 0;
      final mins = int.tryParse(match.group(3) ?? '') ?? 0;
      expect(
        sign * (hours * 60 + mins),
        minutes,
        reason: '"$label" should encode $minutes minutes',
      );
      final magnitude = minutes.abs();
      // Compact rule: no "0m" suffix on whole hours, no "0h" prefix.
      if (magnitude >= 60 && magnitude % 60 == 0) {
        expect(label.endsWith('h'), isTrue, reason: label);
      }
      if (magnitude < 60) {
        expect(label.contains('h'), isFalse, reason: label);
      }
    }, tags: 'glados');
  });

  group('formatClockRange', () {
    final start = DateTime(2026, 5, 26, 9, 14);
    final end = DateTime(2026, 5, 26, 10, 5);

    /// Resolves the range under an explicit device clock and app locale.
    ///
    /// The clock rides on the MediaQuery above the app (the platform half of
    /// [MediaQueryData]) exactly as the real device setting does; the locale
    /// is overridden inside it so both halves of the decision are controlled.
    Future<String> resolve(
      WidgetTester tester, {
      required bool use24Hour,
      Locale? locale,
    }) async {
      late String label;
      Widget probe = Builder(
        builder: (context) {
          label = formatClockRange(context, start, end);
          return const SizedBox.shrink();
        },
      );
      if (locale != null) {
        final inner = probe;
        probe = Builder(
          builder: (context) => Localizations.override(
            context: context,
            locale: locale,
            child: inner,
          ),
        );
      }
      await tester.pumpWidget(
        makeTestableWidget2(
          probe,
          mediaQueryData: phoneMediaQueryData.copyWith(
            alwaysUse24HourFormat: use24Hour,
          ),
        ),
      );
      await tester.pumpAndSettle();
      return label;
    }

    testWidgets('a 12-hour device keeps the AM/PM range', (tester) async {
      final label = await resolve(tester, use24Hour: false);

      expect(label, contains('9:14'));
      expect(label, contains('AM'));
      expect(label, isNot(contains('09:14')));
    });

    testWidgets('a 24-hour device drops AM/PM entirely', (tester) async {
      final label = await resolve(tester, use24Hour: true);

      // The bug: `DateFormat.jm('en_US')` is hard-wired to 12-hour, so a
      // block planned for 09:14–10:05 read back as "9:14 AM–10:05 AM" on a
      // 24-hour device no matter what the device was set to.
      expect(label, '09:14–10:05');
      expect(label, isNot(contains('AM')));
    });

    testWidgets('the same range renders differently under the two clocks', (
      tester,
    ) async {
      final twelveHour = await resolve(tester, use24Hour: false);
      final twentyFourHour = await resolve(tester, use24Hour: true);

      // Guards the whole point of the fix: before it the device setting made
      // no difference at all and these two were identical.
      expect(twelveHour, isNot(twentyFourHour));
    });

    testWidgets('a locale with no AM/PM form ignores a 12-hour device', (
      tester,
    ) async {
      final label = await resolve(
        tester,
        use24Hour: false,
        locale: const Locale('de'),
      );

      // German has no AM/PM form to fall back to, so the locale wins over the
      // device flag — the range must not be forced back into 12-hour.
      expect(label, '09:14–10:05');
    });

    testWidgets('separates the endpoints with an en dash, not a hyphen', (
      tester,
    ) async {
      final label = await resolve(tester, use24Hour: true);

      expect(label, contains('–'));
      expect(label, isNot(contains('-')));
    });
  });
}
