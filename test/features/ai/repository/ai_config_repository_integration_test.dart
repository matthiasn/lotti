import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';

void main() {
  group('AiConfigRepository integration tests', () {
    late AiConfigDb db;
    late AiConfigRepository repository;

    setUp(() async {
      db = AiConfigDb(inMemoryDatabase: true);
      repository = AiConfigRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('should store and retrieve multiple config types', () async {
      // Create API key config
      final apiKeyConfig = AiConfig.apiKey(
        id: 'openai-key',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-1234567890abcdef',
        name: 'OpenAI API Key',
        createdAt: DateTime.now(),
        supportsThinkingOutput: true,
      );

      // Create prompt template config
      final promptConfig = AiConfig.promptTemplate(
        id: 'summarize-prompt',
        name: 'Summarization Template',
        template: 'Please summarize the following text: {{text}}',
        createdAt: DateTime.now(),
        description: 'Template for text summarization',
        defaultVariables: {'text': 'Enter text to summarize'},
        category: 'Summarization',
      );

      // Save both configs
      await repository.saveConfig(apiKeyConfig);
      await repository.saveConfig(promptConfig);

      // Retrieve and check API key config
      final retrievedApiConfig = await repository.getConfigById('openai-key');
      expect(retrievedApiConfig, isNotNull);

      // Use maybeMap to check the type and fields
      retrievedApiConfig?.maybeMap(
        apiKey: (config) {
          expect(config.id, equals('openai-key'));
          expect(config.baseUrl, equals('https://api.openai.com/v1'));
          expect(config.apiKey, equals('sk-1234567890abcdef'));
          expect(config.supportsThinkingOutput, isTrue);
        },
        orElse: () => fail('Retrieved config is not an API key config'),
      );

      // Retrieve and check prompt template config
      final retrievedPromptConfig =
          await repository.getConfigById('summarize-prompt');
      expect(retrievedPromptConfig, isNotNull);

      // Use maybeMap to check the type and fields
      retrievedPromptConfig?.maybeMap(
        promptTemplate: (config) {
          expect(config.id, equals('summarize-prompt'));
          expect(config.name, equals('Summarization Template'));
          expect(config.template, contains('Please summarize'));
          expect(config.category, equals('Summarization'));
        },
        orElse: () => fail('Retrieved config is not a prompt template config'),
      );

      // Watch by type tests
      await expectLater(
        repository.watchConfigsByType('_AiConfigApiKey'),
        emits(
          predicate<List<AiConfig>>((configs) {
            return configs.length == 1 && configs.first.id == 'openai-key';
          }),
        ),
      );

      await expectLater(
        repository.watchConfigsByType('_AiConfigPromptTemplate'),
        emits(
          predicate<List<AiConfig>>((configs) {
            return configs.length == 1 &&
                configs.first.id == 'summarize-prompt';
          }),
        ),
      );
    });
  });
}
