import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/services/system_message_service.dart';

void main() {
  group('SystemMessageService', () {
    test('provider returns a usable instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final service = container.read(systemMessageServiceProvider);
      expect(service, isA<SystemMessageService>());
    });

    test('getSystemMessage includes today date and guidance text', () {
      final service = SystemMessageService();
      final message = service.getSystemMessage();

      // Contains a YYYY-MM-DD date (today)
      final dateRegex = RegExp(r'\b\d{4}-\d{2}-\d{2}\b');
      expect(dateRegex.hasMatch(message), isTrue);

      // Contains tool usage guidance
      expect(message, contains('get_task_summaries'));

      // Contains time-based guidelines
      expect(message, contains('today'));
      expect(message, contains('yesterday'));
      expect(message, contains('this week'));
      expect(message, contains('recently'));
      expect(message, contains('this month'));
      expect(message, contains('last week'));
      expect(message, contains('last month'));

      // Contains ISO 8601 timestamp examples guidance
      expect(message, contains('start_date'));
      expect(message, contains('end_date'));

      // Non-empty and multi-line
      expect(message.trim(), isNotEmpty);
      expect(message.split('\n').length, greaterThan(5));
    });

    test('getSystemMessage resolves all date windows from the injected '
        'clock', () {
      // Friday 2024-03-15, anchoring every relative window deterministically.
      final service = SystemMessageService(now: () => DateTime(2024, 3, 15));
      final message = service.getSystemMessage();

      // Today / yesterday.
      expect(message, contains('Today (local) is 2024-03-15'));
      expect(message, contains('"today" = [2024-03-15, 2024-03-15]'));
      expect(message, contains('"yesterday" = [2024-03-14, 2024-03-14]'));

      // Calendar week (Monday 03-11 .. Sunday 03-17) and the prior week.
      expect(
        message,
        contains(
          '"this week" = current calendar week (default Monday–Sunday): '
          '[2024-03-11, 2024-03-17]',
        ),
      );
      expect(
        message,
        contains(
          '"last week" = previous calendar week: '
          '[2024-03-04, 2024-03-10]',
        ),
      );

      // Month boundaries — February 2024 is a leap month (ends on the 29th).
      expect(message, contains('"this month" = [2024-03-01, 2024-03-31]'));
      expect(message, contains('"last month" = [2024-02-01, 2024-02-29]'));

      // "recently" = trailing 14 local days inclusive (03-02 .. 03-15).
      expect(message, contains('[2024-03-02, 2024-03-15]'));

      // Month-only example windows. July's example is anchored to the current
      // year; December's uses the prior year because month 12 is still ahead of
      // the current month (3), matching the "not yet occurred → previous year"
      // rule the prompt documents.
      expect(message, contains('"July" → [2024-07-01, 2024-07-31]'));
      expect(message, contains('"December" → [2023-12-01, 2023-12-31]'));

      // Concrete example JSON uses yesterday's date.
      expect(
        message,
        contains('{"start_date":"2024-03-14","end_date":"2024-03-14"'),
      );
    });
  });
}
