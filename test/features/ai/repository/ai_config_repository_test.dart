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

class MockAiConfigDb extends Mock implements AiConfigDb {}

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

        final result =
            await repository.deleteInferenceProviderWithModels('provider-1');

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
        await repository.watchConfigsByType(AiConfigType.inferenceProvider).first;

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
        await repository.watchConfigsByType(AiConfigType.inferenceProvider).first;

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
        await repository.watchConfigsByType(AiConfigType.inferenceProvider).first;

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
        await repository.watchConfigsByType(AiConfigType.inferenceProvider).first;

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

        final modelsAfter = await repository.getConfigsByType(AiConfigType.model);
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

      final skills =
          await repository.watchConfigsByType(AiConfigType.skill).first;
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

  });
}
