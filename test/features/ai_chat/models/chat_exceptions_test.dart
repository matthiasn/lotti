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
        expect(exception.toString(),
            equals('ChatRepositoryException: Test message'));
      });

      test('creates exception with message and cause', () {
        final originalError = Exception('Original error');
        final exception =
            ChatRepositoryException('Test message', originalError);

        expect(exception.message, equals('Test message'));
        expect(exception.cause, equals(originalError));
        expect(exception.toString(),
            equals('ChatRepositoryException: Test message'));
      });

      test('is a ChatException', () {
        const exception = ChatRepositoryException('Test message');
        expect(exception, isA<ChatException>());
      });

      test('is an Exception', () {
        const exception = ChatRepositoryException('Test message');
        expect(exception, isA<Exception>());
      });
    });

    group('ChatProcessingException', () {
      test('creates exception with correct type and message', () {
        const exception = ChatProcessingException('Processing failed');

        expect(exception.message, equals('Processing failed'));
        expect(exception.toString(),
            equals('ChatProcessingException: Processing failed'));
        expect(exception, isA<ChatException>());
      });

      test('accepts optional cause', () {
        final cause = StateError('boom');
        final exception = ChatProcessingException('Processing failed', cause);
        expect(exception.cause, same(cause));
        expect(exception.toString(),
            equals('ChatProcessingException: Processing failed'));
      });
    });

    group('ChatToolException', () {
      test('creates exception with correct type and message', () {
        const exception = ChatToolException('Tool call failed');

        expect(exception.message, equals('Tool call failed'));
        expect(exception.toString(),
            equals('ChatToolException: Tool call failed'));
        expect(exception, isA<ChatException>());
      });

      test('accepts optional cause', () {
        final cause = ArgumentError('bad');
        final exception = ChatToolException('Tool call failed', cause);
        expect(exception.cause, same(cause));
        expect(exception.toString(), 'ChatToolException: Tool call failed');
      });
    });

    test('ChatException base toString formats message', () {
      const ex = _BasicChatException('base message');
      expect(ex.toString(), 'ChatException: base message');
    });
  });
}
