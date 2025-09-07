import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai_chat/models/chat_session.dart';
import 'package:lotti/features/ai_chat/repository/chat_repository.dart';
import 'package:lotti/features/ai_chat/ui/widgets/chat_interface.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockChatRepository extends Mock implements ChatRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  setUpAll(() {
    // Required when verifying saveSession argument types in mocktail
    registerFallbackValue(ChatSession(
      id: 'fallback',
      title: 'f',
      createdAt: DateTime(2024),
      lastMessageAt: DateTime(2024),
      messages: const [],
    ));
  });

  testWidgets('shows model dropdown and persists selection', (tester) async {
    final mockChatRepository = MockChatRepository();
    final mockLoggingService = MockLoggingService();
    final mockAiRepo = MockAiConfigRepository();

    // Register GetIt services used by providers
    if (!GetIt.instance.isRegistered<LoggingService>()) {
      GetIt.instance.registerSingleton<LoggingService>(mockLoggingService);
    }

    final provider = AiConfigInferenceProvider(
      id: 'prov-g',
      name: 'Gemini Provider',
      baseUrl: 'https://gemini',
      apiKey: 'k',
      createdAt: DateTime(2024),
      inferenceProviderType: InferenceProviderType.gemini,
    );
    final model = AiConfigModel(
      id: 'model-1',
      name: 'Gemini Flash',
      providerModelId: 'gemini-flash-1.5',
      inferenceProviderId: provider.id,
      createdAt: DateTime(2024),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: false,
      supportsFunctionCalling: true,
    );

    when(() => mockAiRepo.getConfigsByType(AiConfigType.inferenceProvider))
        .thenAnswer((_) async => [provider]);
    when(() => mockAiRepo.getConfigsByType(AiConfigType.model))
        .thenAnswer((_) async => [model]);

    when(() => mockChatRepository.createSession(categoryId: 'cat'))
        .thenAnswer((_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
            ));

    when(() => mockChatRepository.saveSession(any()))
        .thenAnswer((_) async => ChatSession(
              id: 's1',
              title: 'New Chat',
              createdAt: DateTime(2024),
              lastMessageAt: DateTime(2024),
              messages: const [],
              metadata: const {'selectedModelId': 'model-1'},
            ));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          chatRepositoryProvider.overrideWithValue(mockChatRepository),
          aiConfigRepositoryProvider.overrideWithValue(mockAiRepo),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ChatInterface(categoryId: 'cat'),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Dropdown should be present with hint
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('Select model'), findsOneWidget);

    // Open and select the single model option
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini Flash').last);
    await tester.pumpAndSettle();

    // After selection, the input hint should change (canSend becomes true)
    expect(
        find.text('Ask about your tasks and productivity...'), findsOneWidget);

    // Verify persistence via repository
    verify(() => mockChatRepository.saveSession(any())).called(1);
  });
}
