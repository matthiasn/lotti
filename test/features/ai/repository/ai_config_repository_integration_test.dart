import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:mocktail/mocktail.dart';

class MockOutboxService extends Mock implements OutboxService {}

void main() {
  late GetIt getIt;
  late MockOutboxService mockOutboxService;

  setUpAll(() {
    // Register a fallback value for SyncMessage
    registerFallbackValue(
      SyncMessage.aiConfig(
        aiConfig: AiConfig.inferenceProvider(
          id: 'fallback-id',
          baseUrl: 'https://fallback.example.com',
          apiKey: 'fallback-key',
          name: 'Fallback API',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        ),
        status: SyncEntryStatus.initial,
      ),
    );

    // Set up GetIt
    getIt = GetIt.instance;
  });

  group('AiConfigRepository integration tests', () {
    late AiConfigDb db;
    late AiConfigRepository repository;

    setUp(() async {
      // Set up a fresh mock for each test
      mockOutboxService = MockOutboxService();

      // Register the mock with GetIt
      if (getIt.isRegistered<OutboxService>()) {
        getIt.unregister<OutboxService>();
      }
      getIt.registerSingleton<OutboxService>(mockOutboxService);

      // Set up default behavior
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      db = AiConfigDb(inMemoryDatabase: true);
      repository = AiConfigRepository(db);
    });

    tearDown(() async {
      await db.close();

      // Clean up GetIt registrations
      if (getIt.isRegistered<OutboxService>()) {
        getIt.unregister<OutboxService>();
      }
    });

    test('should store and retrieve multiple config types', () async {
      // Create API key config
      final apiKeyConfig = AiConfig.inferenceProvider(
        id: 'openai-key',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-1234567890abcdef',
        name: 'OpenAI API Key',
        createdAt: DateTime.now(),
        description: 'Test API key for OpenAI integration',
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      // Create prompt template config
      final promptConfig = AiConfig.prompt(
        id: 'summarize-prompt',
        name: 'Summarization Template',
        template: 'Please summarize the following text: {{text}}',
        createdAt: DateTime.now(),
        description: 'Template for text summarization',
        defaultVariables: {'text': 'Enter text to summarize'},
        category: 'Summarization',
        modelId: 'model-id1',
        useReasoning: false,
        requiredInputData: [],
      );

      // Save both configs
      await repository.saveConfig(apiKeyConfig);
      await repository.saveConfig(promptConfig);

      // Verify OutboxService was called twice (once for each config)
      verify(() => mockOutboxService.enqueueMessage(any())).called(2);

      // Retrieve and check API key config
      final retrievedApiConfig = await repository.getConfigById('openai-key');
      expect(retrievedApiConfig, isNotNull);

      // Use maybeMap to check the type and fields
      retrievedApiConfig?.maybeMap(
        inferenceProvider: (config) {
          expect(config.id, equals('openai-key'));
          expect(config.baseUrl, equals('https://api.openai.com/v1'));
          expect(config.apiKey, equals('sk-1234567890abcdef'));
          expect(
            config.description,
            equals('Test API key for OpenAI integration'),
          );
        },
        orElse: () => fail('Retrieved config is not an API key config'),
      );

      // Retrieve and check prompt template config
      final retrievedPromptConfig =
          await repository.getConfigById('summarize-prompt');
      expect(retrievedPromptConfig, isNotNull);

      // Use maybeMap to check the type and fields
      retrievedPromptConfig?.maybeMap(
        prompt: (config) {
          expect(config.id, equals('summarize-prompt'));
          expect(config.name, equals('Summarization Template'));
          expect(config.template, contains('Please summarize'));
          expect(config.category, equals('Summarization'));
        },
        orElse: () => fail('Retrieved config is not a prompt template config'),
      );

      // Watch by type tests
      await expectLater(
        repository.watchConfigsByType('inferenceProvider'),
        emits(
          predicate<List<AiConfig>>(
            (configs) =>
                configs.length == 1 && configs.first.id == 'openai-key',
          ),
        ),
      );

      await expectLater(
        repository.watchConfigsByType('prompt'),
        emits(
          predicate<List<AiConfig>>(
            (configs) =>
                configs.length == 1 && configs.first.id == 'summarize-prompt',
          ),
        ),
      );
    });
  });
}
