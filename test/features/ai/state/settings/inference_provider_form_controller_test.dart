import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/constants/provider_config.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_provider_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/settings/inference_provider_form_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

enum _GeneratedProviderFormOperationKind {
  name,
  apiKey,
  baseUrl,
  description,
  providerType,
}

enum _GeneratedProviderFormTextSlot {
  empty,
  short,
  valid,
  apiKey,
  url,
  invalidUrl,
}

enum _GeneratedProviderFormTypeSlot {
  alibaba,
  anthropic,
  gemini,
  genericOpenAi,
  mistral,
  nebiusAiStudio,
  openAi,
  openRouter,
  ollama,
  voxtral,
  whisper,
}

String _generatedProviderFormText(_GeneratedProviderFormTextSlot slot) {
  return switch (slot) {
    _GeneratedProviderFormTextSlot.empty => '',
    _GeneratedProviderFormTextSlot.short => 'xy',
    _GeneratedProviderFormTextSlot.valid => 'Generated provider',
    _GeneratedProviderFormTextSlot.apiKey => 'sk-generated-key',
    _GeneratedProviderFormTextSlot.url => 'https://generated.example.com/v1',
    _GeneratedProviderFormTextSlot.invalidUrl => 'not a url',
  };
}

InferenceProviderType _generatedProviderType(
  _GeneratedProviderFormTypeSlot slot,
) {
  return switch (slot) {
    _GeneratedProviderFormTypeSlot.alibaba => InferenceProviderType.alibaba,
    _GeneratedProviderFormTypeSlot.anthropic => InferenceProviderType.anthropic,
    _GeneratedProviderFormTypeSlot.gemini => InferenceProviderType.gemini,
    _GeneratedProviderFormTypeSlot.genericOpenAi =>
      InferenceProviderType.genericOpenAi,
    _GeneratedProviderFormTypeSlot.mistral => InferenceProviderType.mistral,
    _GeneratedProviderFormTypeSlot.nebiusAiStudio =>
      InferenceProviderType.nebiusAiStudio,
    _GeneratedProviderFormTypeSlot.openAi => InferenceProviderType.openAi,
    _GeneratedProviderFormTypeSlot.openRouter =>
      InferenceProviderType.openRouter,
    _GeneratedProviderFormTypeSlot.ollama => InferenceProviderType.ollama,
    _GeneratedProviderFormTypeSlot.voxtral => InferenceProviderType.voxtral,
    _GeneratedProviderFormTypeSlot.whisper => InferenceProviderType.whisper,
  };
}

class _GeneratedProviderFormOperation {
  const _GeneratedProviderFormOperation({
    required this.kind,
    required this.textSlot,
    required this.typeSlot,
  });

  final _GeneratedProviderFormOperationKind kind;
  final _GeneratedProviderFormTextSlot textSlot;
  final _GeneratedProviderFormTypeSlot typeSlot;

  String get text => _generatedProviderFormText(textSlot);

  InferenceProviderType get providerType => _generatedProviderType(typeSlot);

  @override
  String toString() {
    return '_GeneratedProviderFormOperation('
        'kind: $kind, textSlot: $textSlot, typeSlot: $typeSlot)';
  }
}

class _GeneratedProviderFormScenario {
  const _GeneratedProviderFormScenario({required this.operations});

  final List<_GeneratedProviderFormOperation> operations;

  @override
  String toString() {
    return '_GeneratedProviderFormScenario(operations: $operations)';
  }
}

class _ExpectedProviderFormState {
  String name = '';
  String apiKey = '';
  String baseUrl = '';
  String description = '';
  InferenceProviderType providerType = InferenceProviderType.genericOpenAi;

