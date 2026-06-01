import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/ui/agent_date_format.dart';

void main() {
  group('formatAgentDateTime', () {
    test('formats date with zero-padded month, day, hour, minute', () {
      expect(
        formatAgentDateTime(DateTime(2024, 1, 5, 9, 3)),
        '2024-01-05 09:03',
      );
    });

    test('formats date with double-digit values', () {
      expect(
        formatAgentDateTime(DateTime(2024, 12, 31, 23, 59)),
        '2024-12-31 23:59',
      );
    });

    test('formats midnight as 00:00', () {
      expect(
        formatAgentDateTime(DateTime(2024, 6, 15)),
        '2024-06-15 00:00',
      );
    });

    test('ignores seconds', () {
      expect(
        formatAgentDateTime(DateTime(2024, 3, 15, 14, 30, 45)),
        '2024-03-15 14:30',
      );
    });

    glados.Glados(
      glados.any.generatedAgentDateTime,
      glados.ExploreConfig(numRuns: 160),
    ).test('formats generated date/time parts without seconds', (scenario) {
      expect(
        formatAgentDateTime(scenario.dateTime),
        scenario.expectedDateTime,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  group('formatAgentTimestamp', () {
    test('includes zero-padded seconds', () {
      expect(
        formatAgentTimestamp(DateTime(2024, 1, 5, 9, 3, 7)),
        '2024-01-05 09:03:07',
      );
    });

    test('formats all double-digit values', () {
      expect(
        formatAgentTimestamp(DateTime(2024, 12, 31, 23, 59, 59)),
        '2024-12-31 23:59:59',
      );
    });

    test('formats midnight with zero seconds', () {
      expect(
        formatAgentTimestamp(DateTime(2024, 6, 15)),
        '2024-06-15 00:00:00',
      );
    });

    glados.Glados(
      glados.any.generatedAgentDateTime,
      glados.ExploreConfig(numRuns: 160),
    ).test('formats generated timestamps with seconds', (scenario) {
      expect(
        formatAgentTimestamp(scenario.dateTime),
        scenario.expectedTimestamp,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });
}

class _GeneratedAgentDateTime {
  const _GeneratedAgentDateTime({
    required this.year,
    required this.month,
    required this.daySeed,
    required this.hour,
    required this.minute,
    required this.second,
  });

  final int year;
  final int month;
  final int daySeed;
  final int hour;
  final int minute;
  final int second;

  int get day => 1 + (daySeed % DateTime(year, month + 1, 0).day);

  DateTime get dateTime => DateTime(year, month, day, hour, minute, second);

  String get expectedDateTime =>
      '${_pad4(year)}-${_pad2(month)}-${_pad2(day)} '
      '${_pad2(hour)}:${_pad2(minute)}';

  String get expectedTimestamp => '$expectedDateTime:${_pad2(second)}';

  @override
  String toString() {
    return '_GeneratedAgentDateTime('
        'year: $year, '
        'month: $month, '
        'day: $day, '
        'hour: $hour, '
        'minute: $minute, '
        'second: $second)';
  }
}

String _pad2(int value) => value.toString().padLeft(2, '0');

String _pad4(int value) => value.toString().padLeft(4, '0');

extension _AnyAgentDateFormat on glados.Any {
  glados.Generator<_GeneratedAgentDateTime> get generatedAgentDateTime =>
      glados.CombinableAny(this).combine6(
        glados.IntAnys(this).intInRange(1, 9999),
        glados.IntAnys(this).intInRange(1, 12),
        glados.IntAnys(this).intInRange(0, 30),
        glados.IntAnys(this).intInRange(0, 23),
        glados.IntAnys(this).intInRange(0, 59),
        glados.IntAnys(this).intInRange(0, 59),
        (
          int year,
          int month,
          int daySeed,
          int hour,
          int minute,
          int second,
        ) => _GeneratedAgentDateTime(
          year: year,
          month: month,
          daySeed: daySeed,
          hour: hour,
          minute: minute,
          second: second,
        ),
      );
}
