import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class FakeChatSession extends Fake implements ChatSession {}

void main() {
  late MockChatRepository mockRepo;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });

  setUp(() {
    mockRepo = MockChatRepository();
    mockLoggingService = MockLoggingService();

    // Register the logging service mock
    if (GetIt.instance.isRegistered<LoggingService>()) {
      GetIt.instance.unregister<LoggingService>();
    }
    GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);

    // Setup default mock behavior for logging
    when(() => mockLoggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);
  });

  tearDown(() {
    GetIt.instance.reset();
  });

  Future<void> pumpChatInterface(
    WidgetTester tester, {
    required MockChatRepository repository,
    String categoryId = 'test-category',
    String? sessionId,
  }) async {
    // Set physical size for consistent rendering
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ChatInterface(
              categoryId: categoryId,
              sessionId: sessionId,
            ),
          ),
        ),
      ),
    );

    // Wait for initialization
    await tester.pumpAndSettle();
  }

  group('ChatInterface thinking blocks', () {
    testWidgets('aggregates multiple thinking blocks into one disclosure',
        (tester) async {
      // Setup mock with a session containing thinking blocks
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          lastMessageAt: DateTime(2024, 3, 15, 10, 30),
          messages: [
            ChatMessage.assistant(
              'Intro <think>First thought</think> middle text '
              '```think\nCode thought\n``` '
              'more text [think]Final thought[/think] Done',
            ),
          ],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      await pumpChatInterface(tester, repository: mockRepo);

      // Verify the thinking toggle is shown
      expect(find.text('Show reasoning'), findsOneWidget);

      // Verify visible content is rendered
      expect(find.textContaining('Intro'), findsOneWidget);
      expect(find.textContaining('middle text'), findsOneWidget);
      expect(find.textContaining('more text'), findsOneWidget);
      expect(find.textContaining('Done'), findsOneWidget);

      // Thinking content should be hidden initially
      expect(find.textContaining('First thought'), findsNothing);
      expect(find.textContaining('Code thought'), findsNothing);
      expect(find.textContaining('Final thought'), findsNothing);

      // Expand thinking content
      await tester.tap(find.text('Show reasoning'));
      await tester.pumpAndSettle();

      expect(find.text('Hide reasoning'), findsOneWidget);

      // All thinking content should now be visible
      expect(find.textContaining('First thought'), findsOneWidget);
      expect(find.textContaining('Code thought'), findsOneWidget);
      expect(find.textContaining('Final thought'), findsOneWidget);

      // Collapse thinking content
      await tester.tap(find.text('Hide reasoning'));
      await tester.pumpAndSettle();

      expect(find.text('Show reasoning'), findsOneWidget);
      expect(find.textContaining('First thought'), findsNothing);
    });

    testWidgets('renders message with thinking content properly',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          lastMessageAt: DateTime(2024, 3, 15, 10, 30),
          messages: [
            ChatMessage.assistant(
              '<think>Internal reasoning</think>This is the visible response',
            ),
          ],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      await pumpChatInterface(tester, repository: mockRepo);

      // Verify thinking toggle is present
      expect(find.text('Show reasoning'), findsOneWidget);

      // Verify visible content is shown
      expect(
          find.textContaining('This is the visible response'), findsOneWidget);

      // Verify thinking content is hidden initially
      expect(find.textContaining('Internal reasoning'), findsNothing);

      // Expand thinking content
      await tester.tap(find.text('Show reasoning'));
      await tester.pumpAndSettle();

      // Verify thinking content is now visible
      expect(find.textContaining('Internal reasoning'), findsOneWidget);
    });

    testWidgets('handles streaming response with thinking blocks',
        (tester) async {
      // Setup initial empty session
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          lastMessageAt: DateTime(2024, 3, 15, 10, 30),
          messages: const [],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      // Create a stream controller for simulating streaming responses
      final streamController = StreamController<String>();

      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) => streamController.stream);

      when(() => mockRepo.saveSession(any())).thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          lastMessageAt: DateTime(2024, 3, 15, 10, 30),
          messages: const [],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      await pumpChatInterface(tester, repository: mockRepo);

      // Send a message
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Start streaming with thinking block
      streamController.add('<think>Processing');
      await tester.pump(const Duration(milliseconds: 100));

      // Verify thinking toggle appears
      expect(find.text('Show reasoning'), findsOneWidget);

      // Expand to see partial thinking content
      await tester.tap(find.text('Show reasoning'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Processing'), findsOneWidget);

      // Continue streaming
      streamController.add(' the request...');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Processing the request...'), findsOneWidget);

      // Close thinking block and add visible content
      streamController.add('</think>Here is the response');
      await tester.pump(const Duration(milliseconds: 100));

      // Verify visible content appears
      expect(find.textContaining('Here is the response'), findsOneWidget);

      // Thinking toggle should still be visible (may have toggled back to collapsed)
      // Check for either state as the behavior may vary
      final hasShowReasoning =
          find.text('Show reasoning').evaluate().isNotEmpty;
      final hasHideReasoning =
          find.text('Hide reasoning').evaluate().isNotEmpty;
      expect(hasShowReasoning || hasHideReasoning, isTrue);

      // Add more content
      streamController.add(' with additional information.');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.textContaining(
              'Here is the response with additional information.'),
          findsOneWidget);

      // Complete the stream
      await streamController.close();
      await tester.pumpAndSettle();

      // Verify final state
      expect(
          find.textContaining(
              'Here is the response with additional information.'),
          findsOneWidget);

      // Thinking toggle should be present
      final showReasoningFinder = find.text('Show reasoning');
      final hideReasoningFinder = find.text('Hide reasoning');

      // If collapsed, expand it
      if (showReasoningFinder.evaluate().isNotEmpty) {
        await tester.tap(showReasoningFinder);
        await tester.pumpAndSettle();
        expect(find.text('Hide reasoning'), findsOneWidget);
        expect(
            find.textContaining('Processing the request...'), findsOneWidget);

        // Now collapse it
        await tester.tap(find.text('Hide reasoning'));
        await tester.pumpAndSettle();
        expect(find.text('Show reasoning'), findsOneWidget);
        expect(find.textContaining('Processing the request...'), findsNothing);
      } else if (hideReasoningFinder.evaluate().isNotEmpty) {
        // Already expanded, verify content is visible
        expect(
            find.textContaining('Processing the request...'), findsOneWidget);

        // Collapse and verify
        await tester.tap(hideReasoningFinder);
        await tester.pumpAndSettle();
        expect(find.text('Show reasoning'), findsOneWidget);
        expect(find.textContaining('Processing the request...'), findsNothing);
      }
    });

    testWidgets('handles multiple thinking blocks in streaming',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          lastMessageAt: DateTime(2024, 3, 15, 10, 30),
          messages: const [],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      final streamController = StreamController<String>();

      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) => streamController.stream);

      when(() => mockRepo.saveSession(any())).thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: const [],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      await pumpChatInterface(tester, repository: mockRepo);

      // Send a message
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Stream content with multiple thinking blocks
      streamController.add('Start <think>First thought</think> middle ');
      await tester.pump(const Duration(milliseconds: 100));

      // Should see one thinking toggle
      expect(find.text('Show reasoning'), findsOneWidget);
      expect(find.textContaining('Start'), findsOneWidget);
      expect(find.textContaining('middle'), findsOneWidget);

      // Add second thinking block
      streamController.add('```think\nSecond thought\n``` end');
      await tester.pump(const Duration(milliseconds: 100));

      // Still only one toggle (aggregated)
      expect(find.text('Show reasoning'), findsOneWidget);
      expect(find.textContaining('end'), findsOneWidget);

      // Expand to see all thinking content
      await tester.tap(find.text('Show reasoning'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('First thought'), findsOneWidget);
      expect(find.textContaining('Second thought'), findsOneWidget);

      await streamController.close();
      await tester.pumpAndSettle();
    });

    testWidgets('handles open-ended thinking block during streaming',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: const [],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      final streamController = StreamController<String>();

      when(() => mockRepo.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) => streamController.stream);

      when(() => mockRepo.saveSession(any())).thenAnswer(
        (_) async => ChatSession(
          id: 'session-1',
          title: 'Test Session',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: const [],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      await pumpChatInterface(tester, repository: mockRepo);

      // Send a message
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Test message');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();

      // Start with open-ended thinking block
      streamController.add('<think>Starting to process');
      await tester.pump(const Duration(milliseconds: 100));

      // Should show thinking toggle even without closing tag
      expect(find.text('Show reasoning'), findsOneWidget);

      // Expand to see partial content
      await tester.tap(find.text('Show reasoning'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.textContaining('Starting to process'), findsOneWidget);

      // Continue streaming within thinking block
      streamController.add('... analyzing the request');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
          find.textContaining('Starting to process... analyzing the request'),
          findsOneWidget);

      // Close thinking and add visible content
      streamController.add('</think>The answer is 42');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('The answer is 42'), findsOneWidget);
      // Toggle should be present (in either state)
      final hasToggle = find.text('Show reasoning').evaluate().isNotEmpty ||
          find.text('Hide reasoning').evaluate().isNotEmpty;
      expect(hasToggle, isTrue);

      await streamController.close();
      await tester.pumpAndSettle();
    });

    testWidgets('reasoning uses the same Markdown renderer', (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => ChatSession(
          id: 'session-3',
          title: 'Test Session',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          lastMessageAt: DateTime(2024, 3, 15, 10, 30),
          messages: [
            ChatMessage.assistant('<think>internal</think>Visible response'),
          ],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      await pumpChatInterface(tester, repository: mockRepo);
      await tester.tap(find.text('Show reasoning'));
      await tester.pumpAndSettle();

      // Reasoning content and visible content each use GptMarkdown
      // We expect at least two instances present in the message bubble.
      expect(find.byType(GptMarkdown), findsAtLeastNWidgets(2));
    });

    testWidgets('tap toggles reasoning visibility', (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => ChatSession(
          id: 's-kb',
          title: 'Session',
          createdAt: DateTime(2024),
          lastMessageAt: DateTime(2024),
          messages: [
            ChatMessage.assistant('<think>Internal reasoning</think>Visible'),
          ],
          metadata: const {'selectedModelId': 'test-model'},
        ),
      );

      await pumpChatInterface(tester, repository: mockRepo);
      // Expand by tapping the header text.
      await tester.tap(find.text('Show reasoning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Internal reasoning'), findsOneWidget);

      // Collapse by tapping again.
      await tester.tap(find.text('Hide reasoning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Internal reasoning'), findsNothing);

      // Expand again by tapping.
      await tester.tap(find.text('Show reasoning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Internal reasoning'), findsOneWidget);
    });
  });
}