  void apply(_GeneratedProviderFormOperation operation) {
    switch (operation.kind) {
      case _GeneratedProviderFormOperationKind.name:
        name = operation.text;
      case _GeneratedProviderFormOperationKind.apiKey:
        apiKey = operation.text;
      case _GeneratedProviderFormOperationKind.baseUrl:
        baseUrl = operation.text;
      case _GeneratedProviderFormOperationKind.description:
        description = operation.text;
      case _GeneratedProviderFormOperationKind.providerType:
        final nextType = operation.providerType;
        if (nextType == providerType) {
          return;
        }
        providerType = nextType;
        final defaultBaseUrl = ProviderConfig.getDefaultBaseUrl(nextType);
        if (defaultBaseUrl.isNotEmpty) {
          baseUrl = defaultBaseUrl;
        }
        if (name.isEmpty) {
          final defaultName = ProviderConfig.getDefaultName(nextType);
          if (defaultName.isNotEmpty) {
            name = defaultName;
          }
        }
        if (!ProviderConfig.requiresApiKey(nextType)) {
          apiKey = '';
        }
    }
  }
}

extension _AnyGeneratedProviderFormScenario on glados.Any {
  glados.Generator<_GeneratedProviderFormOperationKind>
  get providerFormOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedProviderFormOperationKind.values);

  glados.Generator<_GeneratedProviderFormTextSlot> get providerFormTextSlot =>
      glados.AnyUtils(this).choose(_GeneratedProviderFormTextSlot.values);

  glados.Generator<_GeneratedProviderFormTypeSlot> get providerFormTypeSlot =>
      glados.AnyUtils(this).choose(_GeneratedProviderFormTypeSlot.values);

  glados.Generator<_GeneratedProviderFormOperation> get providerFormOperation =>
      glados.CombinableAny(this).combine3(
        providerFormOperationKind,
        providerFormTextSlot,
        providerFormTypeSlot,
        (
          _GeneratedProviderFormOperationKind kind,
          _GeneratedProviderFormTextSlot textSlot,
          _GeneratedProviderFormTypeSlot typeSlot,
        ) => _GeneratedProviderFormOperation(
          kind: kind,
          textSlot: textSlot,
          typeSlot: typeSlot,
        ),
      );

  glados.Generator<_GeneratedProviderFormScenario> get providerFormScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 45, providerFormOperation)
          .map(
            (operations) => _GeneratedProviderFormScenario(
              operations: operations,
            ),
          );
}

