import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../../mocks/mocks.dart';

/// Creates a test [ChatSession] with sensible defaults for thinking tests.
ChatSession _createSession({
  String id = 'session-1',
  String title = 'Test Session',
  List<ChatMessage> messages = const [],
}) =>
    ChatSession(
      id: id,
      title: title,
      createdAt: DateTime(2024, 3, 15, 10, 30),
      lastMessageAt: DateTime(2024, 3, 15, 10, 30),
      messages: messages,
      metadata: const {'selectedModelId': 'test-model'},
    );

/// Stubs `sendMessage` with a stream controller and stubs `saveSession`.
/// Returns the controller so the test can push events.
StreamController<String> _stubStreaming(MockChatRepository repo) {
  final controller = StreamController<String>();
  when(() => repo.sendMessage(
        message: any(named: 'message'),
        conversationHistory: any(named: 'conversationHistory'),
        categoryId: any(named: 'categoryId'),
        modelId: any(named: 'modelId'),
      )).thenAnswer((_) => controller.stream);
  when(() => repo.saveSession(any())).thenAnswer((_) async => _createSession());
  return controller;
}

/// Pumps a [ChatInterface] with the given [repository] and localization.
Future<void> _pumpChatInterface(
  WidgetTester tester, {
  required MockChatRepository repository,
  String categoryId = 'test-category',
}) async {
  tester.view.physicalSize = const Size(800, 1200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        chatRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInterface(categoryId: categoryId),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

/// Sends a message in the chat and starts streaming. Call after
/// [_pumpChatInterface].
Future<void> _sendMessage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump();
}

void main() {
  late MockChatRepository mockRepo;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });

  setUp(() {
    GetIt.instance.pushNewScope();
    mockRepo = MockChatRepository();
    mockLoggingService = MockLoggingService();
    GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);

    when(() => mockLoggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String?>(named: 'subDomain'),
          stackTrace: any<dynamic>(named: 'stackTrace'),
        )).thenReturn(null);
  });

  tearDown(() async {
    await GetIt.instance.resetScope();
    await GetIt.instance.popScope();
  });

  group('ChatInterface thinking blocks', () {
    testWidgets('renders separate disclosures for multiple thinking blocks',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => _createSession(
          messages: [
            ChatMessage.assistant(
              'Intro <think>First thought</think> middle text '
              '```think\nCode thought\n``` '
              'more text [think]Final thought[/think] Done',
            ),
          ],
        ),
      );

      await _pumpChatInterface(tester, repository: mockRepo);

      expect(find.text('Show reasoning'), findsNWidgets(3));

      expect(find.textContaining('Intro'), findsOneWidget);
      expect(find.textContaining('middle text'), findsOneWidget);
      expect(find.textContaining('more text'), findsOneWidget);
      expect(find.textContaining('Done'), findsOneWidget);

      expect(find.textContaining('First thought'), findsNothing);
      expect(find.textContaining('Code thought'), findsNothing);
      expect(find.textContaining('Final thought'), findsNothing);

      for (final e in find.text('Show reasoning').evaluate().toList()) {
        await tester.tap(find.byWidget(e.widget));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('First thought'), findsOneWidget);
      expect(find.textContaining('Code thought'), findsOneWidget);
      expect(find.textContaining('Final thought'), findsOneWidget);
    });

    testWidgets('renders message with thinking content properly',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => _createSession(
          messages: [
            ChatMessage.assistant(
              '<think>Internal reasoning</think>This is the visible response',
            ),
          ],
        ),
      );

      await _pumpChatInterface(tester, repository: mockRepo);

      expect(find.text('Show reasoning'), findsOneWidget);
      expect(
        find.textContaining('This is the visible response'),
        findsOneWidget,
      );
      expect(find.textContaining('Internal reasoning'), findsNothing);

      await tester.tap(find.text('Show reasoning'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Internal reasoning'), findsOneWidget);
    });

    testWidgets('handles streaming response with thinking blocks',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      final streamController = _stubStreaming(mockRepo);

      await _pumpChatInterface(tester, repository: mockRepo);
      await _sendMessage(tester, 'Test message');

      // Start streaming with open thinking block; toggle not shown until close
      streamController.add('<think>Processing');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Show reasoning'), findsNothing);

      streamController.add(' the request...');
      await tester.pump(const Duration(milliseconds: 100));

      streamController.add('</think>Here is the response');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('Here is the response'), findsOneWidget);

      if (find.text('Show reasoning').evaluate().isNotEmpty) {
        await tester.tap(find.text('Show reasoning').first);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('Processing the request...'), findsOneWidget);

      expect(
        find.text('Show reasoning').evaluate().isNotEmpty ||
            find.text('Hide reasoning').evaluate().isNotEmpty,
        isTrue,
      );

      streamController.add(' with additional information.');
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.textContaining(
          'Here is the response with additional information.',
        ),
        findsOneWidget,
      );

      await streamController.close();
      await tester.pumpAndSettle();

      expect(
        find.textContaining(
          'Here is the response with additional information.',
        ),
        findsOneWidget,
      );

      final showReasoningFinder = find.text('Show reasoning');
      final hideReasoningFinder = find.text('Hide reasoning');

      if (showReasoningFinder.evaluate().isNotEmpty) {
        await tester.tap(showReasoningFinder);
        await tester.pumpAndSettle();
        expect(find.text('Hide reasoning'), findsOneWidget);
        expect(
          find.textContaining('Processing the request...'),
          findsOneWidget,
        );

        await tester.tap(find.text('Hide reasoning'));
        await tester.pumpAndSettle();
        expect(find.text('Show reasoning'), findsOneWidget);
        expect(find.textContaining('Processing the request...'), findsNothing);
      } else if (hideReasoningFinder.evaluate().isNotEmpty) {
        expect(
          find.textContaining('Processing the request...'),
          findsOneWidget,
        );

        await tester.tap(hideReasoningFinder);
        await tester.pumpAndSettle();
        expect(find.text('Show reasoning'), findsOneWidget);
        expect(find.textContaining('Processing the request...'), findsNothing);
      }
    });

    testWidgets('handles multiple thinking blocks in streaming',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      final streamController = _stubStreaming(mockRepo);

      await _pumpChatInterface(tester, repository: mockRepo);
      await _sendMessage(tester, 'Test message');

      streamController.add('Start <think>First thought</think> middle ');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Show reasoning'), findsAtLeastNWidgets(1));
      expect(find.textContaining('Start'), findsOneWidget);
      expect(find.textContaining('middle'), findsOneWidget);

      streamController.add('```think\nSecond thought\n``` end');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Show reasoning'), findsAtLeastNWidgets(1));
      expect(find.textContaining('end'), findsOneWidget);

      for (final e in find.text('Show reasoning').evaluate().toList()) {
        await tester.tap(find.byWidget(e.widget));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.textContaining('First thought'), findsOneWidget);
      expect(find.textContaining('Second thought'), findsOneWidget);

      await streamController.close();
      await tester.pumpAndSettle();
    });

    testWidgets('handles open-ended thinking block during streaming',
        (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      final streamController = _stubStreaming(mockRepo);

      await _pumpChatInterface(tester, repository: mockRepo);
      await _sendMessage(tester, 'Test message');

      streamController.add('<think>Starting to process');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Show reasoning'), findsNothing);

      streamController.add('... analyzing the request');
      await tester.pump(const Duration(milliseconds: 100));

      streamController.add('</think>The answer is 42');
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('The answer is 42'), findsOneWidget);
      final hasToggle = find.text('Show reasoning').evaluate().isNotEmpty ||
          find.text('Hide reasoning').evaluate().isNotEmpty;
      expect(hasToggle, isTrue);
      if (find.text('Show reasoning').evaluate().isNotEmpty) {
        await tester.tap(find.text('Show reasoning').first);
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.textContaining('Starting to process... analyzing the request'),
        findsOneWidget,
      );

      await streamController.close();
      await tester.pumpAndSettle();
    });

    testWidgets('reasoning uses the same Markdown renderer', (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => _createSession(
          id: 'session-3',
          messages: [
            ChatMessage.assistant('<think>internal</think>Visible response'),
          ],
        ),
      );

      await _pumpChatInterface(tester, repository: mockRepo);
      await tester.tap(find.text('Show reasoning'));
      await tester.pumpAndSettle();

      expect(find.byType(GptMarkdown), findsAtLeastNWidgets(2));
    });

    testWidgets('tap toggles reasoning visibility', (tester) async {
      when(() => mockRepo.createSession(categoryId: 'test-category'))
          .thenAnswer(
        (_) async => _createSession(
          id: 's-kb',
          title: 'Session',
          messages: [
            ChatMessage.assistant('<think>Internal reasoning</think>Visible'),
          ],
        ),
      );

      await _pumpChatInterface(tester, repository: mockRepo);

      await tester.tap(find.text('Show reasoning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Internal reasoning'), findsOneWidget);

      await tester.tap(find.text('Hide reasoning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Internal reasoning'), findsNothing);

      await tester.tap(find.text('Show reasoning'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('Internal reasoning'), findsOneWidget);
    });
  });
}
