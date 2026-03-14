import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/outbox/outbox_service.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigDb extends Mock implements AiConfigDb {}

class MockOutboxService extends Mock implements OutboxService {}

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
        createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
          createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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
        createdAt: DateTime.now(),
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

    test('getProfiles returns only inference profiles', () async {
      // Arrange — save a profile and a provider
      final profile = AiConfig.inferenceProfile(
        id: 'profile-id',
        name: 'Test Profile',
        thinkingModelId: 'models/gemini-3-flash-preview',
        createdAt: DateTime(2024),
      );
      final provider = AiConfig.inferenceProvider(
        id: 'provider-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-key',
        name: 'Provider',
        createdAt: DateTime(2024),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      await repository.saveConfig(profile);
      await repository.saveConfig(provider);

      // Act
      final profiles = await repository.getProfiles();

      // Assert
      expect(profiles, hasLength(1));
      expect(profiles.first.id, 'profile-id');
      expect(profiles.first.thinkingModelId, 'models/gemini-3-flash-preview');
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
        createdAt: DateTime.now(),
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
  });
}