void main() {
  late MockAiConfigRepository mockRepository;
  late ProviderContainer container;
  final testConfig = AiConfig.inferenceProvider(
    id: 'test-id',
    baseUrl: 'https://api.example.com',
    apiKey: 'test-api-key',
    name: 'Test API',
    createdAt: DateTime(2024, 3, 15),
    inferenceProviderType: InferenceProviderType.genericOpenAi,
  );

  final ollamaConfig = AiConfig.inferenceProvider(
    id: 'ollama-id',
    baseUrl: 'http://localhost:11434',
    apiKey: '',
    name: 'Ollama Local',
    createdAt: DateTime(2024, 3, 15),
    inferenceProviderType: InferenceProviderType.ollama,
  );

  setUpAll(() {
    registerFallbackValue(testConfig);
    registerFallbackValue(ollamaConfig);
    registerFallbackValue(AiConfigType.model);
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
    test(
      'should load existing config in build when configId is provided',
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
      },
    );

    test('should have empty form state when configId is null', () async {
      // Act
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      final formState = await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

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
      when(
        () => mockRepository.getConfigsByType(any()),
      ).thenAnswer((_) async => []);

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
        createdAt: DateTime(2024, 3, 15),
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

    test('should update form state when name is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act
      controller.nameChanged('New Name');
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.name.value, equals('New Name'));
    });

    test('should update form state when API key is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act
      controller.apiKeyChanged('new-api-key');
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.apiKey.value, equals('new-api-key'));
    });

    test('should update form state when base URL is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act
      controller.baseUrlChanged('https://new.example.com');
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.baseUrl.value, equals('https://new.example.com'));
    });

    test(
      'should update form state when inference provider type is changed',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(
          InferenceProviderType.anthropic,
        );
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(
          formState?.inferenceProviderType,
          equals(InferenceProviderType.anthropic),
        );
      },
    );

    test(
      'clears baseUrl when switching to a provider that does not use one',
      () async {
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        controller
          ..inferenceProviderTypeChanged(InferenceProviderType.gemini)
          ..inferenceProviderTypeChanged(InferenceProviderType.mlxAudio);

        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

        expect(controller.baseUrlController.text, isEmpty);
        expect(formState?.baseUrl.value, isEmpty);
        expect(
          formState?.inferenceProviderType,
          equals(InferenceProviderType.mlxAudio),
        );
      },
    );

    test('should set baseUrl when Gemini provider type is selected', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.gemini);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

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

    test(
      'updates baseUrl when inferenceProviderType changes to gemini',
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
      },
    );

    test('should set baseUrl when OpenAI provider type is selected', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

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

    test(
      'should set baseUrl when Anthropic provider type is selected',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(
          InferenceProviderType.anthropic,
        );
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

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
      },
    );

    test(
      'should set baseUrl when OpenRouter provider type is selected',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(
          InferenceProviderType.openRouter,
        );
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

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
      },
    );

    test(
      'should set name when Anthropic provider type is selected and name is empty',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(
          InferenceProviderType.anthropic,
        );
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(controller.nameController.text, equals('Anthropic'));
        expect(formState?.name.value, equals('Anthropic'));
      },
    );

    test(
      'should set name when OpenRouter provider type is selected and name is empty',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(
          InferenceProviderType.openRouter,
        );
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(controller.nameController.text, equals('OpenRouter'));
        expect(formState?.name.value, equals('OpenRouter'));
      },
    );

    test(
      'should not override existing name when provider type is changed',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Set a custom name first
        controller.nameChanged('My Custom Provider');

        // Act
        // ignore_for_file: cascade_invocations
        controller.inferenceProviderTypeChanged(
          InferenceProviderType.anthropic,
        );
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(controller.nameController.text, equals('My Custom Provider'));
        expect(formState?.name.value, equals('My Custom Provider'));
      },
    );
  });

  group('API Key Validation for Ollama', () {
    test('should allow empty API key for Ollama provider', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.ollama);
      controller.nameChanged('My Ollama');
      controller.baseUrlChanged('http://localhost:11434/v1');
      // Don't set API key - leave it empty

      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.apiKey.value, isEmpty);
      expect(
        formState?.apiKey.isValid,
        isTrue,
      ); // Should be valid even when empty
      expect(formState?.isValid, isTrue); // Overall form should be valid
    });

    test('should clear API key when switching to Ollama', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

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
          .value;
      expect(formState?.apiKey.value, isEmpty);
    });

    test('should require API key for non-Ollama providers', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act - Set up OpenAI without API key
      controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
      controller.nameChanged('OpenAI Provider');
      controller.baseUrlChanged('https://api.openai.com/v1');
      // Don't set API key

      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.apiKey.value, isEmpty);
      expect(
        formState?.apiKey.isValid,
        isFalse,
      ); // Should be invalid when empty
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
        formState?.apiKey.isValid,
        isTrue,
      ); // Should be valid even when empty
      expect(formState?.baseUrl.value, equals('http://localhost:11434'));
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.ollama),
      );
      expect(formState?.isValid, isTrue);
    });

    test(
      'should set baseUrl and clear API key when Ollama is selected',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(InferenceProviderType.ollama);
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

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
      },
    );

    test(
      'should properly validate form when switching between providers',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Start with OpenAI
        controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
        controller.nameChanged('My Provider');
        controller.baseUrlChanged('https://api.openai.com/v1');

        var formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;
        expect(formState?.isValid, isFalse); // Invalid without API key

        // Add API key
        controller.apiKeyChanged('sk-test-key');
        formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;
        expect(formState?.isValid, isTrue); // Now valid with API key

        // Switch to Ollama
        controller.inferenceProviderTypeChanged(InferenceProviderType.ollama);
        formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;
        expect(formState?.isValid, isTrue); // Still valid without API key

        // Switch back to OpenAI
        controller.inferenceProviderTypeChanged(InferenceProviderType.openAi);
        formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;
        expect(
          formState?.isValid,
          isFalse,
        ); // Invalid again because API key was cleared
      },
    );

    glados.Glados(
      glados.any.providerFormScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated edit sequence semantics', (scenario) async {
      final generatedRepository = MockAiConfigRepository();
      final generatedContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(generatedRepository),
        ],
      );
      final expected = _ExpectedProviderFormState();

      try {
        final controller = generatedContainer.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await generatedContainer.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedProviderFormOperationKind.name:
              controller.nameChanged(operation.text);
            case _GeneratedProviderFormOperationKind.apiKey:
              controller.apiKeyChanged(operation.text);
            case _GeneratedProviderFormOperationKind.baseUrl:
              controller.baseUrlChanged(operation.text);
            case _GeneratedProviderFormOperationKind.description:
              controller.descriptionChanged(operation.text);
            case _GeneratedProviderFormOperationKind.providerType:
              controller.inferenceProviderTypeChanged(operation.providerType);
          }
          expected.apply(operation);

          final formState = generatedContainer
              .read(inferenceProviderFormControllerProvider(configId: null))
              .value!;

          expect(formState.name.value, expected.name, reason: '$scenario');
          expect(controller.nameController.text, expected.name);
          expect(formState.apiKey.value, expected.apiKey, reason: '$scenario');
          expect(controller.apiKeyController.text, expected.apiKey);
          expect(
            formState.baseUrl.value,
            expected.baseUrl,
            reason: '$scenario after $operation',
          );
          expect(controller.baseUrlController.text, expected.baseUrl);
          expect(
            formState.description.value,
            expected.description,
            reason: '$scenario',
          );
          expect(controller.descriptionController.text, expected.description);
          expect(formState.inferenceProviderType, expected.providerType);
          expect(
            formState.apiKey.isValid,
            !ProviderConfig.requiresApiKey(expected.providerType) ||
                expected.apiKey.isNotEmpty,
            reason: '$scenario after $operation',
          );
        }
      } finally {
        generatedContainer.dispose();
      }
    }, tags: 'glados');
  });

  group('Whisper Provider Tests', () {
    test(
      'should set baseUrl and clear API key when Whisper is selected',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(InferenceProviderType.whisper);
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

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
      },
    );

    test(
      'should set name when Whisper provider type is selected and name is empty',
      () async {
        // Arrange
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderTypeChanged(InferenceProviderType.whisper);
        final formState = container
            .read(inferenceProviderFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(controller.nameController.text, equals('Whisper (local)'));
        expect(formState?.name.value, equals('Whisper (local)'));
      },
    );

    test('should allow empty API key for Whisper provider', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act
      controller.inferenceProviderTypeChanged(InferenceProviderType.whisper);
      controller.nameChanged('My Whisper');
      controller.baseUrlChanged('http://localhost:8084');
      // Don't set API key - leave it empty

      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.apiKey.value, isEmpty);
      expect(
        formState?.apiKey.isValid,
        isTrue,
      ); // Should be valid even when empty
      expect(formState?.isValid, isTrue); // Overall form should be valid
    });
  });

  group('Preselected Provider Type Tests', () {
    test(
      'should pre-fill form with Gemini defaults when preselectedType is Gemini',
      () async {
        // Act
        final controller = container.read(
          inferenceProviderFormControllerProvider(
            configId: null,
            preselectedType: InferenceProviderType.gemini,
          ).notifier,
        );
        final formState = await container.read(
          inferenceProviderFormControllerProvider(
            configId: null,
            preselectedType: InferenceProviderType.gemini,
          ).future,
        );

        // Assert
        expect(
          formState?.inferenceProviderType,
          equals(InferenceProviderType.gemini),
        );
        expect(controller.nameController.text, equals('Gemini'));
        expect(
          controller.baseUrlController.text,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'),
        );
        expect(formState?.name.value, equals('Gemini'));
        expect(
          formState?.baseUrl.value,
          equals('https://generativelanguage.googleapis.com/v1beta/openai'),
        );
      },
    );

    test(
      'should pre-fill form with Anthropic defaults when preselectedType is Anthropic',
      () async {
        // Act
        final formState = await container.read(
          inferenceProviderFormControllerProvider(
            configId: null,
            preselectedType: InferenceProviderType.anthropic,
          ).future,
        );
        final controller = container.read(
          inferenceProviderFormControllerProvider(
            configId: null,
            preselectedType: InferenceProviderType.anthropic,
          ).notifier,
        );

        // Assert
        expect(
          formState?.inferenceProviderType,
          equals(InferenceProviderType.anthropic),
        );
        expect(controller.nameController.text, equals('Anthropic'));
        expect(
          controller.baseUrlController.text,
          equals('https://api.anthropic.com/v1'),
        );
      },
    );

    test(
      'should pre-fill form with Ollama defaults when preselectedType is Ollama',
      () async {
        // Act
        final formState = await container.read(
          inferenceProviderFormControllerProvider(
            configId: null,
            preselectedType: InferenceProviderType.ollama,
          ).future,
        );
        final controller = container.read(
          inferenceProviderFormControllerProvider(
            configId: null,
            preselectedType: InferenceProviderType.ollama,
          ).notifier,
        );

        // Assert
        expect(
          formState?.inferenceProviderType,
          equals(InferenceProviderType.ollama),
        );
        expect(controller.nameController.text, equals('Ollama (local)'));
        expect(
          controller.baseUrlController.text,
          equals('http://localhost:11434'),
        );
        // Ollama doesn't require API key
        expect(formState?.apiKey.isValid, isTrue);
      },
    );

    test('should ignore preselectedType when configId is provided', () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testConfig,
      );

      // Act - provide both configId and preselectedType
      final formState = await container.read(
        inferenceProviderFormControllerProvider(
          configId: 'test-id',
          preselectedType: InferenceProviderType.gemini,
        ).future,
      );

      // Assert - should load existing config, not use preselectedType
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.genericOpenAi),
      );
      expect(formState?.name.value, equals('Test API'));
      verify(() => mockRepository.getConfigById('test-id')).called(1);
    });

    test('should use genericOpenAi when no preselectedType provided', () async {
      // Act
      final formState = await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Assert
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.genericOpenAi),
      );
    });
  });

  group('Model Prepopulation Tests', () {
    test('should save config when adding a new inference provider', () async {
      // Arrange
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.getConfigsByType(any()),
      ).thenAnswer((_) async => []);

      // Act
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );

      final newConfig = AiConfig.inferenceProvider(
        id: 'new-provider-id',
        baseUrl: 'https://api.example.com',
        apiKey: 'test-api-key',
        name: 'Test Provider',
        createdAt: DateTime(2024, 3, 15),
        inferenceProviderType: InferenceProviderType.openAi,
      );

      await controller.addConfig(newConfig);

      // Assert
      verify(() => mockRepository.saveConfig(newConfig)).called(1);
    });

    test('should prepopulate models when adding Gemini provider', () async {
      // Arrange
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});
      when(
        () => mockRepository.getConfigsByType(any()),
      ).thenAnswer((_) async => []);

      // Act
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );

      final geminiConfig = AiConfig.inferenceProvider(
        id: 'gemini-provider-id',
        baseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
        apiKey: 'test-gemini-key',
        name: 'Gemini',
        createdAt: DateTime(2024, 3, 15),
        inferenceProviderType: InferenceProviderType.gemini,
      );

      await controller.addConfig(geminiConfig);

      // Assert - should save provider and check for existing models.
      // Two reads: the model prepopulation pass and the subsequent
      // profile upgrade pass each fetch the model rows.
      verify(() => mockRepository.saveConfig(geminiConfig)).called(1);
      verify(
        () => mockRepository.getConfigsByType(AiConfigType.model),
      ).called(2);
    });
  });

  group('Edge Cases', () {
    test(
      'should handle inferenceProviderTypeChanged when state is null',
      () async {
        // This tests the edge case where inferenceProviderTypeChanged is called
        // before build() completes. The method should create initial state.
        final controller = container.read(
          inferenceProviderFormControllerProvider(configId: null).notifier,
        );

        // Call the method before awaiting the future
        controller.inferenceProviderTypeChanged(InferenceProviderType.gemini);

        // Now await to ensure state is set
        final formState = await container.read(
          inferenceProviderFormControllerProvider(configId: null).future,
        );

        // The state should have Gemini as the provider type
        expect(
          formState?.inferenceProviderType,
          equals(InferenceProviderType.gemini),
        );
      },
    );

    test('should handle empty default name for genericOpenAi', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Act - genericOpenAi has no default name
      controller.inferenceProviderTypeChanged(
        InferenceProviderType.genericOpenAi,
      );
      final formState = container
          .read(inferenceProviderFormControllerProvider(configId: null))
          .value;

      // Assert - name should remain empty (no default for genericOpenAi)
      expect(
        formState?.inferenceProviderType,
        equals(InferenceProviderType.genericOpenAi),
      );
    });

    test('should sync controller text when value differs', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Manually set controller text to something different
      controller.nameController.text = 'Different Value';

      // Act - call nameChanged with a different value
      controller.nameChanged('New Value');

      // Assert - controller should be updated
      expect(controller.nameController.text, equals('New Value'));
    });

    test('should not update controller when value is same', () async {
      // Arrange
      final controller = container.read(
        inferenceProviderFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceProviderFormControllerProvider(configId: null).future,
      );

      // Set initial value
      controller.nameChanged('Same Value');
      expect(controller.nameController.text, equals('Same Value'));

      // Act - call with same value
      controller.nameChanged('Same Value');

      // Assert - should still be the same (no unnecessary updates)
      expect(controller.nameController.text, equals('Same Value'));
    });
  });

  // ---------------------------------------------------------------------------
  // Tests from inference_provider_form_controller_dirty_state_test.dart
  // ---------------------------------------------------------------------------
  group('InferenceProviderFormController - Dirty State Tracking', () {
    late ProviderContainer dirtyContainer;
    late MockAiConfigRepository dirtyMockRepo;

    const testDirtyConfigId = 'test-provider-id';
    final testDirtyConfig = AiConfigInferenceProvider(
      id: testDirtyConfigId,
      name: 'Test Provider',
      apiKey: 'test-api-key',
      baseUrl: 'https://api.test.com',
      description: 'Test Description',
      inferenceProviderType: InferenceProviderType.genericOpenAi,
      createdAt: DateTime(2024, 3, 15, 10, 30),
      updatedAt: DateTime(2024, 3, 15, 10, 30),
    );

    setUp(() {
      dirtyMockRepo = MockAiConfigRepository();
      dirtyContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(dirtyMockRepo),
        ],
      );
    });

    tearDown(() {
      dirtyContainer.dispose();
    });

    test(
      'form should start with clean (non-dirty) state when loading existing config',
      () async {
        when(
          () => dirtyMockRepo.getConfigById(testDirtyConfigId),
        ).thenAnswer((_) async => testDirtyConfig);

        await dirtyContainer.read(
          inferenceProviderFormControllerProvider(
            configId: testDirtyConfigId,
          ).future,
        );

        final state = dirtyContainer
            .read(
              inferenceProviderFormControllerProvider(
                configId: testDirtyConfigId,
              ),
            )
            .value;

        expect(state, isNotNull);
        expect(
          state!.isDirty,
          isFalse,
          reason: 'Form should not be dirty when initially loaded',
        );
      },
    );

    test('changing inferenceProviderType should make form dirty', () async {
      when(
        () => dirtyMockRepo.getConfigById(testDirtyConfigId),
      ).thenAnswer((_) async => testDirtyConfig);

      await dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).future,
      );

      final controller = dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).notifier,
      );

      var state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(state!.isDirty, isFalse);

      controller.inferenceProviderTypeChanged(InferenceProviderType.anthropic);

      state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(
        state!.isDirty,
        isTrue,
        reason: 'Form should be dirty after changing inferenceProviderType',
      );
    });

    test('changing text fields should make form dirty', () async {
      when(
        () => dirtyMockRepo.getConfigById(testDirtyConfigId),
      ).thenAnswer((_) async => testDirtyConfig);

      await dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).future,
      );

      final controller = dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).notifier,
      );

      var state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(state!.isDirty, isFalse);

      controller.nameChanged('Modified Provider Name');
      state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(
        state!.isDirty,
        isTrue,
        reason: 'Form should be dirty after changing name',
      );

      // Reset for next assertion
      dirtyContainer.dispose();
      dirtyContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(dirtyMockRepo),
        ],
      );
      await dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).future,
      );

      dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ).notifier,
          )
          .apiKeyChanged('modified-api-key');
      state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(
        state!.isDirty,
        isTrue,
        reason: 'Form should be dirty after changing apiKey',
      );

      // Reset for next assertion
      dirtyContainer.dispose();
      dirtyContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(dirtyMockRepo),
        ],
      );
      await dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).future,
      );

      dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ).notifier,
          )
          .baseUrlChanged('https://modified.test.com');
      state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(
        state!.isDirty,
        isTrue,
        reason: 'Form should be dirty after changing baseUrl',
      );
    });

    test('setting same value should not make form dirty', () async {
      when(
        () => dirtyMockRepo.getConfigById(testDirtyConfigId),
      ).thenAnswer((_) async => testDirtyConfig);

      await dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).future,
      );

      final controller = dirtyContainer.read(
        inferenceProviderFormControllerProvider(
          configId: testDirtyConfigId,
        ).notifier,
      );

      var state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(state!.isDirty, isFalse);

      // testDirtyConfig already has genericOpenAi
      controller.inferenceProviderTypeChanged(
        InferenceProviderType.genericOpenAi,
      );

      state = dirtyContainer
          .read(
            inferenceProviderFormControllerProvider(
              configId: testDirtyConfigId,
            ),
          )
          .value;
      expect(
        state!.isDirty,
        isFalse,
        reason: 'Form should not be dirty when setting same value',
      );
    });

    test(
      'changing provider type to predefined types should update fields and make form dirty',
      () async {
        when(
          () => dirtyMockRepo.getConfigById(testDirtyConfigId),
        ).thenAnswer((_) async => testDirtyConfig);

        await dirtyContainer.read(
          inferenceProviderFormControllerProvider(
            configId: testDirtyConfigId,
          ).future,
        );

        final controller = dirtyContainer.read(
          inferenceProviderFormControllerProvider(
            configId: testDirtyConfigId,
          ).notifier,
        );

        var state = dirtyContainer
            .read(
              inferenceProviderFormControllerProvider(
                configId: testDirtyConfigId,
              ),
            )
            .value;
        expect(state!.isDirty, isFalse);

        controller.inferenceProviderTypeChanged(InferenceProviderType.gemini);

        state = dirtyContainer
            .read(
              inferenceProviderFormControllerProvider(
                configId: testDirtyConfigId,
              ),
            )
            .value;
        expect(
          state!.isDirty,
          isTrue,
          reason: 'Form should be dirty after changing to Gemini',
        );
        expect(
          state.baseUrl.value,
          'https://generativelanguage.googleapis.com/v1beta/openai',
        );

        // Reset
        dirtyContainer.dispose();
        dirtyContainer = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(dirtyMockRepo),
          ],
        );

        // Test with empty name so it gets auto-populated
        final emptyNameConfig = testDirtyConfig.copyWith(name: '');
        when(
          () => dirtyMockRepo.getConfigById(testDirtyConfigId),
        ).thenAnswer((_) async => emptyNameConfig);

        await dirtyContainer.read(
          inferenceProviderFormControllerProvider(
            configId: testDirtyConfigId,
          ).future,
        );

        dirtyContainer
            .read(
              inferenceProviderFormControllerProvider(
                configId: testDirtyConfigId,
              ).notifier,
            )
            .inferenceProviderTypeChanged(InferenceProviderType.nebiusAiStudio);

        state = dirtyContainer
            .read(
              inferenceProviderFormControllerProvider(
                configId: testDirtyConfigId,
              ),
            )
            .value;
        expect(
          state!.isDirty,
          isTrue,
          reason: 'Form should be dirty after changing to Nebius',
        );
        expect(state.baseUrl.value, 'https://api.studio.nebius.com/v1');
        expect(state.name.value, 'Nebius AI Studio');
      },
    );
  });
}
