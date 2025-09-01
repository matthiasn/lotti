import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_sessions_controller.dart';
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
  group('ChatSessionsController', () {
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
      test('returns initial ChatStateUiModel and loads recent sessions',
          () async {
        when(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 10,
            )).thenAnswer((_) async => []);

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.currentSession?.id ?? '', isEmpty);
        expect(state.recentSessions, isEmpty);
        expect(state.error, isNull);

        // Wait for async loading to complete
        await Future<void>.delayed(const Duration(milliseconds: 10));

        verify(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 10,
            )).called(1);
      });
    });

    group('createNewSession', () {
      test('creates new session and updates state', () async {
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
        when(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 10,
            )).thenAnswer((_) async => [newSession]);

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        final result = await controller.createNewSession();

        expect(result.id, equals('new-session-id'));
        expect(result.title, equals('New Chat'));

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.currentSession?.id, equals('new-session-id'));

        verify(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .called(1);
      });

      test('handles error and sets error state', () async {
        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenThrow(Exception('Failed to create session'));

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        await expectLater(
          controller.createNewSession(),
          throwsException,
        );
      });
    });

    group('switchToSession', () {
      test('switches to existing session', () async {
        final existingSession = ChatSession(
          id: 'existing-session-id',
          title: 'Existing Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [ChatMessage.user('Hello')],
        );

        when(() => mockChatRepository.getSession('existing-session-id'))
            .thenAnswer((_) async => existingSession);

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        await controller.switchToSession('existing-session-id');

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.currentSession?.id, equals('existing-session-id'));
        expect(state.currentSession?.title, equals('Existing Chat'));
        expect(state.currentSession?.messages.length, equals(1));

        verify(() => mockChatRepository.getSession('existing-session-id'))
            .called(1);
      });

      test('handles session not found error', () async {
        when(() => mockChatRepository.getSession('non-existent-id'))
            .thenAnswer((_) async => null);

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        await controller.switchToSession('non-existent-id');

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.error, contains('Session not found'));
      });
    });

    group('deleteSession', () {
      test('deletes session and creates new one if current', () async {
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
        when(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 10,
            )).thenAnswer((_) async => []);

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        )

          // Set current session
          ..updateCurrentSession(
            ChatSessionUiModel.fromDomain(
              ChatSession(
                id: 'session-to-delete',
                title: 'To Delete',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ),
            ),
          );

        await controller.deleteSession('session-to-delete');

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.currentSession?.id, equals('new-session-id'));

        verify(() => mockChatRepository.deleteSession('session-to-delete'))
            .called(1);
        verify(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .called(1);
      });

      test('deletes session without creating new one if not current', () async {
        when(() => mockChatRepository.deleteSession('other-session'))
            .thenAnswer((_) async {});
        when(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 10,
            )).thenAnswer((_) async => []);

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        )

          // Set different current session
          ..updateCurrentSession(
            ChatSessionUiModel.fromDomain(
              ChatSession(
                id: 'current-session',
                title: 'Current',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ),
            ),
          );

        await controller.deleteSession('other-session');

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.currentSession?.id, equals('current-session'));

        verify(() => mockChatRepository.deleteSession('other-session'))
            .called(1);
        verifyNever(() => mockChatRepository.createSession(
            categoryId: any(named: 'categoryId')));
      });
    });

    group('updateCurrentSession', () {
      test('updates current session in state', () {
        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        final newSession = ChatSessionUiModel.fromDomain(
          ChatSession(
            id: 'updated-session',
            title: 'Updated Session',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [ChatMessage.user('Hello')],
          ),
        );

        controller.updateCurrentSession(newSession);

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.currentSession, equals(newSession));
      });
    });

    group('clearError', () {
      test('clears error from state', () {
        container.read(
          chatSessionsControllerProvider('test-category').notifier,
        )

          // Set error state
          ..updateState(
            (state) => state.copyWith(error: 'Test error'),
          )
          ..clearError();

        final state = container.read(
          chatSessionsControllerProvider('test-category'),
        );

        expect(state.error, isNull);
      });
    });

    group('refresh', () {
      test('reloads recent sessions', () async {
        final sessions = [
          ChatSession(
            id: 'session-1',
            title: 'Chat 1',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        ];

        when(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 10,
            )).thenAnswer((_) async => sessions);

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        await controller.refresh();

        verify(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 10,
            )).called(2); // Called once in build() and once in refresh()
      });
    });

    group('searchSessions', () {
      test('returns recent sessions for empty query', () async {
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

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        )..updateState(
            (state) => state.copyWith(recentSessions: recentSessions),
          );

        final result = await controller.searchSessions('');
        expect(result, equals(recentSessions));

        final result2 = await controller.searchSessions('   ');
        expect(result2, equals(recentSessions));
      });

      test('searches sessions by title and content', () async {
        final sessions = [
          ChatSession(
            id: 'session-1',
            title: 'Flutter Development',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [ChatMessage.user('How to build apps')],
          ),
          ChatSession(
            id: 'session-2',
            title: 'React Development',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [ChatMessage.user('Flutter is great')],
          ),
          ChatSession(
            id: 'session-3',
            title: 'Backend Development',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [ChatMessage.user('Database design')],
          ),
        ];

        when(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 50,
            )).thenAnswer((_) async => sessions);

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        final result = await controller.searchSessions('flutter');

        expect(result.length, equals(2));
        expect(result[0].id, equals('session-1')); // Title match
        expect(result[1].id, equals('session-2')); // Content match

        verify(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 50,
            )).called(1);
      });

      test('returns recent sessions on search error', () async {
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

        when(() => mockChatRepository.getSessions(
              categoryId: 'test-category',
              limit: 50,
            )).thenThrow(Exception('Search failed'));

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        )..updateState(
            (state) => state.copyWith(recentSessions: recentSessions),
          );

        final result = await controller.searchSessions('test');

        expect(result, equals(recentSessions));
      });
    });

    group('getSessionStats', () {
      test('calculates session statistics correctly', () {
        final sessions = [
          ChatSessionUiModel.fromDomain(
            ChatSession(
              id: 'session-1',
              title: 'Chat 1',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [
                ChatMessage.user('Hello'),
                ChatMessage.assistant('Hi'),
              ],
            ),
          ),
          ChatSessionUiModel.fromDomain(
            ChatSession(
              id: 'session-2',
              title: 'Chat 2',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [
                ChatMessage.user('How are you?'),
                ChatMessage.assistant('Good!'),
                ChatMessage.user('Great!'),
              ],
            ),
          ),
          ChatSessionUiModel.fromDomain(
            ChatSession(
              id: 'session-3',
              title: 'Empty Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          ),
        ];

        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        )..updateState(
            (state) => state.copyWith(recentSessions: sessions),
          );

        final stats = controller.getSessionStats();

        expect(stats['totalSessions'], equals(3));
        expect(stats['totalMessages'], equals(5)); // 2 + 3 + 0
        expect(
            stats['activeSessionsCount'], equals(2)); // Sessions with messages
        expect(stats['averageMessagesPerSession'],
            equals(1)); // 5 / 3 = 1 (integer division)
      });

      test('handles empty sessions list', () {
        final controller = container.read(
          chatSessionsControllerProvider('test-category').notifier,
        );

        final stats = controller.getSessionStats();

        expect(stats['totalSessions'], equals(0));
        expect(stats['totalMessages'], equals(0));
        expect(stats['activeSessionsCount'], equals(0));
        expect(stats['averageMessagesPerSession'], equals(0));
      });
    });
  });
}

// Extension to help with testing state updates
extension ChatSessionsControllerTestExtension on ChatSessionsController {
  void updateState(ChatStateUiModel Function(ChatStateUiModel) update) {
    state = update(state);
  }
}
