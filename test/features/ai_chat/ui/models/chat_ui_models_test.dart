import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';

void main() {
  group('ChatSessionUiModel', () {
    group('factory constructors', () {
      test('empty creates model with default values', () {
        final model = ChatSessionUiModel.empty();

        expect(model.id, equals(''));
        expect(model.title, equals('New Chat'));
        expect(model.messages, isEmpty);
        expect(model.isLoading, isFalse);
        expect(model.isStreaming, isFalse);
        expect(model.error, isNull);
        expect(model.streamingMessageId, isNull);
      });

      test('fromDomain creates model from domain ChatSession', () {
        final domainSession = ChatSession(
          id: 'test-id',
          title: 'Test Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [
            ChatMessage.user('Hello'),
            ChatMessage.assistant('Hi there'),
          ],
        );

        final model = ChatSessionUiModel.fromDomain(domainSession);

        expect(model.id, equals('test-id'));
        expect(model.title, equals('Test Chat'));
        expect(model.messages.length, equals(2));
        expect(model.isLoading, isFalse);
        expect(model.isStreaming, isFalse);
        expect(model.error, isNull);
        expect(model.streamingMessageId, isNull);
      });

      test('fromDomain accepts optional presentation parameters', () {
        final domainSession = ChatSession(
          id: 'test-id',
          title: 'Test Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
        );

        final model = ChatSessionUiModel.fromDomain(
          domainSession,
          isLoading: true,
          isStreaming: true,
          error: 'Test error',
          streamingMessageId: 'msg-123',
        );

        expect(model.isLoading, isTrue);
        expect(model.isStreaming, isTrue);
        expect(model.error, equals('Test error'));
        expect(model.streamingMessageId, equals('msg-123'));
      });
    });

    group('copyWith', () {
      test('returns new instance with updated values', () {
        final original = ChatSessionUiModel.empty();

        final updated = original.copyWith(
          id: 'new-id',
          title: 'Updated Title',
          isLoading: true,
          error: 'Error occurred',
        );

        expect(updated.id, equals('new-id'));
        expect(updated.title, equals('Updated Title'));
        expect(updated.isLoading, isTrue);
        expect(updated.error, equals('Error occurred'));
        expect(updated.messages, equals(original.messages));
        expect(updated.isStreaming, equals(original.isStreaming));
      });

      test('maintains original values when not specified', () {
        final original = ChatSessionUiModel.fromDomain(
          ChatSession(
            id: 'original-id',
            title: 'Original Title',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [ChatMessage.user('Hello')],
          ),
          isLoading: true,
        );

        final updated = original.copyWith(error: 'New error');

        expect(updated.id, equals('original-id'));
        expect(updated.title, equals('Original Title'));
        expect(updated.messages.length, equals(1));
        expect(updated.isLoading, isTrue);
        expect(updated.error, equals('New error'));
      });
    });

    group('toDomain', () {
      test('converts UI model to domain ChatSession', () {
        final messages = [
          ChatMessage.user('Hello'),
          ChatMessage.assistant('Hi there'),
        ];

        final uiModel = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test Chat',
          messages: messages,
          isLoading: false,
          isStreaming: false,
        );

        final domainSession = uiModel.toDomain();

        expect(domainSession.id, equals('test-id'));
        expect(domainSession.title, equals('Test Chat'));
        expect(domainSession.messages, equals(messages));
        expect(domainSession.createdAt, equals(messages.first.timestamp));
        expect(domainSession.lastMessageAt, equals(messages.last.timestamp));
      });

      test('handles empty messages list', () {
        final uiModel = ChatSessionUiModel.empty();
        final domainSession = uiModel.toDomain();

        expect(domainSession.messages, isEmpty);
        // Should use current time for both created and last message timestamps
        expect(domainSession.createdAt, isNotNull);
        expect(domainSession.lastMessageAt, isNotNull);
      });
    });

    group('getter properties', () {
      test('completedMessages filters out streaming messages', () {
        final messages = [
          ChatMessage.user('Hello'),
          ChatMessage.assistant('Response'),
          ChatMessage(
            id: 'streaming',
            content: 'Partial...',
            role: ChatMessageRole.assistant,
            timestamp: DateTime.now(),
            isStreaming: true,
          ),
        ];

        final model = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: messages,
          isLoading: false,
          isStreaming: true,
        );

        expect(model.completedMessages.length, equals(2));
        expect(model.completedMessages.every((m) => !m.isStreaming), isTrue);
      });

      test('streamingMessage returns current streaming message', () {
        final streamingMessage = ChatMessage(
          id: 'streaming',
          content: 'Typing...',
          role: ChatMessageRole.assistant,
          timestamp: DateTime.now(),
          isStreaming: true,
        );

        final model = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [
            ChatMessage.user('Hello'),
            streamingMessage,
          ],
          isLoading: false,
          isStreaming: true,
        );

        expect(model.streamingMessage, equals(streamingMessage));
      });

      test('streamingMessage returns null when no streaming messages', () {
        final model = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [ChatMessage.user('Hello')],
          isLoading: false,
          isStreaming: false,
        );

        expect(model.streamingMessage, isNull);
      });

      test('hasMessages returns correct boolean', () {
        final emptyModel = ChatSessionUiModel.empty();
        final modelWithMessages = ChatSessionUiModel(
          id: 'test-id',
          title: 'Test',
          messages: [ChatMessage.user('Hello')],
          isLoading: false,
          isStreaming: false,
        );

        expect(emptyModel.hasMessages, isFalse);
        expect(modelWithMessages.hasMessages, isTrue);
      });

      test('canSendMessage returns correct boolean', () {
        final readyModel = ChatSessionUiModel.empty();
        final loadingModel = readyModel.copyWith(isLoading: true);
        final streamingModel = readyModel.copyWith(isStreaming: true);
        final busyModel =
            readyModel.copyWith(isLoading: true, isStreaming: true);

        expect(readyModel.canSendMessage, isTrue);
        expect(loadingModel.canSendMessage, isFalse);
        expect(streamingModel.canSendMessage, isFalse);
        expect(busyModel.canSendMessage, isFalse);
      });

      test('displayTitle returns title or fallback', () {
        const modelWithTitle = ChatSessionUiModel(
          id: 'test-id',
          title: 'Custom Title',
          messages: [],
          isLoading: false,
          isStreaming: false,
        );

        final emptyModel = ChatSessionUiModel.empty();

        expect(modelWithTitle.displayTitle, equals('Custom Title'));
        expect(emptyModel.displayTitle, equals('New Chat'));
      });
    });
  });

  group('ChatStateUiModel', () {
    group('factory constructors', () {
      test('initial creates model with default values', () {
        final model = ChatStateUiModel.initial();

        expect(model.currentSession?.id ?? '', isEmpty);
        expect(model.recentSessions, isEmpty);
        expect(model.error, isNull);
      });
    });

    group('copyWith', () {
      test('returns new instance with updated values', () {
        final initialSession = ChatSessionUiModel.empty();
        final recentSessions = [
          ChatSessionUiModel.fromDomain(
            ChatSession(
              id: 'recent-1',
              title: 'Recent Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          ),
        ];

        final original = ChatStateUiModel(
          currentSession: initialSession,
          recentSessions: [],
        );

        final updated = original.copyWith(
          recentSessions: recentSessions,
          error: 'Test error',
        );

        expect(updated.recentSessions, equals(recentSessions));
        expect(updated.error, equals('Test error'));
        expect(updated.currentSession, equals(original.currentSession));
      });
    });

    group('clearError', () {
      test('returns new instance with error cleared', () {
        final original = ChatStateUiModel(
          currentSession: ChatSessionUiModel.empty(),
          recentSessions: [],
          error: 'Some error',
        );

        final cleared = original.clearError();

        expect(cleared.error, isNull);
        expect(cleared.currentSession, equals(original.currentSession));
        expect(cleared.recentSessions, equals(original.recentSessions));
      });
    });

    group('getter properties', () {
      test('isAnySessionLoading detects loading in current session', () {
        final loadingCurrentSession =
            ChatSessionUiModel.empty().copyWith(isLoading: true);
        final model = ChatStateUiModel(
          currentSession: loadingCurrentSession,
          recentSessions: [],
        );

        expect(model.isAnySessionLoading, isTrue);
      });

      test('isAnySessionLoading detects loading in recent sessions', () {
        final loadingRecentSession =
            ChatSessionUiModel.empty().copyWith(isLoading: true);
        final model = ChatStateUiModel(
          currentSession: ChatSessionUiModel.empty(),
          recentSessions: [loadingRecentSession],
        );

        expect(model.isAnySessionLoading, isTrue);
      });

      test('isAnySessionLoading returns false when no sessions are loading',
          () {
        final model = ChatStateUiModel(
          currentSession: ChatSessionUiModel.empty(),
          recentSessions: [ChatSessionUiModel.empty()],
        );

        expect(model.isAnySessionLoading, isFalse);
      });
    });
  });
}
