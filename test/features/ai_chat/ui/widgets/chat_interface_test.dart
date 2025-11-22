import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeChatSession extends Fake implements ChatSession {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });

  // Helper to set up test environment with adequate size
  Future<void> setupTestWidget(
    WidgetTester tester,
    Widget child, {
    List<Override> overrides = const [],
  }) async {
    // Use a generous viewport to avoid overflows on CI/very_good runner
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    // Combine default overrides with test-specific ones
    final allOverrides = [
      eligibleChatModelsForCategoryProvider(categoryId: 'test-category')
          .overrideWith((_) async => []),
      ...overrides,
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: allOverrides,
        child: child,
      ),
    );
  }

  group('ChatInterface', () {
    late MockChatRepository mockChatRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      // Isolate GetIt state per test for optimized runners
      GetIt.instance.pushNewScope();
      mockChatRepository = MockChatRepository();
      mockLoggingService = MockLoggingService();
      // default: empty eligible models

      // Register mock services with GetIt
      GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
    });

    tearDown(() async {
      await GetIt.instance.resetScope();
      await GetIt.instance.popScope();
    });

    testWidgets('displays empty state when no messages', (tester) async {
      final session = ChatSession(
        id: 'test-session',
        title: 'New Chat',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: [],
        metadata: const {'selectedModelId': 'test-model'},
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession('test-session'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
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

    testWidgets('shows "No eligible models" inside settings sheet when none',
        (tester) async {
      final mockAiRepo = MockAiConfigRepository();
      when(() => mockAiRepo.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);
      when(() => mockAiRepo.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => []);

      final session = ChatSession(
        id: 'test-session',
        title: 'New Chat',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: [],
        metadata: const {'selectedModelId': 'test-model'},
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession('test-session'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await setupTestWidget(
        tester,
        ProviderScope(
          overrides: [
            chatRepositoryProvider.overrideWithValue(mockChatRepository),
            aiConfigRepositoryProvider.overrideWithValue(mockAiRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ChatInterface(categoryId: 'test-category'),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Assistant Settings via header button
      await tester.tap(find.byTooltip('Assistant settings'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Assistant Settings'), findsOneWidget);
      expect(find.text('No eligible models'), findsOneWidget);
    });

    testWidgets('input disabled and settings action when no model selected',
        (tester) async {
      final session = ChatSession(
        id: 'test-session',
        title: 'New Chat',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: [],
        // Note: no selectedModelId to test the "no model" case
        metadata: const {},
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession('test-session'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Text input is disabled when no model is selected
      final tf = tester.widget<TextField>(
        find.byKey(const ValueKey('chat_text_field')),
      );
      expect(tf.enabled, isFalse);
      // Mic is not available; a settings (tune) action is shown instead
      expect(find.byIcon(Icons.mic), findsNothing);
      final tuneBtn = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(Icons.tune).first,
        matching: find.byType(IconButton),
      ));
      expect(tuneBtn.onPressed, isNotNull);
    });

    testWidgets('error banner close hides the banner', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenThrow(Exception('fail'));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('displays empty state with helper text', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
                metadata: const {'selectedModelId': 'test-model'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Check empty state text
      expect(find.text('Ask me about your tasks'), findsOneWidget);
      expect(
          find.textContaining('I can help analyze your productivity patterns'),
          findsOneWidget);
    });

    testWidgets('displays header with session title', (tester) async {
      final session = ChatSession(
        id: 'test-session',
        title: 'My Test Chat',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: [],
        metadata: const {'selectedModelId': 'test-model'},
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession('test-session'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Check header elements
      expect(find.text('AI Assistant'), findsOneWidget);
      // Ensure async initialization completes deterministically, then assert title
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('My Test Chat'), findsOneWidget);
      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    });

    testWidgets('displays messages when they exist', (tester) async {
      final messages = [
        ChatMessage.user('Hello, how are you?'),
        ChatMessage.assistant('I am doing well, thank you for asking!'),
      ];

      final session = ChatSession(
        id: 'test-session',
        title: 'Chat with Messages',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: messages,
        metadata: const {'selectedModelId': 'test-model'},
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession('test-session'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Wait a bit more for async initialization
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Check messages are displayed
      expect(find.text('Hello, how are you?'), findsOneWidget);
      expect(
          find.text('I am doing well, thank you for asking!'), findsOneWidget);

      // New UX: no avatars on bubbles; copy button present for assistant only
      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.byIcon(Icons.psychology), findsNothing);
      expect(find.byIcon(Icons.copy), findsOneWidget);
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
                metadata: const {'selectedModelId': 'test-model'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
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
                metadata: const {'selectedModelId': 'test-model'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
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
                metadata: {'selectedModelId': 'test-model'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Check input elements
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Ask about your tasks and productivity...'),
          findsOneWidget);
      // Mic is shown by default when input is empty
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('shows error banner when error exists', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenThrow(Exception('Connection failed'));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
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
                metadata: {'selectedModelId': 'test-model'},
              ));

      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
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
                metadata: {'selectedModelId': 'test-model'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Verify mic button is shown initially
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);

      // Enter text and wait for UI to update
      await tester.enterText(find.byType(TextField), 'Hello, AI!');
      await tester.pump(); // Let the UI update after text entry

      // Now send button should be visible
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.send), findsOneWidget);

      // Tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Verify message was sent
      verify(() => mockChatRepository.sendMessage(
            message: 'Hello, AI!',
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: 'test-category',
            modelId: 'test-model',
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
                metadata: {'selectedModelId': 'test-model'},
              ));

      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
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
                metadata: {'selectedModelId': 'test-model'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
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
            modelId: 'test-model',
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
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Verify main UI elements are displayed
      expect(find.byType(TextField), findsOneWidget);
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
                metadata: {'selectedModelId': 'test-model'},
              ));

      // Set up streaming response
      final streamController = StreamController<String>();
      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) => streamController.stream);

      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => ChatSession(
                id: 'test-session',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: [],
                metadata: {'selectedModelId': 'test-model'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Send a message to trigger streaming
      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump(); // Let UI update after text entry

      // Now tap send button
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump(); // Trigger the send

      // Wait for the streaming state to initialize
      await tester.pump();

      // First check that we have an empty streaming message indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Add some streaming content
      streamController.add('Hello');
      await tester.pump();

      // Now the content should show instead of just "Thinking..."
      expect(find.text('Hello'), findsOneWidget);

      // Properly close the stream and clean up timers
      streamController.add(' world!');
      await streamController.close();
      await tester.pumpAndSettle();

      // Final message should be displayed
      expect(find.text('Hello world!'), findsOneWidget);
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
            eligibleChatModelsForCategoryProvider(categoryId: 'test-category')
                .overrideWith((_) async => []),
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

    testWidgets(
        'model selection disabled during streaming (via settings sheet)',
        (tester) async {
      final mockAiRepo = MockAiConfigRepository();
      final provider = AiConfigInferenceProvider(
        id: 'prov',
        name: 'P',
        baseUrl: 'https://',
        apiKey: 'k',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.openAi,
      );
      final model = AiConfigModel(
        id: 'm1',
        name: 'Model 1',
        providerModelId: 'm1',
        inferenceProviderId: provider.id,
        createdAt: DateTime(2024),
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
        supportsFunctionCalling: true,
      );

      when(() => mockAiRepo.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => [model]);
      when(() => mockAiRepo.getConfigsByType(AiConfigType.inferenceProvider))
          .thenAnswer((_) async => [provider]);

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => ChatSession(
                id: 's1',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: const [],
                metadata: const {'selectedModelId': 'm1'},
              ));

      final streamController = StreamController<String>();
      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) => streamController.stream);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => ChatSession(
                id: 's1',
                title: 'New Chat',
                createdAt: DateTime(2024),
                lastMessageAt: DateTime(2024),
                messages: const [],
                metadata: const {'selectedModelId': 'm1'},
              ));

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
          aiConfigRepositoryProvider.overrideWithValue(mockAiRepo),
          // Override eligible models to return the test model
          eligibleChatModelsForCategoryProvider(categoryId: 'test-category')
              .overrideWith((_) async => [model]),
        ],
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hi');
      await tester.pump(); // Let UI update after text entry
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Open Assistant Settings
      await tester.tap(find.byTooltip('Assistant settings'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Assistant Settings'), findsOneWidget);
      // DropdownFormField should be disabled while streaming
      final ddFinder = find.byType(DropdownButtonFormField<String>);
      final dd = tester.widget<DropdownButtonFormField<String>>(ddFinder);
      expect(dd.onChanged, isNull);

      // Cleanup timers and stream
      await streamController.close();
      await tester.pump(const Duration(milliseconds: 250));
    });

    testWidgets('new chat button triggers session creation', (tester) async {
      var callCount = 0;
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async {
        callCount++;
        return ChatSession(
          id: 's-new-$callCount',
          title: 'New Chat $callCount',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: const [],
          metadata: const {'selectedModelId': 'test-model'},
        );
      });

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );
      await tester.pumpAndSettle();

      // Initial session creation should have been called
      expect(callCount, 1);

      // Tap new chat button
      await tester.tap(find.byIcon(Icons.add_comment_outlined));
      await tester.pumpAndSettle();

      // Another session should have been created
      expect(callCount, 2);
    });

    testWidgets('shows mic button when input is empty', (tester) async {
      final session = ChatSession(
        id: 'test-session',
        title: 'New Chat',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: [],
        metadata: const {'selectedModelId': 'test-model'},
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession('test-session'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Mic button should be visible when input is empty
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('shows send button when text is entered', (tester) async {
      final session = ChatSession(
        id: 'test-session',
        title: 'New Chat',
        createdAt: DateTime(2024),
        lastMessageAt: DateTime(2024),
        messages: [],
        metadata: const {'selectedModelId': 'test-model'},
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession('test-session'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await setupTestWidget(
        tester,
        const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'test-category'),
          ),
        ),
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
        ],
      );

      await tester.pumpAndSettle();

      // Initially mic is shown
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);

      // Enter text
      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump(); // Let UI update

      // Now send button should be visible
      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.send), findsOneWidget);

      // Clear text
      await tester.enterText(find.byType(TextField), '');
      await tester.pump(); // Let UI update

      // Mic should be visible again
      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });
  });
}
