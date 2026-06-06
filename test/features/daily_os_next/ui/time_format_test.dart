import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:intl/intl.dart';
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

    glados.Glados(
      glados.IntAnys(glados.any).intInRange(0, 24 * 60 * 7),
      glados.ExploreConfig(numRuns: 120),
    ).test('round-trips back to the original minute count', (minutes) {
      final label = formatMinutesCompact(minutes);
      final match = RegExp(r'^(?:(\d+)h)?\s?(?:(\d+)m)?$').firstMatch(label);
      expect(match, isNotNull, reason: 'unparseable label "$label"');
      final hours = int.tryParse(match!.group(1) ?? '') ?? 0;
      final mins = int.tryParse(match.group(2) ?? '') ?? 0;
      expect(
        hours * 60 + mins,
        minutes,
        reason: '"$label" should encode $minutes minutes',
      );
      // Compact rule: no "0m" suffix on whole hours, no "0h" prefix.
      if (minutes >= 60 && minutes % 60 == 0) {
        expect(label.endsWith('h'), isTrue, reason: label);
      }
      if (minutes < 60) {
        expect(label.contains('h'), isFalse, reason: label);
      }
    }, tags: 'glados');
  });

  group('formatClockRange', () {
    testWidgets('formats a locale-aware en-dash separated range', (
      tester,
    ) async {
      late String label;
      await tester.pumpWidget(
        makeTestableWidget2(
          Builder(
            builder: (context) {
              label = formatClockRange(
                context,
                DateTime(2026, 5, 26, 9, 14),
                DateTime(2026, 5, 26, 10, 5),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      final formatter = DateFormat.jm('en_US');
      final expected =
          '${formatter.format(DateTime(2026, 5, 26, 9, 14))}–'
          '${formatter.format(DateTime(2026, 5, 26, 10, 5))}';
      expect(label, expected);
    });
  });
}
