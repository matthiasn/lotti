import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/database/settings_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/util/known_models.dart';
import 'package:lotti/features/ai/util/model_prepopulation_service.dart';
import 'package:lotti/get_it.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../test_utils.dart';
import 'model_prepopulation_service_test_helpers.dart';

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

    /// Stubs the repository's config queries: [models] for the model type,
    /// [providers] for the provider type, and a no-op saveConfig.
    void stubRepo({
      List<AiConfig> models = const [],
      List<AiConfig> providers = const [],
    }) {
      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => models);
      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => providers);
      when(
        () => mockRepository.saveConfig(any()),
      ).thenAnswer((_) async {});
    }

    group('prepopulateModelsForProvider', () {
      test(
        'backfills Qwen as a selectable Melious task-agent model',
        () async {
          final provider = AiConfigInferenceProvider(
            id: 'melious-provider-id',
            baseUrl: 'https://api.melious.ai/v1',
            apiKey: 'test-key',
            name: 'Melious',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: InferenceProviderType.melious,
          );
          final savedModels = <AiConfigModel>[];
          stubRepo(providers: [provider]);
          when(() => mockRepository.saveConfig(any())).thenAnswer((
            invocation,
          ) async {
            savedModels.add(
              invocation.positionalArguments.single as AiConfigModel,
            );
          });

          final result = await service.prepopulateModelsForProvider(provider);

          expect(result, meliousModels.length);
          final qwen = savedModels.singleWhere(
            (model) => model.providerModelId == meliousQwen35122BA10BModelId,
          );
          expect(qwen.inferenceProviderId, provider.id);
          expect(qwen.isReasoningModel, isTrue);
          expect(qwen.supportsFunctionCalling, isTrue);
          expect(qwen.inputModalities, contains(Modality.text));
          expect(qwen.outputModalities, contains(Modality.text));
        },
      );

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

        stubRepo(models: [existingModel], providers: [provider]);

        // Act
        final result = await service.prepopulateModelsForProvider(provider);

        // Assert
        expect(result, equals(geminiModels.length - 1));
        verify(
          () => mockRepository.saveConfig(any()),
        ).called(geminiModels.length - 1);
      });

      // The production constructor resolves both dependencies from getIt;
      // every other test injects them, so this pins the default path.
      test(
        'falls back to registered dependencies when none are passed',
        () async {
          await getIt.reset();
          getIt
            ..registerSingleton<AiConfigRepository>(mockRepository)
            ..registerSingleton<SettingsDb>(SettingsDb(inMemoryDatabase: true));
          addTearDown(() async {
            await getIt<SettingsDb>().close();
            await getIt.reset();
          });

          const providerId = 'gemini-provider-id';
          final provider = AiConfigInferenceProvider(
            id: providerId,
            baseUrl: 'https://api.gemini.com',
            apiKey: 'test-key',
            name: 'Gemini',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: InferenceProviderType.gemini,
          );
          stubRepo(providers: [provider]);

          final created = await ModelPrepopulationService()
              .prepopulateModelsForProvider(provider);

          expect(
            created,
            knownModelsByProvider[InferenceProviderType.gemini]!.length,
          );
        },
      );

      // Backfill recreates any known model a configured provider lacks, so a
      // model the user deleted returns on the next launch unless the row is
      // still there to be counted as configured.
      test('does not recreate a model the user deleted', () async {
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime(2026, 3, 15),
          inferenceProviderType: InferenceProviderType.gemini,
        );
        final knownModel =
            knownModelsByProvider[InferenceProviderType.gemini]!.first;
        final deletedRow = knownModel.toAiConfigModel(
          id: generateModelId(providerId, knownModel.providerModelId),
          inferenceProviderId: providerId,
        );
        stubRepo(
          providers: [provider],
          models: [deletedRow.copyWith(deletedAt: DateTime(2026, 7, 25))],
        );

        final created = await service.prepopulateModelsForProvider(provider);

        final saved = verify(
          () => mockRepository.saveConfig(captureAny()),
        ).captured.cast<AiConfigModel>().map((model) => model.providerModelId);
        expect(saved, isNot(contains(knownModel.providerModelId)));
        expect(
          created,
          knownModelsByProvider[InferenceProviderType.gemini]!.length - 1,
        );
      });

      // Deletion is provider-scoped: removing a model under provider A must
      // not stop the same known model being created for a newly added
      // provider B of the same type.
      test(
        "another provider's deleted row does not suppress this one",
        () async {
          const providerA = 'gemini-a';
          const providerB = 'gemini-b';
          AiConfigInferenceProvider provider(String id) =>
              AiConfigInferenceProvider(
                id: id,
                baseUrl: 'https://api.gemini.com',
                apiKey: 'test-key',
                name: id,
                createdAt: DateTime(2026, 3, 15),
                inferenceProviderType: InferenceProviderType.gemini,
              );
          final known =
              knownModelsByProvider[InferenceProviderType.gemini]!.first;
          final deletedUnderA = known
              .toAiConfigModel(
                id: generateModelId(providerA, known.providerModelId),
                inferenceProviderId: providerA,
              )
              .copyWith(deletedAt: DateTime(2026, 7, 25));

          stubRepo(
            providers: [provider(providerA), provider(providerB)],
            models: [deletedUnderA],
          );

          await service.prepopulateModelsForProvider(provider(providerB));

          final saved = verify(() => mockRepository.saveConfig(captureAny()))
              .captured
              .cast<AiConfigModel>()
              .where((model) => model.providerModelId == known.providerModelId);
          expect(saved, hasLength(1));
          expect(saved.single.inferenceProviderId, providerB);
        },
      );

      // The existing-model scan must ask for deleted rows, or it reads
      // "removed" as "never configured".
      test('the existing-model scan includes deleted rows', () async {
        const providerId = 'gemini-provider-id';
        final provider = AiConfigInferenceProvider(
          id: providerId,
          baseUrl: 'https://api.gemini.com',
          apiKey: 'test-key',
          name: 'Gemini',
          createdAt: DateTime(2026, 3, 15),
          inferenceProviderType: InferenceProviderType.gemini,
        );
        stubRepo(providers: [provider]);

        await service.prepopulateModelsForProvider(provider);

        verify(
          () => mockRepository.getConfigsByType(
            AiConfigType.model,
            includeDeleted: true,
          ),
        ).called(1);
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
          () => mockRepository.getConfigsByType(
            AiConfigType.model,
            includeDeleted: any(named: 'includeDeleted'),
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getConfigsByType(
            AiConfigType.inferenceProvider,
            includeDeleted: any(named: 'includeDeleted'),
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

          stubRepo(models: [existingModel], providers: [provider]);

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

          stubRepo(
            models: [existingModel],
            providers: [existingProvider, newProvider],
          );

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

          stubRepo(models: [orphanedModel], providers: [provider]);

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
            () => generatedRepository.getConfigsByType(
              AiConfigType.model,
              includeDeleted: any(named: 'includeDeleted'),
            ),
          ).thenAnswer((_) async => scenario.existingConfigs);
          when(
            () => generatedRepository.getConfigsByType(
              AiConfigType.inferenceProvider,
              includeDeleted: any(named: 'includeDeleted'),
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

  group('migrateRenamedModelIds', () {
    late MockAiConfigRepository mockRepository;
    late ModelPrepopulationService service;

    AiConfigInferenceProvider meliousProvider() => AiConfigInferenceProvider(
      id: 'melious-1',
      baseUrl: 'https://api.melious.ai/v1',
      apiKey: 'key',
      name: 'Melious',
      createdAt: DateTime(2026, 3, 15),
      inferenceProviderType: InferenceProviderType.melious,
    );

    AiConfigModel modelRow({
      required String id,
      required String providerModelId,
      String providerId = 'melious-1',
      DateTime? deletedAt,
    }) => AiConfigModel(
      id: id,
      name: 'DeepSeek V4 Flash',
      providerModelId: providerModelId,
      inferenceProviderId: providerId,
      createdAt: DateTime(2026, 3, 15),
      inputModalities: const [Modality.text],
      outputModalities: const [Modality.text],
      isReasoningModel: true,
      deletedAt: deletedAt,
    );

    setUp(() {
      mockRepository = MockAiConfigRepository();
      service = ModelPrepopulationService(repository: mockRepository);
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async => {});
    });

    void stub({
      required List<AiConfig> providers,
      required List<AiConfig> models,
    }) {
      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => providers);
      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => models);
    }

    test('rewrites the dead id in place, keeping the row id', () async {
      // The row id is what profile slots and direct-model overrides store, so
      // preserving it is the whole point: a new row would leave every existing
      // reference pointing at the unservable model.
      stub(
        providers: [meliousProvider()],
        models: [
          modelRow(id: 'row-flash', providerModelId: 'deepseek-v4-flash'),
        ],
      );

      expect(await service.migrateRenamedModelIds(), 1);

      final saved =
          verify(() => mockRepository.saveConfig(captureAny())).captured.single
              as AiConfigModel;
      expect(saved.id, 'row-flash');
      expect(saved.providerModelId, meliousDeepseekV4FlashModelId);
    });

    test('migrates a soft-deleted row too', () async {
      // Leaving it renames nothing today and resurrects the dead id the moment
      // the user restores the row.
      stub(
        providers: [meliousProvider()],
        models: [
          modelRow(
            id: 'row-deleted',
            providerModelId: 'deepseek-v4-flash',
            deletedAt: DateTime(2026, 8),
          ),
        ],
      );

      expect(await service.migrateRenamedModelIds(), 1);
    });

    test('leaves rows of other providers and other models alone', () async {
      stub(
        providers: [
          meliousProvider(),
          AiConfigInferenceProvider(
            id: 'ollama-1',
            baseUrl: 'http://localhost:11434',
            apiKey: '',
            name: 'Ollama',
            createdAt: DateTime(2026, 3, 15),
            inferenceProviderType: InferenceProviderType.ollama,
          ),
        ],
        models: [
          // Same dead id, wrong provider type — the rename is Melious-scoped.
          modelRow(
            id: 'row-other-provider',
            providerModelId: 'deepseek-v4-flash',
            providerId: 'ollama-1',
          ),
          modelRow(id: 'row-glm', providerModelId: 'glm-5.2'),
          // Already migrated: must not be rewritten a second time.
          modelRow(
            id: 'row-done',
            providerModelId: meliousDeepseekV4FlashModelId,
          ),
        ],
      );

      expect(await service.migrateRenamedModelIds(), 0);
      verifyNever(() => mockRepository.saveConfig(any()));
    });

    test('every rename maps a dead id onto a different, known id', () async {
      // Guards the table itself: a self-mapping would loop the migration over
      // its own output, and a target absent from the curated catalog would
      // rename users onto a model the app does not otherwise offer.
      ModelPrepopulationService.renamedProviderModelIds.forEach((
        type,
        renames,
      ) {
        final known = {
          for (final model
              in knownModelsByProvider[type] ?? const <KnownModel>[])
            model.providerModelId,
        };
        renames.forEach((from, to) {
          expect(from, isNot(to), reason: '$type: $from maps to itself');
          expect(
            known,
            contains(to),
            reason: '$type: $to is not a known model',
          );
          expect(
            known,
            isNot(contains(from)),
            reason: '$type: $from is still offered',
          );
        });
      });
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
        () => mockRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [ollamaProvider]);

      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
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
        () => mockRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [ollamaProvider]);

      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
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
        () => mockRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [ollamaProvider, geminiProvider]);

      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
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
        () => mockRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [ollamaProvider]);

      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.model,
          includeDeleted: any(named: 'includeDeleted'),
        ),
      ).thenAnswer((_) async => [existingModel]);

      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async => {});

      await service.backfillNewModels();

      verify(
        () => mockRepository.saveConfig(any()),
      ).called(ollamaModels.length - 1);
    });

    test('should handle no existing providers gracefully', () async {
      when(
        () => mockRepository.getConfigsByType(
          AiConfigType.inferenceProvider,
          includeDeleted: any(named: 'includeDeleted'),
        ),
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
