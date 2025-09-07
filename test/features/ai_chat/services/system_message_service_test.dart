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
  });
}
