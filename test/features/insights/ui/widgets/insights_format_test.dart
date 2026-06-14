import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/insights/ui/widgets/insights_format.dart';

void main() {
  group('formatDurationCompact', () {
    test('renders minutes, whole hours, and mixed values', () {
      expect(formatDurationCompact(0), '0m');
      expect(formatDurationCompact(45 * 60), '45m');
      expect(formatDurationCompact(2 * 3600), '2h');
      expect(formatDurationCompact(2 * 3600 + 15 * 60), '2h 15m');
      expect(formatDurationCompact(59), '0m'); // sub-minute truncates
    });
  });

  group('formatDurationTable', () {
    test('zero-pads minutes with unbounded hours', () {
      expect(formatDurationTable(5 * 60), '0:05');
      expect(formatDurationTable(2 * 3600 + 15 * 60), '2:15');
      expect(formatDurationTable(134 * 3600 + 7 * 60), '134:07');
      expect(formatDurationTable(0), '0:00');
    });
  });

  group('formatShare', () {
    test('rounds percentages and floors tiny shares at <1%', () {
      expect(formatShare(0), '0%');
      expect(formatShare(0.004), '<1%');
      expect(formatShare(0.0099), '<1%');
      expect(formatShare(0.42), '42%');
      expect(formatShare(0.999), '100%');
      expect(formatShare(1), '100%');
    });
  });

  group('formatDurationWithDays', () {
    test('reads like compact below 100h', () {
      expect(formatDurationWithDays(0), '0m');
      expect(formatDurationWithDays(2 * 3600 + 15 * 60), '2h 15m');
      expect(formatDurationWithDays(99 * 3600), '99h');
    });

    test('rolls into days at and above 100h', () {
      // 100h = 4 days 4 hours.
      expect(formatDurationWithDays(100 * 3600), '4d 4h');
      // Whole days drop the hour component.
      expect(formatDurationWithDays(120 * 3600), '5d');
      // ~966h (the legacy hard-to-grasp case) becomes a legible day count.
      expect(formatDurationWithDays(966 * 3600 + 59 * 60), '40d 6h');
    });
  });

  group('formatAvgDuration', () {
    test('guards real-but-tiny averages and passes others through', () {
      expect(formatAvgDuration(0), '0:00');
      expect(formatAvgDuration(30), '<0:01');
      expect(formatAvgDuration(59), '<0:01');
      expect(formatAvgDuration(60), '0:01');
      expect(formatAvgDuration(3600), '1:00');
    });
  });

  glados.Glados<int>(glados.any.intInRange(0, 1000000)).test(
    'table format round-trips to the exact minute count',
    (seconds) {
      final formatted = formatDurationTable(seconds);
      final parts = formatted.split(':');
      final reconstructed = int.parse(parts[0]) * 60 + int.parse(parts[1]);
      expect(reconstructed, seconds ~/ 60);
      expect(parts[1].length, 2);
    },
    tags: 'glados',
  );

  glados.Glados<int>(glados.any.intInRange(0, 1000000)).test(
    'compact format conserves the minute count and never shows zero units',
    (seconds) {
      final formatted = formatDurationCompact(seconds);
      final minutes = seconds ~/ 60;
      final match = RegExp(
        r'^(?:(\d+)h)?\s?(?:(\d+)m)?$',
      ).firstMatch(formatted)!;
      final h = int.tryParse(match.group(1) ?? '') ?? 0;
      final m = int.tryParse(match.group(2) ?? '') ?? 0;
      expect(h * 60 + m, minutes);
      // "2h 0m" and "0h 15m" style zero components never appear (except
      // the bare "0m" for zero totals).
      if (minutes >= 60 && minutes % 60 == 0) {
        expect(formatted, '${minutes ~/ 60}h');
      }
      if (minutes > 0 && minutes < 60) {
        expect(formatted, '${minutes}m');
      }
    },
    tags: 'glados',
  );
}
