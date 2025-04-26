import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/database/ai_config_db.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigDb extends Mock implements AiConfigDb {}

void main() {
  setUpAll(() {
    // Register a fallback value for AiConfig
    registerFallbackValue(
      AiConfig.apiKey(
        id: 'fallback-id',
        baseUrl: 'https://fallback.example.com',
        apiKey: 'fallback-key',
        name: 'Fallback API',
        createdAt: DateTime.now(),
      ),
    );
  });

  group('AiConfigRepository with mocks', () {
    late MockAiConfigDb mockDb;
    late AiConfigRepository repository;

    setUp(() {
      mockDb = MockAiConfigDb();
      repository = AiConfigRepository(mockDb);
    });

    test('saveConfig calls db.saveConfig', () async {
      // Arrange
      final config = AiConfig.apiKey(
        id: 'test-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test API',
        createdAt: DateTime.now(),
      );
      when(() => mockDb.saveConfig(any())).thenAnswer((_) async => 1);

      // Act
      await repository.saveConfig(config);

      // Assert
      verify(() => mockDb.saveConfig(any())).called(1);
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
      final config = AiConfig.apiKey(
        id: id,
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test API',
        createdAt: DateTime.now(),
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
      const type = 'apiKey';
      final mockConfig = AiConfig.apiKey(
        id: 'mock-id',
        baseUrl: 'https://mock.example.com',
        apiKey: 'mock-key',
        name: 'Mock API',
        createdAt: DateTime.now(),
      );

      // Mock the DB response with any list of entities
      when(() => mockDb.getConfigsByType(type)).thenAnswer((_) async => []);

      // Act
      await repository.getConfigsByType(type);

      // Assert
      verify(() => mockDb.getConfigsByType(type)).called(1);
    });

    test('watchAllConfigs calls db.watchAllConfigs', () async {
      // Arrange
      when(() => mockDb.watchAllConfigs()).thenAnswer(
        (_) => Stream.value([]),
      );

      // Act
      repository.watchAllConfigs();

      // Assert
      verify(() => mockDb.watchAllConfigs()).called(1);
    });
  });

  group('AiConfigRepository with in-memory database', () {
    late AiConfigDb db;
    late AiConfigRepository repository;

    setUp(() async {
      db = AiConfigDb(inMemoryDatabase: true);
      repository = AiConfigRepository(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('saveConfig and getConfigById work correctly', () async {
      // Arrange
      final apiKeyConfig = AiConfig.apiKey(
        id: 'test-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test API',
        createdAt: DateTime.now(),
      );

      // Act
      await repository.saveConfig(apiKeyConfig);
      final result = await repository.getConfigById('test-id');

      // Assert
      result?.maybeMap(
        apiKey: (config) {
          expect(config.id, equals(apiKeyConfig.id));
          expect(config.baseUrl, equals('https://api.example.com'));
          expect(config.apiKey, equals('test-api-key'));
          expect(config.name, equals('Test API'));
        },
        orElse: () => fail('Retrieved config is not an API key config'),
      );
    });

    test('deleteConfig removes the config', () async {
      // Arrange
      final config = AiConfig.apiKey(
        id: 'test-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test API',
        createdAt: DateTime.now(),
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
      final apiConfig = AiConfig.apiKey(
        id: 'api-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'API Config',
        createdAt: DateTime.now(),
      );

      // Save the config
      await repository.saveConfig(apiConfig);

      // Act & Assert
      expect(
        repository.getConfigsByType('apiKey'),
        completion(equals([apiConfig])),
      );
    });

    test('watchConfigsByType returns configs of the specified type', () async {
      // Arrange
      final apiConfig = AiConfig.apiKey(
        id: 'api-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'API Config',
        createdAt: DateTime.now(),
      );

      // Save the config
      await repository.saveConfig(apiConfig);

      // Act & Assert
      expect(
        repository.watchConfigsByType('apiKey'),
        emits(
          predicate<List<AiConfig>>((configs) {
            return configs.length == 1 && configs.first.id == 'api-id';
          }),
        ),
      );
    });

    test('watchAllConfigs returns all configs', () async {
      // Arrange
      final apiConfig1 = AiConfig.apiKey(
        id: 'api-id-1',
        baseUrl: 'https://api1.example.com',
        apiKey: 'test-api-key-1',
        name: 'API Config 1',
        createdAt: DateTime.now(),
      );

      final apiConfig2 = AiConfig.apiKey(
        id: 'api-id-2',
        baseUrl: 'https://api2.example.com',
        apiKey: 'test-api-key-2',
        name: 'API Config 2',
        createdAt: DateTime.now(),
      );

      // Save the configs
      await repository.saveConfig(apiConfig1);
      await repository.saveConfig(apiConfig2);

      // Act & Assert
      expect(
        repository.watchAllConfigs(),
        emits(
          predicate<List<AiConfig>>((configs) {
            return configs.length == 2 &&
                configs.any((c) => c.id == 'api-id-1') &&
                configs.any((c) => c.id == 'api-id-2');
          }),
        ),
      );
    });
  });
}
