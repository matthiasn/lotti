import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/api_key_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/api_key_form_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;
  late ProviderContainer container;
  final testConfig = AiConfig.apiKey(
    id: 'test-id',
    baseUrl: 'https://api.example.com',
    apiKey: 'test-api-key',
    name: 'Test API',
    createdAt: DateTime.now(),
  );

  setUpAll(() {
    registerFallbackValue(testConfig);
  });

  setUp(() {
    mockRepository = MockAiConfigRepository();
    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    addTearDown(container.dispose);
  });

  group('ApiKeyFormController Tests', () {
    test('should load existing config in build when configId is provided',
        () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testConfig,
      );

      // Act
      final controller = container
          .read(apiKeyFormControllerProvider(configId: 'test-id').notifier);
      final formState = await container
          .read(apiKeyFormControllerProvider(configId: 'test-id').future);

      // Assert
      expect(formState, isA<ApiKeyFormState>());
      expect(controller.nameController.text, equals('Test API'));
      expect(controller.apiKeyController.text, equals('test-api-key'));
      expect(
          controller.baseUrlController.text, equals('https://api.example.com'));
      verify(() => mockRepository.getConfigById('test-id')).called(1);
    });

    test('should have empty form state when configId is null', () async {
      // Act
      final controller =
          container.read(apiKeyFormControllerProvider(configId: null).notifier);
      final formState = await container
          .read(apiKeyFormControllerProvider(configId: null).future);

      // Assert
      expect(formState, isA<ApiKeyFormState>());
      expect(controller.nameController.text, isEmpty);
      expect(controller.apiKeyController.text, isEmpty);
      expect(controller.baseUrlController.text, isEmpty);
      verifyNever(() => mockRepository.getConfigById(any()));
    });

    test('should add a new configuration', () async {
      // Arrange
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Act
      final controller =
          container.read(apiKeyFormControllerProvider(configId: null).notifier);
      await controller.addConfig(testConfig);

      // Assert
      verify(() => mockRepository.saveConfig(testConfig)).called(1);
    });

    test('should update an existing configuration', () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testConfig,
      );
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Load the existing config first
      final controller = container
          .read(apiKeyFormControllerProvider(configId: 'test-id').notifier);
      await container
          .read(apiKeyFormControllerProvider(configId: 'test-id').future);

      // Create an updated config
      final updatedConfig = AiConfig.apiKey(
        id: 'test-id',
        baseUrl: 'https://updated.example.com',
        apiKey: 'updated-key',
        name: 'Updated API',
        createdAt: DateTime.now(),
      );

      // Act
      await controller.updateConfig(updatedConfig);

      // Assert
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    test('should delete a configuration', () async {
      // Arrange
      when(() => mockRepository.deleteConfig('test-id'))
          .thenAnswer((_) async {});

      // Act
      final controller =
          container.read(apiKeyFormControllerProvider(configId: null).notifier);
      await controller.deleteConfig('test-id');

      // Assert
      verify(() => mockRepository.deleteConfig('test-id')).called(1);
    });

    test('should reset form fields', () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testConfig,
      );

      // Load the existing config first
      final controller = container
          .read(apiKeyFormControllerProvider(configId: 'test-id').notifier);
      await container
          .read(apiKeyFormControllerProvider(configId: 'test-id').future);

      // Verify fields are populated
      expect(controller.nameController.text, isNotEmpty);
      expect(controller.apiKeyController.text, isNotEmpty);

      // Act
      controller.reset();

      // Assert
      expect(controller.nameController.text, isEmpty);
      expect(controller.apiKeyController.text, isEmpty);
      expect(controller.baseUrlController.text, isEmpty);
      expect(controller.commentController.text, isEmpty);
    });

    test('should update form state when name is changed', () async {
      // Arrange
      final controller =
          container.read(apiKeyFormControllerProvider(configId: null).notifier);
      await container.read(apiKeyFormControllerProvider(configId: null).future);

      // Act
      controller.nameChanged('New Name');
      final formState = container
          .read(apiKeyFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.name.value, equals('New Name'));
    });

    test('should update form state when API key is changed', () async {
      // Arrange
      final controller =
          container.read(apiKeyFormControllerProvider(configId: null).notifier);
      await container.read(apiKeyFormControllerProvider(configId: null).future);

      // Act
      controller.apiKeyChanged('new-api-key');
      final formState = container
          .read(apiKeyFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.apiKey.value, equals('new-api-key'));
    });

    test('should update form state when base URL is changed', () async {
      // Arrange
      final controller =
          container.read(apiKeyFormControllerProvider(configId: null).notifier);
      await container.read(apiKeyFormControllerProvider(configId: null).future);

      // Act
      controller.baseUrlChanged('https://new.example.com');
      final formState = container
          .read(apiKeyFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.baseUrl.value, equals('https://new.example.com'));
    });

    test('should update form state when comment is changed', () async {
      // Arrange
      final controller =
          container.read(apiKeyFormControllerProvider(configId: null).notifier);
      await container.read(apiKeyFormControllerProvider(configId: null).future);

      // Act
      controller.commentChanged('New comment');
      final formState = container
          .read(apiKeyFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.comment.value, equals('New comment'));
    });
  });
}
