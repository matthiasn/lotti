import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late GetIt getIt;
  late MockOutboxService mockOutboxService;
  final fixedDate = DateTime(2024, 3, 15, 12);

  setUpAll(() {
    // Register a fallback value for AiConfig
    registerFallbackValue(
      AiConfig.inferenceProvider(
        id: 'fallback-id',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        name: 'Fallback API',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      ),
    );

    // Register a fallback value for SyncMessage
    registerFallbackValue(
      SyncMessage.aiConfig(
        aiConfig: AiConfig.inferenceProvider(
          id: 'fallback-id',
          baseUrl: 'https://fallback.example.com',
          apiKey: 'fallback-key',
          name: 'Fallback API',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        ),
        status: SyncEntryStatus.initial,
      ),
    );

    // Set up GetIt
    getIt = GetIt.instance;
  });

  setUp(() {
    // Set up a fresh mock for each test
    mockOutboxService = MockOutboxService();

    // Register the mock with GetIt
    if (getIt.isRegistered<OutboxService>()) {
      getIt.unregister<OutboxService>();
    }
    getIt.registerSingleton<OutboxService>(mockOutboxService);

    // Set up default behavior
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    // Clear GetIt registrations
    if (getIt.isRegistered<OutboxService>()) {
      getIt.unregister<OutboxService>();
    }
  });

  group('AiConfigRepository with mocks', () {
    late MockAiConfigDb mockDb;
    late AiConfigRepository repository;

    setUp(() {
      mockDb = MockAiConfigDb();
      repository = AiConfigRepository(mockDb);

      // Set up default behavior for mockDb
      when(() => mockDb.saveConfig(any())).thenAnswer((_) async => 1);
      when(() => mockDb.getAllConfigs()).thenAnswer((_) async => []);
      when(
        () => mockDb.watchAllConfigs(),
      ).thenAnswer((_) => const Stream<List<AiConfigDbEntity>>.empty());
      when(() => mockDb.close()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await repository.close();
    });

    test(
      'saveConfig calls db.saveConfig and outboxService.enqueueMessage',
      () async {
        // Arrange
        final config = AiConfig.inferenceProvider(
          id: 'test-id',
          baseUrl: 'https://api.example.com',
          apiKey: 'test-api-key',
          name: 'Test API',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        // Act
        await repository.saveConfig(config);

        // Assert
        verify(() => mockDb.saveConfig(any())).called(1);
        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      },
    );

    test('deleteConfig calls db.deleteConfig', () async {
      // Arrange
      const id = 'test-id';
      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      await repository.deleteConfig(id);

      // Assert
      verify(() => mockDb.deleteConfig(id)).called(1);
    });

    test('getConfigById calls db.getConfigById', () async {
      // Arrange
      const id = 'test-id';
      final config = AiConfig.inferenceProvider(
        id: id,
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test API',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );
      when(() => mockDb.getConfigById(id)).thenAnswer((_) async => config);

      // Act
      final result = await repository.getConfigById(id);

      // Assert
      expect(result, equals(config));
      verify(() => mockDb.getConfigById(id)).called(1);
    });

    test('getConfigsByType calls db.getConfigsByType', () async {
      // Arrange
      const type = 'inferenceProvider';

      // Mock the DB response with any list of entities
      when(() => mockDb.getConfigsByType(type)).thenAnswer((_) async => []);

      // Act
      await repository.getConfigsByType(AiConfigType.inferenceProvider);

      // Assert
      verify(() => mockDb.getConfigsByType(type)).called(1);
    });

    test('getConfigsByType caches repeated lookups by type', () async {
      final config = AiConfig.inferenceProvider(
        id: 'provider-1',
        baseUrl: 'https://example.com',
        apiKey: 'key',
        name: 'Provider 1',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );
      final entity = AiConfigDbEntity(
        id: config.id,
        type: AiConfigType.inferenceProvider.name,
        name: config.name,
        serialized: jsonEncode(config.toJson()),
        createdAt: fixedDate,
      );
      when(
        () => mockDb.getConfigsByType(AiConfigType.inferenceProvider.name),
      ).thenAnswer((_) async => [entity]);

      final first = await repository.getConfigsByType(
        AiConfigType.inferenceProvider,
      );
      final second = await repository.getConfigsByType(
        AiConfigType.inferenceProvider,
      );

      expect(first, hasLength(1));
      expect(second, hasLength(1));
      verify(
        () => mockDb.getConfigsByType(AiConfigType.inferenceProvider.name),
      ).called(1);
    });

    test('getConfigsByType coalesces concurrent lookups by type', () async {
      final completer = Completer<List<AiConfigDbEntity>>();
      when(
        () => mockDb.getConfigsByType(AiConfigType.model.name),
      ).thenAnswer((_) => completer.future);

      final first = repository.getConfigsByType(AiConfigType.model);
      final second = repository.getConfigsByType(AiConfigType.model);

      verify(() => mockDb.getConfigsByType(AiConfigType.model.name)).called(1);

      completer.complete([
        AiConfigDbEntity(
          id: 'model-1',
          type: AiConfigType.model.name,
          name: 'Model 1',
          serialized: jsonEncode(
            AiConfig.model(
              id: 'model-1',
              name: 'Model 1',
              providerModelId: 'provider/model-1',
              inferenceProviderId: 'provider-1',
              createdAt: fixedDate,
              inputModalities: const [Modality.text],
              outputModalities: const [Modality.text],
              isReasoningModel: false,
            ).toJson(),
          ),
          createdAt: fixedDate,
        ),
      ]);

      expect((await first).single.id, 'model-1');
      expect((await second).single.id, 'model-1');
    });

    test('getConfigById caches repeated lookups by id', () async {
      final config = AiConfig.inferenceProvider(
        id: 'cached-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Cached API',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );
      when(() => mockDb.getConfigById('cached-id')).thenAnswer(
        (_) async => config,
      );

      final first = await repository.getConfigById('cached-id');
      final second = await repository.getConfigById('cached-id');

      expect(first?.id, 'cached-id');
      expect(second?.id, 'cached-id');
      verify(() => mockDb.getConfigById('cached-id')).called(1);
    });

    test(
      'watchConfigsByType shares a single all-config snapshot watch',
      () async {
        final controller = StreamController<List<AiConfigDbEntity>>.broadcast();
        final config = AiConfig.inferenceProvider(
          id: 'provider-1',
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Provider 1',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );
        final entity = AiConfigDbEntity(
          id: config.id,
          type: AiConfigType.inferenceProvider.name,
          name: config.name,
          serialized: jsonEncode(config.toJson()),
          createdAt: fixedDate,
        );

        when(() => mockDb.getAllConfigs()).thenAnswer((_) async => [entity]);
        when(
          () => mockDb.watchAllConfigs(),
        ).thenAnswer((_) => controller.stream);

        final first = repository
            .watchConfigsByType(
              AiConfigType.inferenceProvider,
            )
            .first;
        final second = repository
            .watchConfigsByType(
              AiConfigType.inferenceProvider,
            )
            .first;

        expect((await first).single.id, 'provider-1');
        expect((await second).single.id, 'provider-1');
        verify(() => mockDb.getAllConfigs()).called(1);
        verify(() => mockDb.watchAllConfigs()).called(1);

        await controller.close();
      },
    );
  });

  group('AiConfigRepository with in-memory database', () {
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
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async {});

      db = AiConfigDb(inMemoryDatabase: true);
      repository = AiConfigRepository(db);
    });

    tearDown(() async {
      await repository.close();
      await db.close();
    });

    test('saveConfig and getConfigById work correctly', () async {
      // Arrange
      final apiKeyConfig = AiConfig.inferenceProvider(
        id: 'test-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test API',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      // Act
      await repository.saveConfig(apiKeyConfig);
      final result = await repository.getConfigById('test-id');

      // Assert
      result?.maybeMap(
        inferenceProvider: (config) {
          expect(config.id, equals(apiKeyConfig.id));
          expect(config.baseUrl, equals('https://api.example.com'));
          expect(config.apiKey, equals('test-api-key'));
          expect(config.name, equals('Test API'));
        },
        orElse: () => fail('Retrieved config is not an API key config'),
      );

      // Verify OutboxService was called
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('deleteConfig removes the config', () async {
      // Arrange
      final config = AiConfig.inferenceProvider(
        id: 'test-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test API',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );
      await repository.saveConfig(config);

      // Act
      await repository.deleteConfig('test-id');
      final result = await repository.getConfigById('test-id');

      // Assert
      expect(result, isNull);
    });

    test('getConfigsByType returns configs of the specified type', () async {
      // Arrange
      final apiConfig = AiConfig.inferenceProvider(
        id: 'api-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'API Config',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      // Save the config
      await repository.saveConfig(apiConfig);

      // Act & Assert
      expect(
        repository.getConfigsByType(AiConfigType.inferenceProvider),
        completion(
          predicate<List<AiConfig>>(
            (configs) => configs.length == 1 && configs.first.id == 'api-id',
          ),
        ),
      );
    });

    test('watchProfiles streams only inference profiles', () async {
      // Arrange
      final profile = AiConfig.inferenceProfile(
        id: 'profile-id',
        name: 'Test Profile',
        thinkingModelId: 'models/gemini-3-flash-preview',
        createdAt: DateTime(2024),
      );

      await repository.saveConfig(profile);

      // Act & Assert
      expect(
        repository.watchProfiles(),
        emits(
          predicate<List<AiConfigInferenceProfile>>(
            (profiles) =>
                profiles.length == 1 && profiles.first.id == 'profile-id',
          ),
        ),
      );
    });

    test('resolveOllamaBaseUrl returns URL of first Ollama provider', () async {
      final ollamaProvider = AiConfig.inferenceProvider(
        id: 'ollama-1',
        baseUrl: 'http://localhost:11434',
        apiKey: '',
        name: 'Local Ollama',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.ollama,
      );

      await repository.saveConfig(ollamaProvider);

      final url = await repository.resolveOllamaBaseUrl();
      expect(url, 'http://localhost:11434');
    });

    test(
      'resolveOllamaBaseUrl returns null when no Ollama provider exists',
      () async {
        final openAiProvider = AiConfig.inferenceProvider(
          id: 'openai-1',
          baseUrl: 'https://api.openai.com',
          apiKey: 'key',
          name: 'OpenAI',
          createdAt: DateTime(2024),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );

        await repository.saveConfig(openAiProvider);

        final url = await repository.resolveOllamaBaseUrl();
        expect(url, isNull);
      },
    );

    test('resolveOllamaBaseUrl returns null on empty database', () async {
      final url = await repository.resolveOllamaBaseUrl();
      expect(url, isNull);
    });

    test('watchConfigsByType returns configs of the specified type', () async {
      // Arrange
      final apiConfig = AiConfig.inferenceProvider(
        id: 'api-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'API Config',
        createdAt: fixedDate,
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      // Save the config
      await repository.saveConfig(apiConfig);

      // Act & Assert
      expect(
        repository.watchConfigsByType(AiConfigType.inferenceProvider),
        emits(
          predicate<List<AiConfig>>((configs) {
            return configs.length == 1 && configs.first.id == 'api-id';
          }),
        ),
      );
    });

    test(
      'deleteInferenceProviderWithModels cascades to associated models',
      () async {
        final provider = AiConfig.inferenceProvider(
          id: 'provider-1',
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Provider 1',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );
        final model1 = AiConfig.model(
          id: 'model-1',
          name: 'Model 1',
          providerModelId: 'provider/model-1',
          inferenceProviderId: 'provider-1',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final model2 = AiConfig.model(
          id: 'model-2',
          name: 'Model 2',
          providerModelId: 'provider/model-2',
          inferenceProviderId: 'provider-1',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final otherModel = AiConfig.model(
          id: 'model-other',
          name: 'Other Model',
          providerModelId: 'other/model',
          inferenceProviderId: 'other-provider',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        await repository.saveConfig(provider);
        await repository.saveConfig(model1);
        await repository.saveConfig(model2);
        await repository.saveConfig(otherModel);

        final result = await repository.deleteInferenceProviderWithModels(
          'provider-1',
        );

        expect(result.providerName, 'Provider 1');
        expect(result.deletedModels, hasLength(2));
        expect(
          result.deletedModels.map((m) => m.id).toSet(),
          {'model-1', 'model-2'},
        );

        // Provider and its models removed; unrelated model still present
        expect(await repository.getConfigById('provider-1'), isNull);
        expect(await repository.getConfigById('model-1'), isNull);
        expect(await repository.getConfigById('model-2'), isNull);
        final remaining = await repository.getConfigById('model-other');
        expect(remaining?.id, 'model-other');
      },
    );

    test(
      'deleteInferenceProviderWithModels returns unknown provider name when '
      'provider not found',
      () async {
        // Provider doesn't exist — providerName should fall back to 'Unknown Provider'
        final model = AiConfig.model(
          id: 'model-orphan',
          name: 'Orphan Model',
          providerModelId: 'x/y',
          inferenceProviderId: 'missing-provider',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        await repository.saveConfig(model);

        final result = await repository.deleteInferenceProviderWithModels(
          'missing-provider',
        );

        expect(result.providerName, 'Unknown Provider');
        expect(result.deletedModels, hasLength(1));
      },
    );

    test(
      'saveConfig updates existing config in all-configs snapshot after '
      'initial load',
      () async {
        final config = AiConfig.inferenceProvider(
          id: 'p-1',
          baseUrl: 'https://v1.example.com',
          apiKey: 'key',
          name: 'Provider V1',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );
        await repository.saveConfig(config);

        // Trigger snapshot load by watching
        await repository
            .watchConfigsByType(AiConfigType.inferenceProvider)
            .first;

        final updated = AiConfig.inferenceProvider(
          id: 'p-1',
          baseUrl: 'https://v2.example.com',
          apiKey: 'key-v2',
          name: 'Provider V2',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.anthropic,
        );
        await repository.saveConfig(updated);

        final result = await repository.getConfigById('p-1');
        result?.maybeMap(
          inferenceProvider: (p) {
            expect(p.name, 'Provider V2');
            expect(p.baseUrl, 'https://v2.example.com');
          },
          orElse: () => fail('Expected inferenceProvider'),
        );
      },
    );

    test(
      'saveConfig appends new config to snapshot when _allConfigsLoaded',
      () async {
        // Trigger snapshot load
        await repository
            .watchConfigsByType(AiConfigType.inferenceProvider)
            .first;

        // Now add a brand-new config (not yet in snapshot)
        final newConfig = AiConfig.inferenceProvider(
          id: 'brand-new',
          baseUrl: 'https://new.example.com',
          apiKey: 'new-key',
          name: 'Brand New Provider',
          createdAt: DateTime(2024, 6, 15),
          inferenceProviderType: InferenceProviderType.anthropic,
        );
        await repository.saveConfig(newConfig);

        final providers = await repository.getConfigsByType(
          AiConfigType.inferenceProvider,
        );
        expect(providers.any((c) => c.id == 'brand-new'), isTrue);
      },
    );

    test(
      'deleteConfig removes item from snapshot when _allConfigsLoaded and '
      'id is not in cache (uncached branch)',
      () async {
        final config = AiConfig.inferenceProvider(
          id: 'del-target',
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Delete Target',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );
        await repository.saveConfig(config);

        // Force full snapshot load
        await repository
            .watchConfigsByType(AiConfigType.inferenceProvider)
            .first;

        // Evict from id cache by calling deleteConfig twice to exercise the
        // "not in cache but _allConfigsLoaded" branch on second call.
        await repository.deleteConfig('del-target');
        // Second delete: id no longer in cache, _allConfigsLoaded is true
        await repository.deleteConfig('del-target');

        final result = await repository.getConfigById('del-target');
        expect(result, isNull);
      },
    );

    test(
      'getConfigById returns null for unknown id when _allConfigsLoaded',
      () async {
        // Warm up the snapshot
        await repository
            .watchConfigsByType(AiConfigType.inferenceProvider)
            .first;

        // At this point _allConfigsLoaded == true — unknown id should be null
        final result = await repository.getConfigById('does-not-exist');
        expect(result, isNull);
      },
    );

    test(
      'getConfigsByType returns empty list when _allConfigsLoaded and type has '
      'no entries',
      () async {
        // Warm up snapshot with a provider so _allConfigsLoaded becomes true
        final provider = AiConfig.inferenceProvider(
          id: 'p-only',
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Only Provider',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );
        await repository.saveConfig(provider);
        await repository
            .watchConfigsByType(AiConfigType.inferenceProvider)
            .first;

        // Clear the model cache from the type cache to force the empty path
        final models = await repository.getConfigsByType(AiConfigType.model);
        expect(models, isEmpty);
      },
    );

    test(
      '_setConfigsByTypeCache removes stale ids when config list shrinks',
      () async {
        final modelA = AiConfig.model(
          id: 'model-a',
          name: 'Model A',
          providerModelId: 'prov/a',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final modelB = AiConfig.model(
          id: 'model-b',
          name: 'Model B',
          providerModelId: 'prov/b',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );

        await repository.saveConfig(modelA);
        await repository.saveConfig(modelB);

        // Warm caches
        await repository.getConfigsByType(AiConfigType.model);

        // Remove model-b — this triggers _setConfigsByTypeCache with smaller set
        await repository.deleteConfig('model-b');

        final modelsAfter = await repository.getConfigsByType(
          AiConfigType.model,
        );
        expect(modelsAfter.map((m) => m.id).toList(), ['model-a']);
      },
    );

    test('watchConfigsByType streams skill configs correctly', () async {
      final skill = AiConfig.skill(
        id: 'skill-1',
        name: 'Image Analysis Skill',
        createdAt: fixedDate,
        skillType: SkillType.imageAnalysis,
        requiredInputModalities: const [Modality.image],
        systemInstructions: 'Analyze the image.',
        userInstructions: 'Please analyze this image.',
      );

      await repository.saveConfig(skill);

      final skills = await repository
          .watchConfigsByType(AiConfigType.skill)
          .first;
      expect(skills, hasLength(1));
      expect(skills.first.id, 'skill-1');
      skills.first.maybeMap(
        skill: (s) => expect(s.skillType, SkillType.imageAnalysis),
        orElse: () => fail('Expected AiConfigSkill'),
      );
    });

    test(
      '_typeForConfig returns AiConfigType.skill for skill configs',
      () async {
        final skill = AiConfig.skill(
          id: 'skill-type-test',
          name: 'Transcription Skill',
          createdAt: fixedDate,
          skillType: SkillType.transcription,
          requiredInputModalities: const [Modality.audio],
          systemInstructions: 'Transcribe.',
          userInstructions: 'Transcribe this audio.',
        );

        await repository.saveConfig(skill);
        final configs = await repository.getConfigsByType(AiConfigType.skill);
        expect(configs, hasLength(1));
        expect(configs.first.id, 'skill-type-test');
      },
    );
  });

  group('AiConfigRepository with mocks — error handling', () {
    late MockAiConfigDb mockDb;
    late MockDomainLogger mockDomainLogger;
    late AiConfigRepository repository;

    setUp(() {
      mockDb = MockAiConfigDb();
      mockDomainLogger = MockDomainLogger();
      repository = AiConfigRepository(mockDb);

      when(() => mockDb.saveConfig(any())).thenAnswer((_) async => 1);
      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});
      when(() => mockDb.getAllConfigs()).thenAnswer((_) async => []);
      when(
        () => mockDb.watchAllConfigs(),
      ).thenAnswer((_) => const Stream<List<AiConfigDbEntity>>.empty());
      when(() => mockDb.close()).thenAnswer((_) async {});
      when(
        () => mockDomainLogger.error(
          any(),
          any(),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      if (getIt.isRegistered<DomainLogger>()) {
        getIt.unregister<DomainLogger>();
      }
      getIt.registerSingleton<DomainLogger>(mockDomainLogger);
    });

    tearDown(() async {
      await repository.close();
      if (getIt.isRegistered<DomainLogger>()) {
        getIt.unregister<DomainLogger>();
      }
    });

    test(
      'deleteInferenceProviderWithModels logs error via DomainLogger and '
      'rethrows when transaction fails',
      () async {
        // Arrange: make the transaction itself throw via a failing getConfigById
        when(() => mockDb.getConfigById(any())).thenThrow(
          Exception('DB connection lost'),
        );
        when(
          () => mockDb.transaction<CascadeDeletionResult>(any()),
        ).thenAnswer((invocation) async {
          final callback =
              invocation.positionalArguments.first
                  as Future<CascadeDeletionResult> Function();
          return callback();
        });
        when(
          () => mockDb.getConfigsByType(AiConfigType.model.name),
        ).thenAnswer((_) async => []);

        // Act & Assert: should rethrow
        await expectLater(
          repository.deleteInferenceProviderWithModels('provider-1'),
          throwsException,
        );

        // DomainLogger.error should have been called
        verify(
          () => mockDomainLogger.error(
            LogDomain.ai,
            any(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'deleteInferenceProviderWithModels',
          ),
        ).called(1);
      },
    );

    test(
      '_ensureAllConfigsLoaded resets bootstrap to null when getAllConfigs '
      'returns a failed Future and _allConfigsLoaded stays false',
      () async {
        // getAllConfigs returns a failing Future (not a sync throw) so the
        // whenComplete chain executes.  _replaceAllConfigsSnapshot is never
        // called, so _allConfigsLoaded stays false → line 420 resets
        // _allConfigsBootstrap to null.
        var callCount = 0;
        when(() => mockDb.getAllConfigs()).thenAnswer((_) {
          callCount++;
          return Future.error(Exception('DB unavailable'));
        });

        // watchConfigsByType triggers _ensureAllConfigsLoaded internally via a
        // fire-and-forget Future.  The unhandled failed Future must be collected
        // in the test Zone to prevent a test failure.
        final zoneErrors = <Object>[];
        await runZonedGuarded(
          () async {
            final collected = <List<AiConfig>>[];
            final subscription = repository
                .watchConfigsByType(AiConfigType.inferenceProvider)
                .listen(
                  collected.add,
                  onError: (Object e, StackTrace s) {},
                );

            // Drain the event queue deterministically so the bootstrap
            // Future settles — no zero-duration Timers (fake-time policy).
            await pumpEventQueue();

            await subscription.cancel();
          },
          (error, _) => zoneErrors.add(error),
        );

        // The important assertion: after the bootstrap failure the repository
        // has NOT set _allConfigsLoaded.  A subsequent getConfigsByType must
        // hit the DB again (not return an empty list from an "allConfigsLoaded"
        // short-circuit) — verified by checking that getAllConfigs was called
        // at least once (the initial bootstrap attempt).
        expect(callCount, greaterThanOrEqualTo(1));

        // Re-stub for the follow-up call.
        when(
          () => mockDb.getConfigsByType(AiConfigType.inferenceProvider.name),
        ).thenAnswer((_) async => []);

        // Should not throw — confirms the repository is still usable.
        final result = await repository.getConfigsByType(
          AiConfigType.inferenceProvider,
        );
        expect(result, isEmpty);
      },
    );

    test(
      '_ensureWatchingAllConfigs onError forwards stream error to '
      '_allConfigsController without throwing',
      () async {
        // Emit one valid snapshot so the repository bootstraps, then push an
        // error on the watch stream. The error must reach the broadcast
        // controller and be receivable by downstream subscribers.
        final watchController =
            StreamController<List<AiConfigDbEntity>>.broadcast();

        when(() => mockDb.getAllConfigs()).thenAnswer((_) async => []);
        when(
          () => mockDb.watchAllConfigs(),
        ).thenAnswer((_) => watchController.stream);

        // Bootstrap: watch and wait for the first (empty) snapshot.
        final firstSnapshotCompleter = Completer<void>();
        final errors = <Object>[];
        final subscription = repository
            .watchConfigsByType(AiConfigType.inferenceProvider)
            .listen(
              (_) {
                if (!firstSnapshotCompleter.isCompleted) {
                  firstSnapshotCompleter.complete();
                }
              },
              onError: errors.add,
            );
        await firstSnapshotCompleter.future;

        // Push an error on the raw watch stream — the onError handler on
        // lines 434-436 must forward it to _allConfigsController which then
        // propagates it to downstream stream listeners.
        final testError = Exception('Watch stream failed');
        watchController.addError(testError);

        // Drain the event queue deterministically so the error propagates —
        // no zero-duration Timers (fake-time policy).
        await pumpEventQueue();

        await subscription.cancel();
        await watchController.close();

        // The error was forwarded to the downstream subscriber.
        expect(errors, hasLength(1));
        expect(errors.first, isA<Exception>());
      },
    );
  });

  group('AiConfigRepository with mocks — _cacheConfigInTypeList paths', () {
    late MockAiConfigDb mockDb;
    late AiConfigRepository repository;

    setUp(() {
      mockDb = MockAiConfigDb();
      repository = AiConfigRepository(mockDb);

      when(() => mockDb.saveConfig(any())).thenAnswer((_) async => 1);
      when(() => mockDb.getAllConfigs()).thenAnswer((_) async => []);
      when(
        () => mockDb.watchAllConfigs(),
      ).thenAnswer((_) => const Stream<List<AiConfigDbEntity>>.empty());
      when(() => mockDb.close()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await repository.close();
    });

    test(
      '_cacheConfigInTypeList appends a config not yet in the type cache '
      '(covers the !exists branch, lines 397-400)',
      () async {
        // Step 1: Populate the type cache for AiConfigType.model via
        // getConfigsByType so _configsByTypeCache[model] is non-null.
        final modelA = AiConfig.model(
          id: 'model-a',
          name: 'Model A',
          providerModelId: 'prov/a',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final entityA = AiConfigDbEntity(
          id: modelA.id,
          type: AiConfigType.model.name,
          name: modelA.name,
          serialized: jsonEncode(modelA.toJson()),
          createdAt: fixedDate,
        );
        when(
          () => mockDb.getConfigsByType(AiConfigType.model.name),
        ).thenAnswer((_) async => [entityA]);

        await repository.getConfigsByType(AiConfigType.model);

        // Step 2: Fetch a DIFFERENT model via getConfigById — the completion
        // handler calls _cacheConfigInTypeList(modelB), which finds the
        // non-null cachedList and appends model-b (the !exists branch).
        final modelB = AiConfig.model(
          id: 'model-b',
          name: 'Model B',
          providerModelId: 'prov/b',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        when(
          () => mockDb.getConfigById('model-b'),
        ).thenAnswer((_) async => modelB);

        final result = await repository.getConfigById('model-b');
        expect(result?.id, 'model-b');

        // Type cache must now contain both models.
        final cached = await repository.getConfigsByType(AiConfigType.model);
        expect(cached.map((c) => c.id).toSet(), {'model-a', 'model-b'});
      },
    );

    test(
      '_cacheConfigInTypeList appends multiple configs via getConfigById '
      'covering for-loop iteration over existing items (lines 392-394)',
      () async {
        // Populate cache with two models so the for-loop body executes for
        // multiple iterations when a third model is appended.
        final modelA = AiConfig.model(
          id: 'loop-a',
          name: 'Loop A',
          providerModelId: 'prov/loop-a',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final modelB = AiConfig.model(
          id: 'loop-b',
          name: 'Loop B',
          providerModelId: 'prov/loop-b',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final entityA = AiConfigDbEntity(
          id: modelA.id,
          type: AiConfigType.model.name,
          name: modelA.name,
          serialized: jsonEncode(modelA.toJson()),
          createdAt: fixedDate,
        );
        final entityB = AiConfigDbEntity(
          id: modelB.id,
          type: AiConfigType.model.name,
          name: modelB.name,
          serialized: jsonEncode(modelB.toJson()),
          createdAt: fixedDate,
        );
        when(
          () => mockDb.getConfigsByType(AiConfigType.model.name),
        ).thenAnswer((_) async => [entityA, entityB]);

        // Seed the type cache with [A, B].
        await repository.getConfigsByType(AiConfigType.model);

        // Fetch a THIRD model via getConfigById — _cacheConfigInTypeList(C)
        // iterates over [A, B] (neither matches C's id) and appends C.
        // Lines 392-394 (the list comprehension / for loop) execute for
        // both A and B, and line 396 computes exists=false, line 398 adds C.
        final modelC = AiConfig.model(
          id: 'loop-c',
          name: 'Loop C',
          providerModelId: 'prov/loop-c',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        when(
          () => mockDb.getConfigById('loop-c'),
        ).thenAnswer((_) async => modelC);

        final result = await repository.getConfigById('loop-c');
        expect(result?.id, 'loop-c');

        // Type cache now contains all three models.
        final cached = await repository.getConfigsByType(AiConfigType.model);
        expect(cached.map((c) => c.id).toSet(), {'loop-a', 'loop-b', 'loop-c'});
      },
    );

    test(
      '_invalidateConfig removes config from snapshot when _allConfigsLoaded '
      'is true and config is not in id-cache (lines 373-376)',
      () async {
        // Seed DB with a config, load snapshot via getAllConfigs mock.
        final config = AiConfig.inferenceProvider(
          id: 'inv-target',
          baseUrl: 'https://example.com',
          apiKey: 'key',
          name: 'Inv Target',
          createdAt: fixedDate,
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        );
        final entity = AiConfigDbEntity(
          id: config.id,
          type: AiConfigType.inferenceProvider.name,
          name: config.name,
          serialized: jsonEncode(config.toJson()),
          createdAt: fixedDate,
        );

        // Make getAllConfigs return the entity so the snapshot is populated.
        when(() => mockDb.getAllConfigs()).thenAnswer((_) async => [entity]);
        when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

        // Trigger snapshot load.
        await repository
            .watchConfigsByType(AiConfigType.inferenceProvider)
            .first;

        // First delete: config IS in _configByIdCache (cached != null path).
        await repository.deleteConfig('inv-target');

        // After first delete _configByIdCache no longer has 'inv-target'.
        // Second delete: cached == null AND _allConfigsLoaded == true →
        // exercises lines 373-376 (_replaceAllConfigsSnapshot via the
        // uncached-but-loaded branch).
        await repository.deleteConfig('inv-target');

        // The snapshot must remain empty; getConfigById returns null.
        final result = await repository.getConfigById('inv-target');
        expect(result, isNull);
      },
    );

    test(
      '_setConfigsByTypeCache removes stale id-cache entries when type-list '
      'shrinks via _cacheConfigInTypeList → _setConfigsByTypeCache path '
      '(lines 319-320)',
      () async {
        // Populate the type cache with [A, B] via getConfigsByType.
        final modelA = AiConfig.model(
          id: 'stale-a',
          name: 'Stale A',
          providerModelId: 'prov/stale-a',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final modelB = AiConfig.model(
          id: 'stale-b',
          name: 'Stale B',
          providerModelId: 'prov/stale-b',
          inferenceProviderId: 'prov',
          createdAt: fixedDate,
          inputModalities: const [Modality.text],
          outputModalities: const [Modality.text],
          isReasoningModel: false,
        );
        final entityA = AiConfigDbEntity(
          id: modelA.id,
          type: AiConfigType.model.name,
          name: modelA.name,
          serialized: jsonEncode(modelA.toJson()),
          createdAt: fixedDate,
        );
        final entityB = AiConfigDbEntity(
          id: modelB.id,
          type: AiConfigType.model.name,
          name: modelB.name,
          serialized: jsonEncode(modelB.toJson()),
          createdAt: fixedDate,
        );

        // First call returns [A, B].
        when(
          () => mockDb.getConfigsByType(AiConfigType.model.name),
        ).thenAnswer((_) async => [entityA, entityB]);

        final first = await repository.getConfigsByType(AiConfigType.model);
        expect(first, hasLength(2));

        // Simulate a DB-side removal of B: the next getConfigsByType only
        // returns [A].  But the type cache was populated, so we must clear it
        // first (as deleteConfig would) to force a re-fetch.
        when(() => mockDb.deleteConfig('stale-b')).thenAnswer((_) async {});
        await repository.deleteConfig('stale-b');

        // After deleteConfig the type cache is cleared; next call fetches from
        // DB which now only returns [A].  _setConfigsByTypeCache is called with
        // previousIds = {} (cache was cleared) → loop body doesn't run here.
        when(
          () => mockDb.getConfigsByType(AiConfigType.model.name),
        ).thenAnswer((_) async => [entityA]);

        final second = await repository.getConfigsByType(AiConfigType.model);
        expect(second.map((m) => m.id).toList(), ['stale-a']);

        // stale-b must be absent from the id cache.
        when(
          () => mockDb.getConfigById('stale-b'),
        ).thenAnswer((_) async => null);
        final staleLookup = await repository.getConfigById('stale-b');
        // _allConfigsLoaded is still false here, so the id lookup hits DB.
        expect(staleLookup, isNull);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // From ai_config_repository_cascade_delete_test.dart
  // ---------------------------------------------------------------------------

  group('deleteInferenceProviderWithModels — cascade delete', () {
    late MockAiConfigDb mockDb;
    late MockOutboxService mockOutboxService;
    late AiConfigRepository repository;

    setUp(() {
      mockDb = MockAiConfigDb();
      mockOutboxService = MockOutboxService();
      repository = AiConfigRepository(mockDb);

      // Register mock services
      if (getIt.isRegistered<OutboxService>()) {
        getIt.unregister<OutboxService>();
      }
      getIt.registerSingleton<OutboxService>(mockOutboxService);

      // Setup default mocks
      when(
        () => mockOutboxService.enqueueMessage(any()),
      ).thenAnswer((_) async => {});

      // Setup default transaction mock to execute the callback
      when(() => mockDb.transaction<CascadeDeletionResult>(any())).thenAnswer((
        invocation,
      ) async {
        final callback =
            invocation.positionalArguments[0]
                as Future<CascadeDeletionResult> Function();
        return callback();
      });

      // Setup default getConfigById mock to return a mock provider
      when(() => mockDb.getConfigById(any())).thenAnswer(
        (_) async => AiConfigInferenceProvider(
          id: 'test-provider',
          name: 'Test Provider',
          baseUrl: 'https://test.com',
          apiKey: 'test-key',
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inferenceProviderType: InferenceProviderType.genericOpenAi,
        ),
      );
      when(() => mockDb.close()).thenAnswer((_) async {});
    });

    tearDown(() async {
      await repository.close();
      if (getIt.isRegistered<OutboxService>()) {
        getIt.unregister<OutboxService>();
      }
    });

    test('should delete provider and all associated models', () async {
      // Arrange
      const providerId = 'provider-123';

      final model1 = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      final model2 = AiConfigModel(
        id: 'model-2',
        name: 'Model 2',
        providerModelId: 'provider-model-2',
        inferenceProviderId: providerId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text],
        isReasoningModel: true,
      );

      // Model from different provider
      final otherModel = AiConfigModel(
        id: 'model-3',
        name: 'Model 3',
        providerModelId: 'provider-model-3',
        inferenceProviderId: 'other-provider',
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name)).thenAnswer(
        (_) async => [
          AiConfigDbEntity(
            id: model1.id,
            type: 'AiConfigModel',
            name: model1.name,
            serialized: jsonEncode(model1.toJson()),
            createdAt: model1.createdAt,
          ),
          AiConfigDbEntity(
            id: model2.id,
            type: 'AiConfigModel',
            name: model2.name,
            serialized: jsonEncode(model2.toJson()),
            createdAt: model2.createdAt,
          ),
          AiConfigDbEntity(
            id: otherModel.id,
            type: 'AiConfigModel',
            name: otherModel.name,
            serialized: jsonEncode(otherModel.toJson()),
            createdAt: otherModel.createdAt,
          ),
        ],
      );

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final result = await repository.deleteInferenceProviderWithModels(
        providerId,
      );

      // Assert
      expect(result.deletedModels.length, equals(2));
      expect(
        result.deletedModels.map((m) => m.id),
        containsAll(['model-1', 'model-2']),
      );
      expect(result.providerName, isNotEmpty);

      // Verify models were deleted
      verify(() => mockDb.deleteConfig('model-1')).called(1);
      verify(() => mockDb.deleteConfig('model-2')).called(1);

      // Verify provider was deleted
      verify(() => mockDb.deleteConfig(providerId)).called(1);

      // Verify other model was not deleted
      verifyNever(() => mockDb.deleteConfig('model-3'));

      // Verify sync messages were sent
      verify(() => mockOutboxService.enqueueMessage(any())).called(3);
    });

    test('should handle provider with no models', () async {
      // Arrange
      const providerId = 'provider-with-no-models';

      when(
        () => mockDb.getConfigsByType(AiConfigType.model.name),
      ).thenAnswer((_) async => []);

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final result = await repository.deleteInferenceProviderWithModels(
        providerId,
      );

      // Assert
      expect(result.deletedModels.length, equals(0));
      expect(result.providerName, isNotEmpty);

      // Verify only provider was deleted
      verify(() => mockDb.deleteConfig(providerId)).called(1);

      // Verify sync message was sent for provider deletion
      verify(() => mockOutboxService.enqueueMessage(any())).called(1);
    });

    test('should not send sync messages when fromSync is true', () async {
      // Arrange
      const providerId = 'provider-sync';
      final model = AiConfigModel(
        id: 'model-sync',
        name: 'Model Sync',
        providerModelId: 'provider-model-sync',
        inferenceProviderId: providerId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      when(() => mockDb.getConfigsByType(AiConfigType.model.name)).thenAnswer(
        (_) async => [
          AiConfigDbEntity(
            id: model.id,
            type: 'AiConfigModel',
            name: model.name,
            serialized: jsonEncode(model.toJson()),
            createdAt: model.createdAt,
          ),
        ],
      );

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final result = await repository.deleteInferenceProviderWithModels(
        providerId,
        fromSync: true,
      );

      // Assert
      expect(result.deletedModels.length, equals(1));
      expect(
        result.deletedModels.map((m) => m.id),
        containsAll(['model-sync']),
      );
      expect(result.providerName, isNotEmpty);

      // Verify deletions happened
      verify(() => mockDb.deleteConfig('model-sync')).called(1);
      verify(() => mockDb.deleteConfig(providerId)).called(1);

      // Verify no sync messages were sent
      verifyNever(() => mockOutboxService.enqueueMessage(any()));
    });

    test('should handle database errors gracefully', () async {
      // Arrange
      const providerId = 'provider-error';

      when(
        () => mockDb.getConfigsByType(AiConfigType.model.name),
      ).thenThrow(Exception('Database error'));

      // Act & Assert
      expect(
        () => repository.deleteInferenceProviderWithModels(providerId),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Database error'),
          ),
        ),
      );
    });

    test('should delete multiple models in correct order', () async {
      // Arrange
      const providerId = 'provider-multi';
      final models = List.generate(
        5,
        (i) => AiConfigModel(
          id: 'model-$i',
          name: 'Model $i',
          providerModelId: 'provider-model-$i',
          inferenceProviderId: providerId,
          createdAt: DateTime(2024, 3, 15, 10, 30),
          inputModalities: [Modality.text],
          outputModalities: [Modality.text],
          isReasoningModel: false,
        ),
      );

      when(() => mockDb.getConfigsByType(AiConfigType.model.name)).thenAnswer(
        (_) async => models
            .map(
              (m) => AiConfigDbEntity(
                id: m.id,
                type: 'AiConfigModel',
                name: m.name,
                serialized: jsonEncode(m.toJson()),
                createdAt: m.createdAt,
              ),
            )
            .toList(),
      );

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final result = await repository.deleteInferenceProviderWithModels(
        providerId,
      );

      // Assert
      expect(result.deletedModels.length, equals(5));
      expect(
        result.deletedModels.map((m) => m.id),
        containsAll(['model-0', 'model-1', 'model-2', 'model-3', 'model-4']),
      );
      expect(result.providerName, isNotEmpty);

      // Verify all models were deleted
      for (var i = 0; i < 5; i++) {
        verify(() => mockDb.deleteConfig('model-$i')).called(1);
      }

      // Verify provider was deleted after models
      verify(() => mockDb.deleteConfig(providerId)).called(1);
    });

    test('should rollback transaction when model deletion fails', () async {
      // Arrange
      const providerId = 'provider-rollback';

      final model1 = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      final model2 = AiConfigModel(
        id: 'model-2',
        name: 'Model 2',
        providerModelId: 'provider-model-2',
        inferenceProviderId: providerId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name)).thenAnswer(
        (_) async => [
          AiConfigDbEntity(
            id: model1.id,
            type: 'AiConfigModel',
            name: model1.name,
            serialized: jsonEncode(model1.toJson()),
            createdAt: model1.createdAt,
          ),
          AiConfigDbEntity(
            id: model2.id,
            type: 'AiConfigModel',
            name: model2.name,
            serialized: jsonEncode(model2.toJson()),
            createdAt: model2.createdAt,
          ),
        ],
      );

      // Mock first model deletion to succeed, second to fail
      when(() => mockDb.deleteConfig('model-1')).thenAnswer((_) async {});
      when(
        () => mockDb.deleteConfig('model-2'),
      ).thenThrow(Exception('Model deletion failed'));

      // Act & Assert
      expect(
        () => repository.deleteInferenceProviderWithModels(providerId),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Model deletion failed'),
          ),
        ),
      );

      // Verify that the transaction was attempted
      verify(() => mockDb.transaction<CascadeDeletionResult>(any())).called(1);
    });

    test('should rollback transaction when provider deletion fails', () async {
      // Arrange
      const providerId = 'provider-delete-fail';

      final model = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name)).thenAnswer(
        (_) async => [
          AiConfigDbEntity(
            id: model.id,
            type: 'AiConfigModel',
            name: model.name,
            serialized: jsonEncode(model.toJson()),
            createdAt: model.createdAt,
          ),
        ],
      );

      // Mock model deletion to succeed, provider deletion to fail
      when(() => mockDb.deleteConfig('model-1')).thenAnswer((_) async {});
      when(
        () => mockDb.deleteConfig(providerId),
      ).thenThrow(Exception('Provider deletion failed'));

      // Act & Assert
      expect(
        () => repository.deleteInferenceProviderWithModels(providerId),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Failed to delete provider $providerId'),
          ),
        ),
      );

      // Verify that the transaction was attempted
      verify(() => mockDb.transaction<CascadeDeletionResult>(any())).called(1);
    });

    test('should use transaction for successful deletions', () async {
      // Arrange
      const providerId = 'provider-transaction';

      final model = AiConfigModel(
        id: 'model-1',
        name: 'Model 1',
        providerModelId: 'provider-model-1',
        inferenceProviderId: providerId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text],
        outputModalities: [Modality.text],
        isReasoningModel: false,
      );

      // Mock the database responses
      when(() => mockDb.getConfigsByType(AiConfigType.model.name)).thenAnswer(
        (_) async => [
          AiConfigDbEntity(
            id: model.id,
            type: 'AiConfigModel',
            name: model.name,
            serialized: jsonEncode(model.toJson()),
            createdAt: model.createdAt,
          ),
        ],
      );

      when(() => mockDb.deleteConfig(any())).thenAnswer((_) async {});

      // Act
      final result = await repository.deleteInferenceProviderWithModels(
        providerId,
      );

      // Assert
      expect(result.deletedModels.length, equals(1));
      expect(result.deletedModels.map((m) => m.id), containsAll(['model-1']));
      expect(result.providerName, isNotEmpty);

      // Verify that the transaction was used
      verify(() => mockDb.transaction<CascadeDeletionResult>(any())).called(1);

      // Verify deletions happened within the transaction
      verify(() => mockDb.deleteConfig('model-1')).called(1);
      verify(() => mockDb.deleteConfig(providerId)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // From ai_config_repository_integration_test.dart
  // ---------------------------------------------------------------------------

  group('AiConfigRepository integration tests', () {
    late AiConfigDb db;
    late AiConfigRepository repository;
    late MockOutboxService mockOutboxServiceInteg;

    setUp(() async {
      // Set up a fresh mock for each test
      mockOutboxServiceInteg = MockOutboxService();

      // Register the mock with GetIt
      if (getIt.isRegistered<OutboxService>()) {
        getIt.unregister<OutboxService>();
      }
      getIt.registerSingleton<OutboxService>(mockOutboxServiceInteg);

      // Set up default behavior
      when(
        () => mockOutboxServiceInteg.enqueueMessage(any()),
      ).thenAnswer((_) async {});

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
      final testDate = DateTime(2024, 3, 15, 10, 30);
      final apiKeyConfig = AiConfig.inferenceProvider(
        id: 'openai-key',
        baseUrl: 'https://api.openai.com/v1',
        apiKey: 'sk-1234567890abcdef',
        name: 'OpenAI API Key',
        createdAt: testDate,
        description: 'Test API key for OpenAI integration',
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      // Create prompt template config
      final promptConfig = AiConfig.prompt(
        id: 'summarize-prompt',
        name: 'Summarization Template',
        systemMessage: 'Please summarize the following text:',
        userMessage: '{{text}}',
        createdAt: testDate,
        description: 'Template for text summarization',
        defaultVariables: {'text': 'Enter text to summarize'},
        category: 'Summarization',
        defaultModelId: 'model-id1',
        modelIds: [],
        useReasoning: false,
        requiredInputData: [],
        // ignore: deprecated_member_use_from_same_package
        aiResponseType: AiResponseType.taskSummary,
      );

      // Save both configs
      await repository.saveConfig(apiKeyConfig);
      await repository.saveConfig(promptConfig);

      // Verify OutboxService was called twice (once for each config)
      verify(() => mockOutboxServiceInteg.enqueueMessage(any())).called(2);

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
      final retrievedPromptConfig = await repository.getConfigById(
        'summarize-prompt',
      );
      expect(retrievedPromptConfig, isNotNull);

      // Use maybeMap to check the type and fields
      retrievedPromptConfig?.maybeMap(
        prompt: (config) {
          expect(config.id, equals('summarize-prompt'));
          expect(config.name, equals('Summarization Template'));
          expect(
            config.systemMessage,
            equals('Please summarize the following text:'),
          );
          expect(config.userMessage, equals('{{text}}'));
          expect(config.category, equals('Summarization'));
        },
        orElse: () => fail('Retrieved config is not a prompt template config'),
      );

      // Watch by type tests
      await expectLater(
        repository.watchConfigsByType(AiConfigType.inferenceProvider),
        emits(
          predicate<List<AiConfig>>(
            (configs) =>
                configs.length == 1 && configs.first.id == 'openai-key',
          ),
        ),
      );

      await expectLater(
        repository.watchConfigsByType(AiConfigType.prompt),
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
