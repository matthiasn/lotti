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
    when(() => mockOutboxService.enqueueMessage(any()))
        .thenAnswer((_) async {});
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
    });

    test('saveConfig calls db.saveConfig and outboxService.enqueueMessage',
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
    });

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
      when(() => mockOutboxService.enqueueMessage(any()))
          .thenAnswer((_) async {});

      db = AiConfigDb(inMemoryDatabase: true);
      repository = AiConfigRepository(db);
    });

    tearDown(() async {
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
        completion(equals([apiConfig])),
      );
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
