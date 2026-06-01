import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/controllers/chat_session_controller.dart';
import 'package:lotti/features/ai_chat/ui/models/chat_ui_models.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });
  group('ChatSessionController', () {
    late MockChatRepository mockChatRepository;
    late MockDomainLogger mockDomainLogger;
    late ProviderContainer container;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockDomainLogger = MockDomainLogger();

      // Register mock services with GetIt
      if (!GetIt.instance.isRegistered<DomainLogger>()) {
        GetIt.instance.registerSingleton<DomainLogger>(mockDomainLogger);
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

        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer((_) async => newSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.initializeSession();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('new-session-id'));
        expect(state.title, equals('New Chat'));
        verify(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).called(1);

        // No streaming here; nothing to close
      });

      test('loads existing session when sessionId provided', () async {
        final existingSession = ChatSession(
          id: 'existing-session-id',
          title: 'Existing Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [ChatMessage.user('Previous message')],
        );

        when(
          () => mockChatRepository.getSession('existing-session-id'),
        ).thenAnswer((_) async => existingSession);

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
        verify(
          () => mockChatRepository.getSession('existing-session-id'),
        ).called(1);
      });

      test('creates new session when existing session not found', () async {
        final newSession = ChatSession(
          id: 'new-session-id',
          title: 'New Chat',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [],
        );

        when(
          () => mockChatRepository.getSession('non-existent-id'),
        ).thenAnswer((_) async => null);
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer((_) async => newSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.initializeSession(sessionId: 'non-existent-id');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('new-session-id'));
        verify(
          () => mockChatRepository.getSession('non-existent-id'),
        ).called(1);
        verify(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).called(1);
      });

      test('handles error and sets error state', () async {
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenThrow(Exception('Failed to create session'));

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
      test('upgrades soft break before heading to blank line for Markdown', () {
        fakeAsync((async) {
          // Initialize empty session
          when(
            () => mockChatRepository.createSession(categoryId: 'test-category'),
          ).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
            ),
          );

          final streamController = StreamController<String>();
          // Keep provider alive during async streaming
          final sbSubscription = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );
          when(
            () => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              modelId: any(named: 'modelId'),
            ),
          ).thenAnswer((_) => streamController.stream);
          when(() => mockChatRepository.saveSession(any())).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
            ),
          );

          // Keep provider alive during async streaming
          final keepAlive = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );
          // Run async init steps deterministically
          // ignore: cascade_invocations
          controller.initializeSession();
          async.flushMicrotasks();
          controller.setModel('model-1');
          async.flushMicrotasks();

          // Start streaming (do not await to keep stream open)
          controller.sendMessage('Hello');
          async.flushMicrotasks();

          // Visible segments: text, then whitespace+newline, then heading start
          streamController.add('Intro');
          async.flushMicrotasks();
          streamController.add(' \n');
          async.flushMicrotasks();
          streamController.add('# Title');
          // Close and flush delivery
          // ignore: cascade_invocations
          streamController.close();
          async.flushMicrotasks();

          final state = container.read(
            chatSessionControllerProvider('test-category'),
          );
          final assistant = state.messages.last;

          // The controller should have upgraded the soft break to a blank line
          // before the heading so Markdown recognizes the header properly.
          expect(assistant.content.contains('\n\n# Title'), isTrue);
          // Close the listen subscriptions
          sbSubscription.close();
          keepAlive.close();
        });
      });
      test('does not send empty messages', () async {
        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.sendMessage('');
        await controller.sendMessage('   ');

        verifyNever(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        );
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

        verifyNever(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        );
      });

      test('shows error when no model selected', () async {
        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        // Don't set a model - selectedModelId will be null
        await controller.sendMessage('Hello');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(
          state.error,
          equals('Please select a model before sending messages'),
        );

        verifyNever(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        );
      });

      test('adds user message and creates streaming placeholder', () async {
        when(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        ).thenAnswer((_) async* {
          yield 'Hello there!';
        });

        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 'session-id',
            title: 'Test',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );

        // Keep provider alive during async streaming
        final keepAlive = container.listen(
          chatSessionControllerProvider('test-category'),
          (_, _) {},
          fireImmediately: true,
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        // Set a model first
        await controller.setModel('test-model-id');

        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 'session-id',
            title: 'Test',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
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
        keepAlive.close();
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

        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer((_) async => newSession);

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        await controller.clearChat();

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );

        expect(state.id, equals('new-session-id'));
        expect(state.messages, isEmpty);
        verify(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).called(1);
      });

      test('falls back to empty session on error', () async {
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenThrow(Exception('Failed to create session'));

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

        when(
          () => mockChatRepository.deleteSession('session-to-delete'),
        ).thenAnswer((_) async {});
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer((_) async => newSession);

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
        verify(
          () => mockChatRepository.deleteSession('session-to-delete'),
        ).called(1);
        verify(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).called(1);
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

        verifyNever(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        );
      });

      test('retries last user message', () async {
        final messages = [
          ChatMessage.user('First message'),
          ChatMessage.assistant('First response'),
          ChatMessage.user('Second message'),
          ChatMessage.assistant('Second response'),
        ];

        when(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        ).thenAnswer((_) async* {
          yield 'Retry response';
        });

        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 'session-id',
            title: 'Test',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );

        // Keep provider alive during async streaming
        final keepAlive = container.listen(
          chatSessionControllerProvider('test-category'),
          (_, _) {},
          fireImmediately: true,
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );

        // Set state with messages and model
        container
            .read(chatSessionControllerProvider('test-category').notifier)
            .updateState(
              (state) => state.copyWith(
                messages: messages,
                selectedModelId: 'test-model-id',
              ),
            );

        await controller.retryLastMessage();

        // Verify the last user message was retried
        verify(
          () => mockChatRepository.sendMessage(
            message: 'Second message',
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: 'test-category',
            modelId: any(named: 'modelId'),
          ),
        ).called(1);
        keepAlive.close();
      });
    });

    group('setModel', () {
      test('updates selectedModelId and persists', () async {
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );
        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
            metadata: const {'selectedModelId': 'model-1'},
          ),
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );
        await controller.initializeSession();

        await controller.setModel('model-1');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );
        expect(state.selectedModelId, 'model-1');
        verify(() => mockChatRepository.saveSession(any())).called(1);
      });

      test('reverts UI state and logs error when save fails', () async {
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );
        when(
          () => mockChatRepository.saveSession(any()),
        ).thenThrow(Exception('save failed'));

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );
        await controller.initializeSession();

        await controller.setModel('m2');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );
        expect(state.selectedModelId, isNull);
        verify(
          () => mockDomainLogger.error(
            LogDomain.chat,
            any<Object>(),
            stackTrace: any<StackTrace>(named: 'stackTrace'),
            subDomain: 'setModel',
          ),
        ).called(1);
      });
    });

    group('sendMessage error handling', () {
      test('removes streaming placeholder and sets error on failure', () async {
        // Initialize empty session
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );
        when(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        ).thenAnswer((_) async* {
          throw Exception('stream failure');
        });
        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );
        await controller.initializeSession();

        await controller.setModel('model-1');
        await controller.sendMessage('Hello');

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );
        // User message should remain; streaming placeholder removed
        expect(state.messages.length, 1);
        expect(state.messages.first.role, ChatMessageRole.user);
        expect(state.error, contains('Failed to send message'));
        expect(state.isStreaming, isFalse);
      });

      test(
        'truncates overly long streaming content to cap with ellipsis',
        () async {
          // Initialize empty session
          when(
            () => mockChatRepository.createSession(categoryId: 'test-category'),
          ).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          );

          final streamController = StreamController<String>();
          when(
            () => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              modelId: any(named: 'modelId'),
            ),
          ).thenAnswer((_) => streamController.stream);
          when(() => mockChatRepository.saveSession(any())).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
            ),
          );

          // Keep provider alive during async streaming by listening to it
          final sub = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );
          final keepAlive = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );
          await controller.initializeSession();
          await controller.setModel('model-1');

          // Start streaming
          // ignore: unawaited_futures
          controller.sendMessage('Hello');
          await Future<void>.delayed(Duration.zero);

          // Push content exceeding 1,000,000 characters
          const cap = 1000000;
          streamController
            ..add('a' * cap)
            ..add('b' * 100);

          // Close and settle
          await streamController.close();
          await Future<void>.delayed(Duration.zero);

          final state = container.read(
            chatSessionControllerProvider('test-category'),
          );
          final assistant = state.messages.last;
          expect(assistant.content.length, cap + 1);
          expect(assistant.content.endsWith('…'), isTrue);
          // Close subscriptions
          sub.close();
          keepAlive.close();
        },
      );

      test('does not send a second message while streaming', () async {
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );

        final streamController = StreamController<String>();
        when(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: const [],
          ),
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );
        await controller.initializeSession();
        await controller.setModel('model-1');

        // Start first send and stay streaming (we intentionally do not await)
        // ignore: unawaited_futures
        controller.sendMessage('First');
        await Future<void>.delayed(Duration.zero);

        // Attempt second send
        await controller.sendMessage('Second');

        // Only one sendMessage on repository should be observed
        verify(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: 'test-category',
            modelId: any(named: 'modelId'),
          ),
        ).called(1);

        await streamController.close();
      });

      test('drops empty streaming assistant message on finalize', () async {
        // Initialize empty session
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );

        final streamController = StreamController<String>();
        when(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: const [],
          ),
        );

        // Keep provider alive during async streaming by listening to it
        final keepSub = container.listen(
          chatSessionControllerProvider('test-category'),
          (_, _) {},
          fireImmediately: true,
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );
        await controller.initializeSession();
        await controller.setModel('model-1');

        // Start streaming and emit only whitespace so assistant message should be dropped
        // ignore: unawaited_futures
        controller.sendMessage('Hi');
        await Future<void>.delayed(Duration.zero);
        streamController.add('   ');
        await streamController.close();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );
        // Only user message remains
        expect(state.messages.length, 1);
        expect(state.messages.first.role, ChatMessageRole.user);

        // End
        keepSub.close();
      });

      test('flushes trailing thinking buffer without close token', () async {
        // Initialize empty session
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );

        final streamController = StreamController<String>();
        when(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: const [],
          ),
        );

        // Keep provider alive during async streaming by listening to it
        final sub = container.listen(
          chatSessionControllerProvider('test-category'),
          (_, _) {},
          fireImmediately: true,
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );
        await controller.initializeSession();
        await controller.setModel('model-1');

        // Start streaming and emit only an unterminated thinking block
        // ignore: unawaited_futures
        controller.sendMessage('Hi');
        await Future<void>.delayed(Duration.zero);
        streamController.add('<thinking>Work in progress');
        await streamController.close();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );
        // Expect user + a finalized thinking message (wrapped)
        expect(state.isStreaming, isFalse);
        expect(state.isLoading, isFalse);
        expect(state.streamingMessageId, isNull);
        expect(state.messages.length, 2);
        final assistant = state.messages.last;
        expect(assistant.role, ChatMessageRole.assistant);
        expect(assistant.content.contains('<thinking>'), isTrue);
        expect(assistant.content.contains('Work in progress'), isTrue);
        expect(assistant.content.contains('</thinking>'), isTrue);
        sub.close();
      });

      test('finalizes visible then flushes trailing thinking buffer', () async {
        // Initialize empty session
        when(
          () => mockChatRepository.createSession(categoryId: 'test-category'),
        ).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: [],
          ),
        );

        final streamController = StreamController<String>();
        when(
          () => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          ),
        ).thenAnswer((_) => streamController.stream);
        when(() => mockChatRepository.saveSession(any())).thenAnswer(
          (_) async => ChatSession(
            id: 's1',
            title: 'New Chat',
            createdAt: DateTime(2024),
            lastMessageAt: DateTime(2024),
            messages: const [],
          ),
        );

        // Keep provider alive during async streaming by listening to it
        final sub = container.listen(
          chatSessionControllerProvider('test-category'),
          (_, _) {},
          fireImmediately: true,
        );

        final controller = container.read(
          chatSessionControllerProvider('test-category').notifier,
        );
        await controller.initializeSession();
        await controller.setModel('model-1');

        // Start streaming: first visible text, then an unterminated thinking block
        // ignore: unawaited_futures
        controller.sendMessage('Hi');
        await Future<void>.delayed(Duration.zero);
        streamController.add('Visible part');
        await Future<void>.delayed(Duration.zero);
        streamController.add('<thinking>Hidden rationale');
        await streamController.close();
        await Future<void>.delayed(Duration.zero);

        final state = container.read(
          chatSessionControllerProvider('test-category'),
        );
        // Expect user + finalized visible assistant + finalized thinking assistant
        expect(state.isStreaming, isFalse);
        expect(state.streamingMessageId, isNull);
        expect(state.messages.length, 3);
        final visible = state.messages[1];
        final thinking = state.messages[2];
        expect(visible.role, ChatMessageRole.assistant);
        expect(visible.content, contains('Visible part'));
        expect(thinking.content.contains('<thinking>'), isTrue);
        expect(thinking.content.contains('Hidden rationale'), isTrue);
        expect(thinking.content.contains('</thinking>'), isTrue);
        sub.close();
      });

      test(
        'flushes visible segment from parser.finish() when stream ends mid-text',
        () async {
          // Initialize empty session
          when(
            () => mockChatRepository.createSession(categoryId: 'test-category'),
          ).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          );

          final streamController = StreamController<String>();
          when(
            () => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              modelId: any(named: 'modelId'),
            ),
          ).thenAnswer((_) => streamController.stream);
          when(() => mockChatRepository.saveSession(any())).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
            ),
          );

          final sub = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );
          await controller.initializeSession();
          await controller.setModel('model-1');

          // Start streaming with a thinking block that contains visible text after
          // Close the stream without a </thinking> so parser.finish() emits a
          // ThinkingFinal; then also emit visible text so appendVisible is
          // called from the finish() flush path (line 178).
          // ignore: unawaited_futures
          controller.sendMessage('Hi');
          await Future<void>.delayed(Duration.zero);
          // Emit a complete thinking block then visible text to exercise
          // parser.finish() flushing a VisibleAppend.
          streamController
            ..add('<thinking>Reasoning</thinking>')
            ..add('Answer text');
          await streamController.close();
          await Future<void>.delayed(Duration.zero);

          final state = container.read(
            chatSessionControllerProvider('test-category'),
          );
          // user + thinking + visible answer messages
          expect(state.isStreaming, isFalse);
          expect(state.isLoading, isFalse);
          expect(state.messages.length, greaterThanOrEqualTo(2));
          final lastMsg = state.messages.last;
          expect(lastMsg.role, ChatMessageRole.assistant);
          expect(lastMsg.content, contains('Answer text'));
          sub.close();
        },
      );

      test(
        'removes streaming message with content on error (exercises _removeStreamingMessage body)',
        () async {
          when(
            () => mockChatRepository.createSession(categoryId: 'test-category'),
          ).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          );

          // Stream emits some content then throws to trigger _removeStreamingMessage
          // with a non-null _currentStreamingMessageId already set.
          final streamController = StreamController<String>();
          when(
            () => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              modelId: any(named: 'modelId'),
            ),
          ).thenAnswer((_) => streamController.stream);
          when(() => mockChatRepository.saveSession(any())).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
            ),
          );

          final sub = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );
          await controller.initializeSession();
          await controller.setModel('model-1');

          // ignore: unawaited_futures
          controller.sendMessage('Hi');
          await Future<void>.delayed(Duration.zero);

          // Emit real content so a streaming message is added (non-null ID)
          streamController.add('Partial response');
          await Future<void>.delayed(Duration.zero);

          // Now add an error to trigger the catch block with an active streaming
          // message, exercising _removeStreamingMessage lines 287-297.
          streamController.addError(Exception('mid-stream error'));
          await Future<void>.delayed(Duration.zero);

          final state = container.read(
            chatSessionControllerProvider('test-category'),
          );
          // Streaming message should be removed; only user message remains
          expect(
            state.messages.where((m) => m.role == ChatMessageRole.user).length,
            1,
          );
          expect(
            state.messages
                .where((m) => m.role == ChatMessageRole.assistant)
                .length,
            0,
          );
          expect(state.isStreaming, isFalse);
          expect(state.isLoading, isFalse);
          expect(state.error, contains('Failed to send message'));
          sub.close();
        },
      );

      test(
        '_saveCurrentSession logs error and does not expose it on save failure',
        () async {
          when(
            () => mockChatRepository.createSession(categoryId: 'test-category'),
          ).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          );

          when(
            () => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              modelId: any(named: 'modelId'),
            ),
          ).thenAnswer((_) async* {
            yield 'Response text';
          });

          // saveSession throws so _saveCurrentSession catch (line 314) is hit
          when(
            () => mockChatRepository.saveSession(any()),
          ).thenThrow(Exception('save failed'));

          final sub = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );
          await controller.initializeSession();

          // Use updateState to set the model directly, bypassing the setModel
          // path that also calls saveSession (which would throw and revert).
          controller.updateState((s) => s.copyWith(selectedModelId: 'model-1'));

          await controller.sendMessage('Hello');

          final state = container.read(
            chatSessionControllerProvider('test-category'),
          );
          // Error should NOT be exposed to the user for save failures
          expect(state.error, isNull);
          // But the logger should have been called
          verify(
            () => mockDomainLogger.error(
              LogDomain.chat,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: '_saveCurrentSession',
            ),
          ).called(1);
          sub.close();
        },
      );

      test(
        '_saveCurrentSession persists completed messages to repository after send',
        () async {
          when(
            () => mockChatRepository.createSession(categoryId: 'test-category'),
          ).thenAnswer(
            (_) async => ChatSession(
              id: 'session-42',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          );

          when(
            () => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              modelId: any(named: 'modelId'),
            ),
          ).thenAnswer((_) async* {
            yield 'Saved response';
          });

          final savedSessions = <ChatSession>[];
          when(
            () => mockChatRepository.saveSession(any()),
          ).thenAnswer((invocation) async {
            final session = invocation.positionalArguments.first as ChatSession;
            savedSessions.add(session);
            return session;
          });

          final sub = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );
          await controller.initializeSession();
          controller.updateState((s) => s.copyWith(selectedModelId: 'model-1'));

          await controller.sendMessage('Persist me');

          // _saveCurrentSession should have been called once with the full session
          expect(savedSessions, hasLength(1));
          final saved = savedSessions.first;
          expect(saved.id, equals('session-42'));
          expect(
            saved.messages.any((m) => m.content == 'Persist me'),
            isTrue,
          );
          expect(
            saved.messages.any((m) => m.content == 'Saved response'),
            isTrue,
          );
          sub.close();
        },
      );
    });

    group('deleteSession error handling', () {
      test(
        'sets error state when deleteSession throws (lines 360, 366-367)',
        () async {
          when(
            () => mockChatRepository.deleteSession(any()),
          ).thenThrow(Exception('delete failed'));

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );

          // Set a non-empty session id so deleteSession proceeds past the guard
          // ignore: cascade_invocations
          controller.updateState((s) => s.copyWith(id: 'session-to-delete'));

          await controller.deleteSession();

          final state = container.read(
            chatSessionControllerProvider('test-category'),
          );
          expect(state.error, contains('Failed to delete session'));
          verify(
            () => mockDomainLogger.error(
              LogDomain.chat,
              any<Object>(),
              stackTrace: any<StackTrace>(named: 'stackTrace'),
              subDomain: 'deleteSession',
            ),
          ).called(1);
        },
      );
    });

    group('_finalizeStreamingMessage edge cases', () {
      test(
        'handles missing streaming message gracefully (line 256: clears id and returns)',
        () async {
          when(
            () => mockChatRepository.createSession(categoryId: 'test-category'),
          ).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: [],
            ),
          );

          final streamController = StreamController<String>();
          when(
            () => mockChatRepository.sendMessage(
              message: any(named: 'message'),
              conversationHistory: any(named: 'conversationHistory'),
              categoryId: any(named: 'categoryId'),
              modelId: any(named: 'modelId'),
            ),
          ).thenAnswer((_) => streamController.stream);
          when(() => mockChatRepository.saveSession(any())).thenAnswer(
            (_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
            ),
          );

          final sub = container.listen(
            chatSessionControllerProvider('test-category'),
            (_, _) {},
            fireImmediately: true,
          );

          final controller = container.read(
            chatSessionControllerProvider('test-category').notifier,
          );
          await controller.initializeSession();
          await controller.setModel('model-1');

          // ignore: unawaited_futures
          controller.sendMessage('Hi');
          await Future<void>.delayed(Duration.zero);

          // Emit visible content to create a streaming message
          streamController.add('Some text');
          await Future<void>.delayed(Duration.zero);

          // Remove all messages from state while the streaming ID is still set,
          // so when _finalizeStreamingMessage runs it cannot find the message
          // and hits the "existing == null" guard on line 255-257.
          controller.updateState((s) => s.copyWith(messages: []));

          await streamController.close();
          await Future<void>.delayed(Duration.zero);

          final state = container.read(
            chatSessionControllerProvider('test-category'),
          );
          // Controller should complete gracefully with no crash and clear flags
          expect(state.isStreaming, isFalse);
          expect(state.isLoading, isFalse);
          sub.close();
        },
      );
    });
  });
}

// Extension to help with testing state updates
extension ChatSessionControllerTestExtension on ChatSessionController {
  void updateState(ChatSessionUiModel Function(ChatSessionUiModel) update) {
    state = update(state);
  }
}
