import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeChatSession extends Fake implements ChatSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });
  group('ChatSessionController', () {
    late MockChatRepository mockChatRepository;
    late MockLoggingService mockLoggingService;
    late ProviderContainer container;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockLoggingService = MockLoggingService();

      // Register mock services with GetIt
      if (!GetIt.instance.isRegistered<LoggingService>()) {
        GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
      }

      container = ProviderContainer(
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );
    });

    tearDown(() {
      container.dispose();
      GetIt.instance.reset();
    });

    group('build', () {
      test('returns empty ChatSessionUiModel', () {
        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, isEmpty);
        expect(state.title, equals('New Chat'));
        expect(state.messages, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.isStreaming, isFalse);
      });
    });

    group('initializeSession', () {
      test('creates new session when no sessionId provided', () async {
        final newSession = ChatSession(
          id: 'new-session-id',
          title: 'New Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
        );

        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenAnswer((_) async => newSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.initializeSession();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('new-session-id'));
        expect(state.title, equals('New Chat'));
        verify(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .called(1);
      });

      test('loads existing session when sessionId provided', () async {
        final existingSession = ChatSession(
          id: 'existing-session-id',
          title: 'Existing Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [ChatMessage.user('Previous message')],
        );

        when(() => mockChatRepository.getSession('existing-session-id'))
            .thenAnswer((_) async => existingSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.initializeSession(sessionId: 'existing-session-id');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('existing-session-id'));
        expect(state.title, equals('Existing Chat'));
        expect(state.messages.length, equals(1));
        verify(() => mockChatRepository.getSession('existing-session-id'))
            .called(1);
      });

      test('creates new session when existing session not found', () async {
        final newSession = ChatSession(
          id: 'new-session-id',
          title: 'New Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
        );

        when(() => mockChatRepository.getSession('non-existent-id'))
            .thenAnswer((_) async => null);
        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenAnswer((_) async => newSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.initializeSession(sessionId: 'non-existent-id');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('new-session-id'));
        verify(() => mockChatRepository.getSession('non-existent-id'))
            .called(1);
        verify(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .called(1);
      });

      test('handles error and sets error state', () async {
        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenThrow(Exception('Failed to create session'));

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.initializeSession();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.error, contains('Failed to initialize session'));
      });
    });

    group('sendMessage', () {
      test('does not send empty messages', () async {
        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.sendMessage('');
        await controller.sendMessage('   ');

        verifyNever(() => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              enableThinking: any(named: 'enableThinking'),
            ));
      });

      test('does not send when cannot send message', () async {
        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        // Set state to loading
        container
            .read(chatSessionControllerProvider('test-category').notifier)
            .updateState(
              (state) => state.copyWith(isLoading: true),
            );

        await controller.sendMessage('Hello');

        verifyNever(() => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              enableThinking: any(named: 'enableThinking'),
            ));
      });

      test('adds user message and creates streaming placeholder', () async {
        when(() => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              enableThinking: any(named: 'enableThinking'),
            )).thenAnswer((_) async* {
          yield 'Hello there!';
        });

        when(() => mockChatRepository.saveSession(any()))
            .thenAnswer((_) async => ChatSession(
                  id: 'session-id',
                  title: 'Test',
                  createdAt: DateTime(2024),
                  lastMessageAt: DateTime(2024),
                  messages: [],
                ));

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.sendMessage('Hello');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.messages.length, equals(2));
        expect(state.messages[0].role, equals(ChatMessageRole.user));
        expect(state.messages[0].content, equals('Hello'));
        expect(state.messages[1].role, equals(ChatMessageRole.assistant));
        expect(state.messages[1].content, equals('Hello there!'));
        expect(state.messages[1].isStreaming, isFalse);
      });
    });

    group('clearChat', () {
      test('creates new session', () async {
        final newSession = ChatSession(
          id: 'new-session-id',
          title: 'New Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
        );

        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenAnswer((_) async => newSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.clearChat();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('new-session-id'));
        expect(state.messages, isEmpty);
        verify(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .called(1);
      });

      test('falls back to empty session on error', () async {
        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenThrow(Exception('Failed to create session'));

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.clearChat();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, isEmpty);
        expect(state.title, equals('New Chat'));
        expect(state.messages, isEmpty);
      });
    });

    group('deleteSession', () {
      test('does nothing when session ID is empty', () async {
        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.deleteSession();

        verifyNever(() => mockChatRepository.deleteSession(any()));
      });

      test('deletes session and creates new one', () async {
        final newSession = ChatSession(
          id: 'new-session-id',
          title: 'New Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
        );

        when(() => mockChatRepository.deleteSession('session-to-delete'))
            .thenAnswer((_) async {});
        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenAnswer((_) async => newSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        // Set state with session ID
        container
            .read(chatSessionControllerProvider('test-category').notifier)
            .updateState(
              (state) => state.copyWith(id: 'session-to-delete'),
            );

        await controller.deleteSession();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('new-session-id'));
        verify(() => mockChatRepository.deleteSession('session-to-delete'))
            .called(1);
        verify(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .called(1);
      });
    });

    group('clearError', () {
      test('clears error from state', () {
        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        // Set error state
        container
            .read(chatSessionControllerProvider('test-category').notifier)
            .updateState(
              (state) => state.copyWith(error: 'Test error'),
            );

        controller.clearError();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.error, isNull);
      });
    });

    group('retryLastMessage', () {
      test('does nothing when no messages', () async {
        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.retryLastMessage();

        verifyNever(() => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              enableThinking: any(named: 'enableThinking'),
            ));
      });

      test('retries last user message', () async {
        final messages = [
          ChatMessage.user('First message'),
          ChatMessage.assistant('First response'),
          ChatMessage.user('Second message'),
          ChatMessage.assistant('Second response'),
        ];

        when(() => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              enableThinking: any(named: 'enableThinking'),
            )).thenAnswer((_) async* {
          yield 'Retry response';
        });

        when(() => mockChatRepository.saveSession(any()))
            .thenAnswer((_) async => ChatSession(
                  id: 'session-id',
                  title: 'Test',
                  createdAt: DateTime(2024),
                  lastMessageAt: DateTime(2024),
                  messages: [],
                ));

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        // Set state with messages
        container
            .read(chatSessionControllerProvider('test-category').notifier)
            .updateState(
              (state) => state.copyWith(messages: messages),
            );

        await controller.retryLastMessage();

        // Verify the last user message was retried
        verify(() => mockChatRepository.sendMessage(
              message: 'Second message',
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: 'test-category',
              enableThinking: true,
            )).called(1);
      });
    });
  });
}

// Extension to help with testing state updates
extension ChatSessionControllerTestExtension on ChatSessionController {
  void updateState(ChatSessionUiModel Function(ChatSessionUiModel) update) {
    state = update(state);
  }
}
