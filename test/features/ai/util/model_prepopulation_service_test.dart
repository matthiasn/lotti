import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/model_prepopulation_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class FakeAiConfig extends Fake implements AiConfig {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeAiConfig());
  });

  group('ModelPrepopulationService', () {
    late MockAiConfigRepository mockRepository;
    late ModelPrepopulationService service;

    setUp(() {
      mockRepository = MockAiConfigRepository();
      service = ModelPrepopulationService(repository: mockRepository);
    });

    group('prepopulateModelsForProvider', () {
      test('should create all known models for Gemini provider', () async {
        // Arrange
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => []);

        when(() => mockRepository.saveConfig(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(result, equals(geminiModels.length));
        verify(() => mockRepository.saveConfig(any()))
            .called(geminiModels.length);
      });

      test('should create all known models for Nebius provider', () async {
        // Arrange
        const providerId = 'nebius-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.nebius.com',
          apiKey: 'test-key',
          name: 'Nebius',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.nebiusAiStudio,
        );

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => []);

        when(() => mockRepository.saveConfig(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(result, equals(nebiusModels.length));
        verify(() => mockRepository.saveConfig(any()))
            .called(nebiusModels.length);
      });

      test('should create all known models for Ollama provider', () async {
        // Arrange
        const providerId = 'ollama-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'http://localhost:11434',
          apiKey: '',
          name: 'Ollama',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.ollama,
        );

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => []);

        when(() => mockRepository.saveConfig(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(result, equals(ollamaModels.length));
        verify(() => mockRepository.saveConfig(any()))
            .called(ollamaModels.length);
      });

      test('should skip existing models and only create new ones', () async {
        // Arrange
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        // Simulate that one model already exists
        final existingModelId = generateModelId(
          providerId,
          geminiModels.first.providerModelId,
        );
        final existingModel = AiConfigModel(
          id: existingModelId,
          name: 'Existing Model',
          providerModelId: geminiModels.first.providerModelId,
          inferenceProviderId: providerId,
          createdAt: DateTime.now(),
          inputModalities: [],
          outputModalities: [],
          isReasoningModel: false,
        );

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => [existingModel]);

        when(() => mockRepository.saveConfig(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(result, equals(geminiModels.length - 1));
        verify(() => mockRepository.saveConfig(any()))
            .called(geminiModels.length - 1);
      });

      test('should return 0 when provider has no known models', () async {
        // Arrange
        final provider = AiConfigInferenceProvider(
          id: 'generic-provider-id',
          baseUrl: 'https://api.generic.com',
          apiKey: 'test-key',
          name: 'Generic',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        // Act
        final result = await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(result, equals(0));
        verifyNever(() => mockRepository.saveConfig(any()));
      });

      test('should create models with correct properties', () async {
        // Arrange
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        AiConfigModel? capturedModel;
        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => []);

        when(() => mockRepository.saveConfig(any()))
            .thenAnswer((invocation) async {
          capturedModel = invocation.positionalArguments[0] as AiConfigModel;
        });

        // Act
        await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(capturedModel, isNotNull);
        expect(capturedModel!.inferenceProviderId, equals(providerId));
        expect(capturedModel!.inputModalities, contains(Modality.text));
        expect(capturedModel!.description, isNotEmpty);
      });
    });

    group('ensureModelsForProvider', () {
      test('should prepopulate models when provider exists', () async {
        // Arrange
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime.now(),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        when(() => mockRepository.getConfigById(providerId))
            .thenAnswer((_) async => provider);

        when(() => mockRepository.getConfigsByType(AiConfigType.model))
            .thenAnswer((_) async => []);

        when(() => mockRepository.saveConfig(any()))
            .thenAnswer((_) async => {});

        // Act
        final result = await service.ensureModelsForProvider(providerId);

        // Assert
        expect(result, equals(geminiModels.length));
      });

      test('should return 0 when provider does not exist', () async {
        // Arrange
        const providerId = 'non-existent-id';

        when(() => mockRepository.getConfigById(providerId))
            .thenAnswer((_) async => null);

        // Act
        final result = await service.ensureModelsForProvider(providerId);

        // Assert
        expect(result, equals(0));
        verifyNever(() => mockRepository.saveConfig(any()));
      });

      test('should return 0 when config is not a provider', () async {
        // Arrange
        const providerId = 'prompt-id';
        final prompt = AiConfigPrompt(
          id: providerId,
          name: 'Test Prompt',
          systemMessage: 'System',
          userMessage: 'User',
          defaultModelId: 'model-id',
          modelIds: ['model-id'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [],
          aiResponseType: AiResponseType.taskSummary,
        );

        when(() => mockRepository.getConfigById(providerId))
            .thenAnswer((_) async => prompt);

        // Act
        final result = await service.ensureModelsForProvider(providerId);

        // Assert
        expect(result, equals(0));
        verifyNever(() => mockRepository.saveConfig(any()));
      });
    });

    group('getModelIdsForProviderType', () {
      test('should return correct model IDs for Gemini', () {
        // Arrange
        const providerId = 'gemini-provider-id';

        // Act
        final result = service.getModelIdsForProviderType(
          providerId,
          InferenceProviderType.gemini,
        );

        // Assert
        expect(result.length, equals(geminiModels.length));
        // Check that IDs contain the transformed provider ID (hyphens replaced with underscores)
        final transformedProviderId = providerId.replaceAll('-', '_');
        expect(
            result.every((id) => id.contains(transformedProviderId)), isTrue);
        expect(result.every((id) => !id.contains('/')), isTrue);
        expect(result.every((id) => !id.contains(':')), isTrue);
        expect(result.every((id) => !id.contains('-')), isTrue);
      });

      test('should return empty list for unknown provider type', () {
        // Arrange
        const providerId = 'generic-provider-id';

        // Act
        final result = service.getModelIdsForProviderType(
          providerId,
          InferenceProviderType.genericOpenAi,
        );

        // Assert
        expect(result, isEmpty);
      });
    });
  });

  group('generateModelId', () {
    test('should replace problematic characters', () {
      // Test various problematic characters
      final id = generateModelId(
        'provider-id',
        'models/gemini-2.0-pro:latest',
      );

      expect(id, equals('provider_id_models_gemini_2_0_pro_latest'));
      expect(id.contains('/'), isFalse);
      expect(id.contains(':'), isFalse);
      expect(id.contains('-'), isFalse);
      expect(id.contains('.'), isFalse);
    });

    test('should convert to lowercase', () {
      final id = generateModelId(
        'PROVIDER-ID',
        'MODELS/GEMINI',
      );

      expect(id, equals('provider_id_models_gemini'));
      expect(id, equals(id.toLowerCase()));
    });
  });

  group('KnownModel', () {
    test('should convert to AiConfigModel correctly', () {
      // Arrange
      const knownModel = KnownModel(
        providerModelId: 'test-model-id',
        name: 'Test Model',
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text],
        isReasoningModel: true,
        description: 'Test description',
      );

      // Act
      final aiConfigModel = knownModel.toAiConfigModel(
        id: 'generated-id',
        inferenceProviderId: 'provider-id',
      );

      // Assert
      expect(aiConfigModel.id, equals('generated-id'));
      expect(aiConfigModel.name, equals('Test Model'));
      expect(aiConfigModel.providerModelId, equals('test-model-id'));
      expect(aiConfigModel.inferenceProviderId, equals('provider-id'));
      expect(aiConfigModel.inputModalities,
          equals([Modality.text, Modality.image]));
      expect(aiConfigModel.outputModalities, equals([Modality.text]));
      expect(aiConfigModel.isReasoningModel, isTrue);
      expect(aiConfigModel.description, equals('Test description'));
      expect(aiConfigModel.createdAt, isNotNull);
    });
  });

  group('Known Models Configuration', () {
    test('all known models should have valid configurations', () {
      for (final providerType in InferenceProviderType.values) {
        final models = knownModelsByProvider[providerType];
        if (models != null) {
          for (final model in models) {
            expect(model.providerModelId, isNotEmpty);
            expect(model.name, isNotEmpty);
            expect(model.inputModalities, isNotEmpty);
            expect(model.outputModalities, isNotEmpty);
            expect(model.description, isNotEmpty);
          }
        }
      }
    });

    test('reasoning models should have appropriate input modalities', () {
      for (final entry in knownModelsByProvider.entries) {
        final providerType = entry.key;
        final models = entry.value;

        for (final model in models) {
          if (model.isReasoningModel) {
            // Gemini models support reasoning with multimodal input
            if (providerType == InferenceProviderType.gemini) {
              expect(model.inputModalities, contains(Modality.text));
              // Can have additional modalities like image and audio
            } else {
              // Other reasoning models only support text input
              expect(model.inputModalities, equals([Modality.text]));
            }
          }
        }
      }
    });
  });
}
