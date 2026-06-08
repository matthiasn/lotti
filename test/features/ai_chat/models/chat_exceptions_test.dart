import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/models/chat_exceptions.dart';

// File-level helper to exercise base toString implementation.
class _BasicChatException extends ChatException {
  const _BasicChatException(super.message);
}

void main() {
  group('ChatException', () {
    group('ChatRepositoryException', () {
      test('creates exception with message only', () {
        const exception = ChatRepositoryException('Test message');

        expect(exception.message, equals('Test message'));
        expect(exception.cause, isNull);
        expect(
          exception.toString(),
          equals('ChatRepositoryException: Test message'),
        );
      });

      test('creates exception with message and cause', () {
        final originalError = Exception('Original error');
        final exception = ChatRepositoryException(
          'Test message',
          originalError,
        );

        expect(exception.message, equals('Test message'));
        expect(exception.cause, equals(originalError));
        expect(
          exception.toString(),
          equals('ChatRepositoryException: Test message'),
        );
      });
    });

    test('ChatException base toString formats message', () {
      const ex = _BasicChatException('base message');
      expect(ex.toString(), 'ChatException: base message');
    });
  });
}
