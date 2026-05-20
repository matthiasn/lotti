import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/model_prepopulation_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

enum _GeneratedExistingKnownModelsShape {
  none,
  first,
  alternating,
  all,
}

class _GeneratedPrepopulationScenario {
  const _GeneratedPrepopulationScenario({
    required this.providerType,
    required this.existingShape,
  });

  final InferenceProviderType providerType;
  final _GeneratedExistingKnownModelsShape existingShape;

  String get providerId => 'generated-${providerType.name}-provider';

  List<KnownModel> get knownModels =>
      knownModelsByProvider[providerType] ?? const [];

  Set<int> get existingKnownModelIndexes {
    return switch (existingShape) {
      _GeneratedExistingKnownModelsShape.none => const <int>{},
      _GeneratedExistingKnownModelsShape.first =>
        knownModels.isEmpty ? const <int>{} : const <int>{0},
      _GeneratedExistingKnownModelsShape.alternating => {
        for (var i = 0; i < knownModels.length; i++)
          if (i.isEven) i,
      },
      _GeneratedExistingKnownModelsShape.all => {
        for (var i = 0; i < knownModels.length; i++) i,
      },
    };
  }

  List<AiConfig> get existingConfigs {
    return [
      for (final index in existingKnownModelIndexes)
        AiConfig.model(
          id: generateModelId(providerId, knownModels[index].providerModelId),
          name: 'Existing ${knownModels[index].name}',
          providerModelId: knownModels[index].providerModelId,
          inferenceProviderId: providerId,
          createdAt: DateTime(2026, 3, 15),
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        ),
      AiConfig.inferenceProvider(
        id: 'not-a-model',
        baseUrl: 'https://generated.example.com',
        apiKey: 'key',
        name: 'Not a model',
        createdAt: DateTime(2026, 3, 15),
        inferenceProviderType: InferenceProviderType.openAi,
      ),
    ];
  }

  List<KnownModel> get modelsToCreate => [
    for (var i = 0; i < knownModels.length; i++)
      if (!existingKnownModelIndexes.contains(i)) knownModels[i],
  ];

  List<String> get expectedCreatedIds => [
    for (final model in modelsToCreate)
      generateModelId(providerId, model.providerModelId),
  ];

  AiConfigInferenceProvider get provider =>
      AiConfig.inferenceProvider(
            id: providerId,
            baseUrl: 'https://generated.example.com',
            apiKey: 'key',
            name: 'Generated ${providerType.name}',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: providerType,
          )
          as AiConfigInferenceProvider;

  @override
  String toString() {
    return '_GeneratedPrepopulationScenario('
        'providerType: $providerType, existingShape: $existingShape)';
  }
}

extension _AnyGeneratedPrepopulationScenario on glados.Any {
  glados.Generator<InferenceProviderType> get inferenceProviderType =>
      glados.AnyUtils(this).choose(InferenceProviderType.values);

  glados.Generator<_GeneratedExistingKnownModelsShape>
  get existingKnownModelsShape =>
      glados.AnyUtils(this).choose(_GeneratedExistingKnownModelsShape.values);

  glados.Generator<_GeneratedPrepopulationScenario> get prepopulationScenario =>
      glados.CombinableAny(this).combine2(
        inferenceProviderType,
        existingKnownModelsShape,
        (
          InferenceProviderType providerType,
          _GeneratedExistingKnownModelsShape existingShape,
        ) => _GeneratedPrepopulationScenario(
          providerType: providerType,
          existingShape: existingShape,
        ),
      );
}

