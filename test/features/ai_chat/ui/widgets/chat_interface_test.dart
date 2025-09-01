import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai_chat/domain/models/chat_session.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeChatSession extends Fake implements ChatSession {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });

  // Helper to set up test environment with adequate size
  Future<void> setupTestWidget(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());
    await tester.pumpWidget(child);
  }

  group('ChatInterface', () {
    late MockChatRepository mockChatRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      mockChatRepository = MockChatRepository();
      mockLoggingService = MockLoggingService();

      // Register mock services with GetIt
      if (!GetIt.instance.isRegistered<LoggingService>()) {
        GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
      }
    });

    tearDown(() {
      GetIt.instance.reset();
    });

    testWidgets('displays empty state when no messages', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check empty state elements
      expect(find.byIcon(Icons.psychology_outlined), findsWidgets);
      expect(find.text('Ask me about your tasks'), findsOneWidget);
      expect(
          find.text(
              'I can help analyze your productivity patterns, summarize completed tasks, and provide insights about your work habits.'),
          findsOneWidget);
    });

    testWidgets('displays suggestion chips in empty state', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check suggestion chips
      expect(find.text('What did I work on this week?'), findsOneWidget);
      expect(find.text('Show me my productivity patterns'), findsOneWidget);
      expect(find.text('Summarize completed tasks'), findsOneWidget);
    });

    testWidgets('displays header with session title', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'My Test Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header elements
      expect(find.text('AI Assistant'), findsOneWidget);
      expect(find.text('My Test Chat'), findsOneWidget);
      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    });

    testWidgets('displays messages when they exist', (tester) async {
      final messages = [
        ChatMessage.user('Hello, how are you?'),
        ChatMessage.assistant('I am doing well, thank you for asking!'),
      ];

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'Chat with Messages',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: messages,
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check messages are displayed
      expect(find.text('Hello, how are you?'), findsOneWidget);
      expect(
          find.text('I am doing well, thank you for asking!'), findsOneWidget);

      // Check message avatars
      expect(find.byIcon(Icons.person), findsOneWidget); // User avatar
      expect(find.byIcon(Icons.psychology), findsOneWidget); // AI avatar
    });

    testWidgets('shows clear chat button when messages exist', (tester) async {
      final messages = [ChatMessage.user('Hello')];

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'Chat with Messages',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: messages,
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check clear chat button is visible
      expect(find.byIcon(Icons.clear_all), findsOneWidget);
    });

    testWidgets('hides clear chat button when no messages', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'Empty Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check clear chat button is not visible
      expect(find.byIcon(Icons.clear_all), findsNothing);
    });

    testWidgets('displays input field and send button', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check input elements
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Ask about your tasks and productivity...'),
          findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
    });

    testWidgets('shows error banner when error exists', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenThrow(Exception('Connection failed'));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check error banner elements
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('sends message when send button pressed', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async* {
        yield 'Hello there!';
      });

      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text and send message
      await tester.enterText(find.byType(TextField), 'Hello, AI!');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify message was sent
      verify(() => mockChatRepository.sendMessage(
            message: 'Hello, AI!',
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: 'test-category',
          )).called(1);
    });

    testWidgets('sends message when Enter key pressed', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) async* {
        yield 'Response via Enter key!';
      });

      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter text and press Enter
      await tester.enterText(find.byType(TextField), 'Hello via Enter!');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      // Verify message was sent
      verify(() => mockChatRepository.sendMessage(
            message: 'Hello via Enter!',
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: 'test-category',
          )).called(1);
    });

    testWidgets('shows UI elements correctly when session loads',
        (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify main UI elements are displayed
      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(Icons.send), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
    });

    testWidgets('shows streaming indicator when message is streaming',
        (tester) async {
      // Set up a session with existing messages first
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      // Set up streaming response
      final streamController = StreamController<String>();
      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
          )).thenAnswer((_) => streamController.stream);

      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
              ));

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Send a message to trigger streaming
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(); // Trigger the send

      // Add some streaming content
      streamController.add('Thinking...');
      await tester.pump();

      // Check streaming indicator elements
      expect(find.text('Thinking...'), findsOneWidget);

      // Properly close the stream and clean up timers
      streamController.add('Complete response');
      await streamController.close();
      await tester.pumpAndSettle();
    });

    testWidgets('accepts sessionId parameter', (tester) async {
      final existingSession = ChatSession(
        id: 'existing-session-id',
        title: 'Existing Chat',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: [ChatMessage.user('Previous message')],
      );

      when(() => mockChatRepository.getSession('existing-session-id'))
          .thenAnswer((_) async => existingSession);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(
                categoryId: 'test-category',
                sessionId: 'existing-session-id',
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify session was loaded
      verify(() => mockChatRepository.getSession('existing-session-id'))
          .called(1);
      expect(find.text('Previous message'), findsOneWidget);
    });
  });
}
