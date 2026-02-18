import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_message.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/providers/chat_model_providers.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/l10n/app_localizations.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeChatSession extends Fake implements ChatSession {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

/// Creates a test [ChatSession] with sensible defaults.
///
/// Most tests use a session with `selectedModelId`, so that's the default.
/// Pass `metadata: const {}` for the "no model selected" case, or `null` to
/// omit metadata entirely.
ChatSession _createSession({
  String id = 'test-session',
  String title = 'New Chat',
  List<ChatMessage> messages = const [],
  Map<String, dynamic>? metadata = const {'selectedModelId': 'test-model'},
}) =>
    ChatSession(
      id: id,
      title: title,
      createdAt: DateTime(2024),
      lastMessageAt: DateTime(2024),
      messages: messages,
      metadata: metadata,
    );

/// Stubs `createSession`, `getSession`, and `saveSession` on the given
/// repository to return [session].
void _stubRepository(
  MockChatRepository repo, {
  required ChatSession session,
  String categoryId = 'test-category',
}) {
  when(() => repo.createSession(categoryId: categoryId))
      .thenAnswer((_) async => session);
  when(() => repo.getSession(any())).thenAnswer((_) async => session);
  when(() => repo.saveSession(any())).thenAnswer((_) async => session);
}

/// Pumps a [ChatInterface] inside a localised [MaterialApp] with provider
/// overrides and a generous viewport.
Future<void> _pumpChatInterface(
  WidgetTester tester, {
  required MockChatRepository chatRepository,
  String categoryId = 'test-category',
  String? sessionId,
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = const Size(1400, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() => tester.view.reset());

  final allOverrides = [
    chatRepositoryProvider.overrideWithValue(chatRepository),
    ...extraOverrides,
  ];

  // Add default empty models override unless the test provides one
  final hasModelsOverride = allOverrides.any(
    (o) => o.toString().contains('AiConfigModel'),
  );
  if (!hasModelsOverride) {
    allOverrides.add(
      eligibleChatModelsForCategoryProvider(categoryId)
          .overrideWith((_) async => []),
    );
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: allOverrides,
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatInterface(
            categoryId: categoryId,
            sessionId: sessionId,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeChatSession());
  });

  group('ChatInterface', () {
    late MockChatRepository mockChatRepository;
    late MockLoggingService mockLoggingService;

    setUp(() {
      // Isolate GetIt state per test for optimized runners
      GetIt.instance.pushNewScope();
      mockChatRepository = MockChatRepository();
      mockLoggingService = MockLoggingService();

      GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
    });

    tearDown(() async {
      await GetIt.instance.resetScope();
      await GetIt.instance.popScope();
    });

    testWidgets('displays empty state when no messages', (tester) async {
      final session = _createSession();
      _stubRepository(mockChatRepository, session: session);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.psychology_outlined), findsWidgets);
      expect(find.text('Ask me about your tasks'), findsOneWidget);
      expect(
        find.text(
          'I can help analyze your productivity patterns, summarize '
          'completed tasks, and provide insights about your work habits.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'shows "No eligible models" inside settings sheet when none',
      (tester) async {
        final mockAiRepo = MockAiConfigRepository();
        when(() => mockAiRepo.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => []);
        when(() => mockAiRepo.getConfigsByType(AiConfigType.inferenceProvider))
            .thenAnswer((_) async => []);

        final session = _createSession();
        _stubRepository(mockChatRepository, session: session);

        await _pumpChatInterface(
          tester,
          chatRepository: mockChatRepository,
          extraOverrides: [
            aiConfigRepositoryProvider.overrideWithValue(mockAiRepo),
          ],
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Assistant settings'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Assistant Settings'), findsOneWidget);
        expect(find.text('No eligible models'), findsOneWidget);
      },
    );

    testWidgets('input disabled and settings action when no model selected',
        (tester) async {
      final session = _createSession(metadata: const {});
      _stubRepository(mockChatRepository, session: session);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      final tf = tester.widget<TextField>(
        find.byKey(const ValueKey('chat_text_field')),
      );
      expect(tf.enabled, isFalse);
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

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.error_outline), findsNothing);
    });

    testWidgets('error banner retry calls retryLastMessage', (tester) async {
      final session = _createSession(
        title: 'Test Chat',
        messages: [ChatMessage.user('Hello')],
      );

      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => session);
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => session);

      var sendCallCount = 0;
      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) {
        sendCallCount++;
        if (sendCallCount == 1) {
          return Stream<String>.error(Exception('Network error'));
        }
        return Stream.value('Response');
      });
      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => session);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(sendCallCount, 2);
    });

    testWidgets('clear chat button clears the conversation', (tester) async {
      final sessionWithMessages = _createSession(
        title: 'Test Chat',
        messages: [
          ChatMessage.user('Hello'),
          ChatMessage.assistant('Hi there!'),
        ],
      );
      final emptySession = _createSession(id: 'new-session');

      var createCallCount = 0;
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async {
        createCallCount++;
        return createCallCount == 1 ? sessionWithMessages : emptySession;
      });
      when(() => mockChatRepository.getSession(any()))
          .thenAnswer((_) async => sessionWithMessages);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.clear_all));
      await tester.pumpAndSettle();

      expect(createCallCount, 2);
    });

    testWidgets('displays empty state with helper text', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.text('Ask me about your tasks'), findsOneWidget);
      expect(
        find.textContaining('I can help analyze your productivity patterns'),
        findsOneWidget,
      );
    });

    testWidgets('displays header with session title', (tester) async {
      final session = _createSession(title: 'My Test Chat');
      _stubRepository(mockChatRepository, session: session);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.text('AI Assistant'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      expect(find.text('My Test Chat'), findsOneWidget);
      expect(find.byIcon(Icons.add_comment_outlined), findsOneWidget);
    });

    testWidgets('displays messages when they exist', (tester) async {
      final session = _createSession(
        title: 'Chat with Messages',
        messages: [
          ChatMessage.user('Hello, how are you?'),
          ChatMessage.assistant('I am doing well, thank you for asking!'),
        ],
      );
      _stubRepository(mockChatRepository, session: session);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Hello, how are you?'), findsOneWidget);
      expect(
        find.text('I am doing well, thank you for asking!'),
        findsOneWidget,
      );

      expect(find.byIcon(Icons.person), findsNothing);
      expect(find.byIcon(Icons.psychology), findsNothing);
      expect(find.byIcon(Icons.copy), findsOneWidget);
    });

    testWidgets('shows clear chat button when messages exist', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession(
                title: 'Chat with Messages',
                messages: [ChatMessage.user('Hello')],
              ));

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear_all), findsOneWidget);
    });

    testWidgets('hides clear chat button when no messages', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession(title: 'Empty Chat'));

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear_all), findsNothing);
    });

    testWidgets('displays input field and send button', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(
        find.text('Ask about your tasks and productivity...'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('shows error banner when error exists', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenThrow(Exception('Connection failed'));

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('sends message when send button pressed', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) async* {
        yield 'Hello there!';
      });

      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => _createSession());

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello, AI!');
      await tester.pump();

      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.send), findsOneWidget);

      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      verify(() => mockChatRepository.sendMessage(
            message: 'Hello, AI!',
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: 'test-category',
            modelId: 'test-model',
          )).called(1);
    });

    testWidgets('sends message when Enter key pressed', (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) async* {
        yield 'Response via Enter key!';
      });

      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => _createSession());

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello via Enter!');
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

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
          .thenAnswer((_) async => _createSession(metadata: null));

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('AI Assistant'), findsOneWidget);
    });

    testWidgets('shows streaming indicator when message is streaming',
        (tester) async {
      when(() => mockChatRepository.createSession(categoryId: 'test-category'))
          .thenAnswer((_) async => _createSession());

      final streamController = StreamController<String>();
      when(() => mockChatRepository.sendMessage(
            message: any(named: 'message'),
            conversationHistory: any(named: 'conversationHistory'),
            categoryId: any(named: 'categoryId'),
            modelId: any(named: 'modelId'),
          )).thenAnswer((_) => streamController.stream);

      when(() => mockChatRepository.saveSession(any()))
          .thenAnswer((_) async => _createSession());

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Test message');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.send));
      await tester.pump();
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      streamController.add('Hello');
      await tester.pump();
      expect(find.text('Hello'), findsOneWidget);

      streamController.add(' world!');
      await streamController.close();
      await tester.pumpAndSettle();

      expect(find.text('Hello world!'), findsOneWidget);
    });

    testWidgets('accepts sessionId parameter', (tester) async {
      final existingSession = _createSession(
        id: 'existing-session-id',
        title: 'Existing Chat',
        messages: [ChatMessage.user('Previous message')],
        metadata: null,
      );

      when(() => mockChatRepository.getSession('existing-session-id'))
          .thenAnswer((_) async => existingSession);

      await _pumpChatInterface(
        tester,
        chatRepository: mockChatRepository,
        sessionId: 'existing-session-id',
      );
      await tester.pumpAndSettle();

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

        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenAnswer((_) async => _createSession(
                  id: 's1',
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
            .thenAnswer((_) async => _createSession(
                  id: 's1',
                  metadata: const {'selectedModelId': 'm1'},
                ));

        await _pumpChatInterface(
          tester,
          chatRepository: mockChatRepository,
          extraOverrides: [
            aiConfigRepositoryProvider.overrideWithValue(mockAiRepo),
            eligibleChatModelsForCategoryProvider('test-category')
                .overrideWith((_) async => [model]),
          ],
        );
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), 'Hi');
        await tester.pump();
        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        await tester.tap(find.byTooltip('Assistant settings'));
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Assistant Settings'), findsOneWidget);
        final dd = tester.widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>));
        expect(dd.onChanged, isNull);

        await streamController.close();
        await tester.pump(const Duration(milliseconds: 250));
      },
    );

    testWidgets(
      'new chat button triggers session creation',
      (tester) async {
        var callCount = 0;
        when(() =>
                mockChatRepository.createSession(categoryId: 'test-category'))
            .thenAnswer((_) async {
          callCount++;
          return _createSession(
            id: 's-new-$callCount',
            title: 'New Chat $callCount',
          );
        });

        await _pumpChatInterface(tester, chatRepository: mockChatRepository);
        await tester.pumpAndSettle();

        expect(callCount, 1);

        await tester.tap(find.byIcon(Icons.add_comment_outlined));
        await tester.pumpAndSettle();

        expect(callCount, 2);
      },
    );

    testWidgets('shows mic button when input is empty', (tester) async {
      final session = _createSession();
      _stubRepository(mockChatRepository, session: session);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });

    testWidgets('shows send button when text is entered', (tester) async {
      final session = _createSession();
      _stubRepository(mockChatRepository, session: session);

      await _pumpChatInterface(tester, chatRepository: mockChatRepository);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pump();

      expect(find.byIcon(Icons.mic), findsNothing);
      expect(find.byIcon(Icons.send), findsOneWidget);

      await tester.enterText(find.byType(TextField), '');
      await tester.pump();

      expect(find.byIcon(Icons.mic), findsOneWidget);
      expect(find.byIcon(Icons.send), findsNothing);
    });
  });
}