void main() {
  setUpAll(() {
    registerFallbackValue(fallbackAiConfig);
  });

  group('ModelPrepopulationService', () {
    late MockAiConfigRepository mockRepository;
    late ModelPrepopulationService service;

    setUp(() {
      mockRepository = MockAiConfigRepository();
      service = ModelPrepopulationService(repository: mockRepository);
    });

    group('prepopulateModelsForProvider', () {
      test('should skip existing models and only create new ones', () async {
        // Arrange
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime(2026, 3, 15),
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
          createdAt: DateTime(2026, 3, 15),
          inputModalities: [],
          outputModalities: [],
          isReasoningModel: false,
        );

        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => [existingModel]);
        when(
          () => mockRepository.getConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) async => [provider]);

        when(
          () => mockRepository.saveConfig(any()),
        ).thenAnswer((_) async => {});

        // Act
        final result = await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(result, equals(geminiModels.length - 1));
        verify(
          () => mockRepository.saveConfig(any()),
        ).called(geminiModels.length - 1);
      });

      test('should create models with correct properties', () async {
        // Arrange
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime(2026, 3, 15),
          inferenceProviderType: InferenceProviderType.gemini,
        );

        AiConfigModel? capturedModel;
        when(
          () => mockRepository.getConfigsByType(AiConfigType.model),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getConfigsByType(
            AiConfigType.inferenceProvider,
          ),
        ).thenAnswer((_) async => [provider]);

        when(() => mockRepository.saveConfig(any())).thenAnswer((
          invocation,
        ) async {
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

      test(
        'should skip same-provider models when providerModelId already exists '
        'with a different row ID',
        () async {
          const providerId = 'gemini-provider-id';
          final provider = AiConfigInferenceProvider(
            id: providerId,
            baseUrl: 'https://api.gemini.com',
            apiKey: 'test-key',
            name: 'Gemini',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: InferenceProviderType.gemini,
          );
          final existingModel = geminiModels.first.toAiConfigModel(
            id: 'ftue-uuid-model-id',
            inferenceProviderId: providerId,
          );

          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [existingModel]);
          when(
            () => mockRepository.getConfigsByType(
              AiConfigType.inferenceProvider,
            ),
          ).thenAnswer((_) async => [provider]);
          when(
            () => mockRepository.saveConfig(any()),
          ).thenAnswer((_) async => {});

          final result = await service.prepopulateModelsForProvider(provider);

          expect(result, geminiModels.length - 1);
          verify(
            () => mockRepository.saveConfig(any()),
          ).called(geminiModels.length - 1);
        },
      );

      test(
        'should skip same-type duplicate model rows when an existing provider '
        'is usable',
        () async {
          final existingProvider = AiConfigInferenceProvider(
            id: 'gemini-provider-existing',
            baseUrl: 'https://api.gemini.com',
            apiKey: 'existing-key',
            name: 'Gemini existing',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: InferenceProviderType.gemini,
          );
          final newProvider = AiConfigInferenceProvider(
            id: 'gemini-provider-new',
            baseUrl: 'https://api.gemini.com',
            apiKey: 'new-key',
            name: 'Gemini new',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: InferenceProviderType.gemini,
          );
          final existingModel = geminiModels.first.toAiConfigModel(
            id: 'existing-provider-model',
            inferenceProviderId: existingProvider.id,
          );

          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [existingModel]);
          when(
            () => mockRepository.getConfigsByType(
              AiConfigType.inferenceProvider,
            ),
          ).thenAnswer((_) async => [existingProvider, newProvider]);
          when(
            () => mockRepository.saveConfig(any()),
          ).thenAnswer((_) async => {});

          final result = await service.prepopulateModelsForProvider(
            newProvider,
          );

          expect(result, geminiModels.length - 1);
          verify(
            () => mockRepository.saveConfig(any()),
          ).called(geminiModels.length - 1);
        },
      );

      test(
        'should create models when matching rows only point at deleted '
        'providers',
        () async {
          final provider = AiConfigInferenceProvider(
            id: 'gemini-provider-live',
            baseUrl: 'https://api.gemini.com',
            apiKey: 'test-key',
            name: 'Gemini',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: InferenceProviderType.gemini,
          );
          final orphanedModel = geminiModels.first.toAiConfigModel(
            id: 'orphaned-gemini-model',
            inferenceProviderId: 'deleted-gemini-provider',
          );

          when(
            () => mockRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => [orphanedModel]);
          when(
            () => mockRepository.getConfigsByType(
              AiConfigType.inferenceProvider,
            ),
          ).thenAnswer((_) async => [provider]);
          when(
            () => mockRepository.saveConfig(any()),
          ).thenAnswer((_) async => {});

          final result = await service.prepopulateModelsForProvider(provider);

          expect(result, geminiModels.length);
          verify(
            () => mockRepository.saveConfig(any()),
          ).called(geminiModels.length);
        },
      );

      glados.Glados(
        glados.any.prepopulationScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test(
        'matches generated provider prepopulation skip semantics',
        (scenario) async {
          final generatedRepository = MockAiConfigRepository();
          final generatedService = ModelPrepopulationService(
            repository: generatedRepository,
          );
          final savedModels = <AiConfigModel>[];

          when(
            () => generatedRepository.getConfigsByType(AiConfigType.model),
          ).thenAnswer((_) async => scenario.existingConfigs);
          when(
            () => generatedRepository.getConfigsByType(
              AiConfigType.inferenceProvider,
            ),
          ).thenAnswer((_) async => [scenario.provider]);
          when(
            () => generatedRepository.saveConfig(any()),
          ).thenAnswer((invocation) async {
            savedModels.add(
              invocation.positionalArguments.single as AiConfigModel,
            );
          });

          final createdCount = await generatedService
              .prepopulateModelsForProvider(scenario.provider);

          expect(
            createdCount,
            scenario.expectedCreatedIds.length,
            reason: '$scenario',
          );
          expect(
            savedModels.map((model) => model.id),
            equals(scenario.expectedCreatedIds),
            reason: '$scenario',
          );
          expect(
            savedModels.map((model) => model.inferenceProviderId).toSet(),
            savedModels.isEmpty ? isEmpty : {scenario.providerId},
            reason: '$scenario',
          );
          expect(
            savedModels.map((model) => model.providerModelId),
            equals(
              scenario.modelsToCreate.map((model) => model.providerModelId),
            ),
            reason: '$scenario',
          );
        },
        tags: 'glados',
      );
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
      expect(
        aiConfigModel.inputModalities,
        equals([Modality.text, Modality.image]),
      );
      expect(aiConfigModel.outputModalities, equals([Modality.text]));
      expect(aiConfigModel.isReasoningModel, isTrue);
      expect(aiConfigModel.description, equals('Test description'));
      expect(aiConfigModel.createdAt, isNotNull);
    });
  });

  group('backfillNewModels', () {
    late MockAiConfigRepository mockRepository;
    late ModelPrepopulationService service;

    setUp(() {
      mockRepository = MockAiConfigRepository();
      service = ModelPrepopulationService(repository: mockRepository);
    });

    test('should backfill models for all existing providers', () async {
      final ollamaProvider = AiConfigInferenceProvider(
        id: 'ollama-1',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        name: 'Ollama',
        createdAt: DateTime(2026, 3, 15),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [ollamaProvider]);

      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => []);

      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async => {});

      await service.backfillNewModels();

      verify(
        () => mockRepository.saveConfig(any()),
      ).called(ollamaModels.length);
    });

    test('should skip already existing models during backfill', () async {
      final ollamaProvider = AiConfigInferenceProvider(
        id: 'ollama-1',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        name: 'Ollama',
        createdAt: DateTime(2026, 3, 15),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      // Simulate all models already existing
      final existingModels = ollamaModels.map((m) {
        final modelId = generateModelId('ollama-1', m.providerModelId);
        return m.toAiConfigModel(
          id: modelId,
          inferenceProviderId: 'ollama-1',
        );
      }).toList();

      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [ollamaProvider]);

      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => existingModels);

      await service.backfillNewModels();

      verifyNever(() => mockRepository.saveConfig(any()));
    });

    test('should backfill across multiple providers', () async {
      final ollamaProvider = AiConfigInferenceProvider(
        id: 'ollama-1',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        name: 'Ollama',
        createdAt: DateTime(2026, 3, 15),
        inferenceProviderType: InferenceProviderType.ollama,
      );
      final geminiProvider = AiConfigInferenceProvider(
        id: 'gemini-1',
        baseUrl: 'https://api.gemini.com',
        apiKey: 'key',
        name: 'Gemini',
        createdAt: DateTime(2026, 3, 15),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [ollamaProvider, geminiProvider]);

      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => []);

      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async => {});

      await service.backfillNewModels();

      verify(
        () => mockRepository.saveConfig(any()),
      ).called(ollamaModels.length + geminiModels.length);
    });

    test('should only backfill missing models for a provider', () async {
      final ollamaProvider = AiConfigInferenceProvider(
        id: 'ollama-1',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        name: 'Ollama',
        createdAt: DateTime(2026, 3, 15),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      // Only the first Ollama model exists
      final firstModel = ollamaModels.first;
      final existingModelId = generateModelId(
        'ollama-1',
        firstModel.providerModelId,
      );
      final existingModel = firstModel.toAiConfigModel(
        id: existingModelId,
        inferenceProviderId: 'ollama-1',
      );

      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => [ollamaProvider]);

      when(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).thenAnswer((_) async => [existingModel]);

      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async => {});

      await service.backfillNewModels();

      verify(
        () => mockRepository.saveConfig(any()),
      ).called(ollamaModels.length - 1);
    });

    test('should handle no existing providers gracefully', () async {
      when(
        () => mockRepository.getConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) async => []);

      await service.backfillNewModels();

      verifyNever(() => mockRepository.saveConfig(any()));
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
            // Gemini, Anthropic, and OpenRouter models support reasoning with multimodal input
            if (providerType == InferenceProviderType.gemini ||
                providerType == InferenceProviderType.anthropic ||
                providerType == InferenceProviderType.openRouter) {
              expect(model.inputModalities, contains(Modality.text));
              // Can have additional modalities like image and audio
            } else {
              // Other reasoning models should at least support text input
              expect(model.inputModalities, contains(Modality.text));
            }
          }
        }
      }
    });
  });
}
