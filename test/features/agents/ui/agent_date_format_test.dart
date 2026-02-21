import 'package:flutter_test/flutter_test.dart';
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
  });
}
