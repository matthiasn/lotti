import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/settings/inference_provider_form_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;
  late ProviderContainer container;
  final testConfig = AiConfig.inferenceProvider(
    id: 'test-id',
    baseUrl: 'https://api.example.com',
    apiKey: 'test-api-key',
    name: 'Test API',
    createdAt: DateTime.now(),
    inferenceProviderType: InferenceProviderType.genericOpenAi,
  );

  final ollamaConfig = AiConfig.inferenceProvider(
    id: 'ollama-id',
    baseUrl: 'http://localhost:11434',
    apiKey: '',
    name: 'Ollama Local',
    createdAt: DateTime.now(),
    inferenceProviderType: InferenceProviderType.ollama,
  );

  setUpAll(() {
    registerFallbackValue(testConfig);
    registerFallbackValue(ollamaConfig);
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
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: 'test-id').notifier,
      );
      final formState = await container.read(
        inferenceProviderFormControllerProvider(configId: 'test-id').future,
      );

      // Assert
      expect(formState, isA<InferenceProviderFormState>());
      expect(controller.nameController.text, equals('Test API'));
      expect(controller.apiKeyController.text, equals('test-api-key'));
      expect(
        controller.baseUrlController.text,
        equals('https://api.example.com'),
      );
      verify(() => mockRepository.getConfigById('test-id')).called(1);
    });

    test('should have empty form state when configId is null', () async {
      // Act
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      final formState = await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Assert
      expect(formState, isA<InferenceProviderFormState>());
      expect(controller.nameController.text, isEmpty);
      expect(controller.apiKeyController.text, isEmpty);
      expect(controller.baseUrlController.text, isEmpty);
      verifyNever(() => mockRepository.getConfigById(any()));
    });

    test('should add a new configuration', () async {
      // Arrange
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);

      // Act
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
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
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: 'test-id').notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: 'test-id').future,
      );

      // Create an updated config
      final updatedConfig = AiConfig.inferenceProvider(
        id: 'test-id',
        baseUrl: 'https://updated.example.com',
        apiKey: 'updated-key',
        name: 'Updated API',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.genericOpenAi,
      );

      // Act
      await controller.updateConfig(updatedConfig);

      // Assert - capture the argument to verify properties
      final captured = verify(
        () => mockRepository.saveConfig(captureAny()),
      ).captured;
      expect(captured.length, 1);
      final savedConfig = captured.first as AiConfigInferenceProvider;
      expect(savedConfig.id, equals('test-id'));
      expect(savedConfig.name, equals('Updated API'));
      expect(savedConfig.baseUrl, equals('https://updated.example.com'));
      expect(savedConfig.apiKey, equals('updated-key'));
    });

    test('should delete a configuration', () async {
      // Arrange
      final mockResult = CascadeDeletionResult(
        deletedModels: [
          AiConfigModel(
            id: 'model-1',
            name: 'Test Model',
            providerModelId: 'test-model',
            inferenceProviderId: 'test-id',
            createdAt: DateTime.now(),
            inputModalities: [Modality.text],
            outputModalities: [Modality.text],
            isReasoningModel: false,
          ),
        ],
        providerName: 'Test Provider',
      );

      when(() => mockRepository.deleteInferenceProviderWithModels('test-id'))
          .thenAnswer((_) async => mockResult);

      // Act
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      final result = await controller.deleteConfig('test-id');

      // Assert
      expect(result.deletedModels.length, equals(1));
      expect(result.providerName, equals('Test Provider'));
      verify(() => mockRepository.deleteInferenceProviderWithModels('test-id'))
          .called(1);
    });

    test('should reset form fields', () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testConfig,
      );

      // Load the existing config first
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: 'test-id').notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: 'test-id').future,
      );

      // Verify fields are populated
      expect(controller.nameController.text, isNotEmpty);
      expect(controller.apiKeyController.text, isNotEmpty);

      // Act
      controller.reset();

      // Assert
      expect(controller.nameController.text, isEmpty);
      expect(controller.apiKeyController.text, isEmpty);
      expect(controller.baseUrlController.text, isEmpty);
      expect(controller.descriptionController.text, isEmpty);
    });

    test('should update form state when name is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.nameChanged('New Name');
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.name.value, equals('New Name'));
    });

    test('should update form state when API key is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.apiKeyChanged('new-api-key');
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.apiKey.value, equals('new-api-key'));
    });

    test('should update form state when base URL is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.baseUrlChanged('https://new.example.com');
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.baseUrl.value, equals('https://new.example.com'));
    });

    test('should update form state when comment is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.descriptionChanged('New comment');
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.description.value, equals('New comment'));
    });

    test('should update form state when inference provider type is changed',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.anthropic);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.anthropic),
      );
    });

    test('should set baseUrl when Gemini provider type is selected', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.gemini);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        controller.baseUrlController.text,
        equals('https://generativelanguage.googleapis.com/v1beta/openai'),
      );
      expect(
        formState?.baseUrl.value,
        equals('https://generativelanguage.googleapis.com/v1beta/openai'),
      );
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.gemini),
      );
    });

    test('updates baseUrl when inferenceProviderType changes to gemini',
        () async {
      // Initially base URL is empty
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      expect(controller.baseUrlController.text, isEmpty);

      // Change inference provider type to Gemini
      controller.inferenceProviderTypeChanged(InferenceProviderType.gemini);

      // Verify base URL is updated
      expect(
        controller.baseUrlController.text,
        'https://generativelanguage.googleapis.com/v1beta/openai',
      );
    });

    test('should set baseUrl when OpenAI provider type is selected', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        controller.baseUrlController.text,
        equals('https://api.openai.com/v1'),
      );
      expect(
        formState?.baseUrl.value,
        equals('https://api.openai.com/v1'),
      );
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.openAi),
      );
    });

    test('should set baseUrl when Anthropic provider type is selected',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.anthropic);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        controller.baseUrlController.text,
        equals('https://api.anthropic.com/v1'),
      );
      expect(
        formState?.baseUrl.value,
        equals('https://api.anthropic.com/v1'),
      );
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.anthropic),
      );
    });

    test('should set baseUrl when OpenRouter provider type is selected',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.openRouter);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        controller.baseUrlController.text,
        equals('https://openrouter.ai/api/v1'),
      );
      expect(
        formState?.baseUrl.value,
        equals('https://openrouter.ai/api/v1'),
      );
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.openRouter),
      );
    });

    test(
        'should set name when Anthropic provider type is selected and name is empty',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.anthropic);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(controller.nameController.text, equals('Anthropic'));
      expect(formState?.name.value, equals('Anthropic'));
    });

    test(
        'should set name when OpenRouter provider type is selected and name is empty',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.openRouter);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(controller.nameController.text, equals('OpenRouter'));
      expect(formState?.name.value, equals('OpenRouter'));
    });

    test('should not override existing name when provider type is changed',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Set a custom name first
      controller.nameChanged('My Custom Provider');

      // Act
      // ignore_for_file: cascade_invocations
      controller.inferenceProviderTypeChanged(InferenceProviderType.anthropic);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(controller.nameController.text, equals('My Custom Provider'));
      expect(formState?.name.value, equals('My Custom Provider'));
    });
  });

  group('API Key Validation for Ollama', () {
    test('should allow empty API key for Ollama provider', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.ollama);
      controller.nameChanged('My Ollama');
      controller.baseUrlChanged('http://localhost:11434/v1');
      // Don't set API key - leave it empty

      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.apiKey.value, isEmpty);
      expect(
          formState?.apiKey.isValid, isTrue); // Should be valid even when empty
      expect(formState?.isValid, isTrue); // Overall form should be valid
    });

    test('should clear API key when switching to Ollama', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // First set up a provider with API key
      controller.nameChanged('OpenAI Provider');
      controller.apiKeyChanged('sk-1234567890');
      controller.baseUrlChanged('https://api.openai.com/v1');

      // Act - switch to Ollama
      controller.inferenceProviderTypeChanged(InferenceProviderType.ollama);

      // Assert
      expect(controller.apiKeyController.text, isEmpty);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;
      expect(formState?.apiKey.value, isEmpty);
    });

    test('should require API key for non-Ollama providers', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act - Set up OpenAI without API key
      controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
      controller.nameChanged('OpenAI Provider');
      controller.baseUrlChanged('https://api.openai.com/v1');
      // Don't set API key

      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.apiKey.value, isEmpty);
      expect(
          formState?.apiKey.isValid, isFalse); // Should be invalid when empty
      expect(formState?.isValid, isFalse); // Overall form should be invalid
    });

    test('should load existing Ollama provider with empty API key', () async {
      // Arrange
      when(() => mockRepository.getConfigById('ollama-id')).thenAnswer(
        (_) async => ollamaConfig,
      );

      // Act
      final formState = await container.read(
        inferenceProviderFormControllerProvider(configId: 'ollama-id').future,
      );

      // Assert
      expect(formState, isNotNull);
      expect(formState?.name.value, equals('Ollama Local'));
      expect(formState?.apiKey.value, isEmpty);
      expect(
          formState?.apiKey.isValid, isTrue); // Should be valid even when empty
      expect(formState?.baseUrl.value, equals('http://localhost:11434'));
      expect(formState?.inferenceProviderType,
          equals(InferenceProviderType.ollama));
      expect(formState?.isValid, isTrue);
    });

    test('should set baseUrl and clear API key when Ollama is selected',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.ollama);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        controller.baseUrlController.text,
        equals('http://localhost:11434'),
      );
      expect(
        formState?.baseUrl.value,
        equals('http://localhost:11434'),
      );
      expect(controller.apiKeyController.text, isEmpty);
      expect(formState?.apiKey.value, isEmpty);
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.ollama),
      );
    });

    test('should properly validate form when switching between providers',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Start with OpenAI
      controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
      controller.nameChanged('My Provider');
      controller.baseUrlChanged('https://api.openai.com/v1');

      var formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;
      expect(formState?.isValid, isFalse); // Invalid without API key

      // Add API key
      controller.apiKeyChanged('sk-test-key');
      formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;
      expect(formState?.isValid, isTrue); // Now valid with API key

      // Switch to Ollama
      controller.inferenceProviderTypeChanged(InferenceProviderType.ollama);
      formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;
      expect(formState?.isValid, isTrue); // Still valid without API key

      // Switch back to OpenAI
      controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
      formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;
      expect(formState?.isValid,
          isFalse); // Invalid again because API key was cleared
    });
  });

  group('Whisper Provider Tests', () {
    test('should set baseUrl and clear API key when Whisper is selected',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.whisper);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        controller.baseUrlController.text,
        equals('http://localhost:8084'),
      );
      expect(
        formState?.baseUrl.value,
        equals('http://localhost:8084'),
      );
      expect(controller.apiKeyController.text, isEmpty);
      expect(formState?.apiKey.value, isEmpty);
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.whisper),
      );
    });

    test(
        'should set name when Whisper provider type is selected and name is empty',
        () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.whisper);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(controller.nameController.text, equals('Whisper (local)'));
      expect(formState?.name.value, equals('Whisper (local)'));
    });

    test('should allow empty API key for Whisper provider', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceProviderFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.whisper);
      controller.nameChanged('My Whisper');
      controller.baseUrlChanged('http://localhost:8084');
      // Don't set API key - leave it empty

      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.apiKey.value, isEmpty);
      expect(
          formState?.apiKey.isValid, isTrue); // Should be valid even when empty
      expect(formState?.isValid, isTrue); // Overall form should be valid
    });
  });

  group('Model Prepopulation Tests', () {
    test('should save config when adding a new inference provider', () async {
      // Arrange
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(() => mockRepository.getConfigsByType(AiConfigType.model))
          .thenAnswer((_) async => []);

      // Act
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );

      final newConfig = AiConfig.inferenceProvider(
        id: 'new-provider-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test Provider',
        createdAt: DateTime.now(),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      await controller.addConfig(newConfig);

      // Assert
      verify(() => mockRepository.saveConfig(newConfig)).called(1);
    });
  });
}
