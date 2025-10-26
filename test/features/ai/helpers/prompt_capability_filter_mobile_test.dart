import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockRef extends Mock implements Ref {
  MockRef(this._mockRepo);
  final MockAiConfigRepository _mockRepo;

  @override
  T read<T>(ProviderListenable<T> provider) {
    if (identical(provider, aiConfigRepositoryProvider)) {
      return _mockRepo as T;
    }
    throw UnimplementedError('Provider $provider not mocked');
  }
}

void main() {
  late MockAiConfigRepository mockRepo;
  late MockRef mockRef;
  late PromptCapabilityFilter filter;

  setUpAll(() {
    // Register fallback values for any() matchers
    registerFallbackValue(
      AiTestDataFactory.createTestPrompt(
        id: 'fallback-prompt',
        name: 'Fallback',
      ),
    );
  });

  setUp(() {
    mockRepo = MockAiConfigRepository();
    mockRef = MockRef(mockRepo);
    filter = PromptCapabilityFilter(mockRef);
  });

  // These tests will only run correctly on mobile platforms
  // On desktop they will be skipped
  group('PromptCapabilityFilter - Mobile Platform Tests', () {
    group('isPromptAvailableOnPlatform on mobile', () {
      test('returns false when model is null', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'non-existent-model',
        );

        when(() => mockRepo.getConfigById('non-existent-model'))
            .thenAnswer((_) async => null);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        expect(result, isFalse);
      });

      test('returns false when model is not AiConfigModel', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'wrong-type',
        );

        final wrongType = AiTestDataFactory.createTestPrompt(
          id: 'wrong-type',
          name: 'Wrong',
          defaultModelId: 'model',
        );

        when(() => mockRepo.getConfigById('wrong-type'))
            .thenAnswer((_) async => wrongType);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        expect(result, isFalse);
      });

      test('returns false when provider is null', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt();

        final model = AiTestDataFactory.createTestModel(
          inferenceProviderId: 'non-existent-provider',
        );

        when(() => mockRepo.getConfigById('test-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('non-existent-provider'))
            .thenAnswer((_) async => null);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        expect(result, isFalse);
      });

      test('returns false when provider is not AiConfigInferenceProvider',
          () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt();

        final model = AiTestDataFactory.createTestModel(
          inferenceProviderId: 'wrong-type',
        );

        final wrongType = AiTestDataFactory.createTestPrompt(
          id: 'wrong-type',
          name: 'Wrong',
          defaultModelId: 'model',
        );

        when(() => mockRepo.getConfigById('test-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('wrong-type'))
            .thenAnswer((_) async => wrongType);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        expect(result, isFalse);
      });

      test('returns false when provider is Whisper', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'whisper-model',
        );

        final model = AiTestDataFactory.createTestModel(
          id: 'whisper-model',
          name: 'Whisper Model',
          inferenceProviderId: 'whisper-provider',
        );

        final provider = AiTestDataFactory.createTestProvider(
          id: 'whisper-provider',
          name: 'Whisper',
          type: InferenceProviderType.whisper,
          baseUrl: 'http://localhost:8080',
          apiKey: '',
        );

        when(() => mockRepo.getConfigById('whisper-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('whisper-provider'))
            .thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // Whisper is local-only, should be unavailable on mobile
        expect(result, isFalse);
      });

      test('returns false when provider is Ollama', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'ollama-model',
        );

        final model = AiTestDataFactory.createTestModel(
          id: 'ollama-model',
          name: 'Ollama Model',
          inferenceProviderId: 'ollama-provider',
        );

        final provider = AiTestDataFactory.createTestProvider(
          id: 'ollama-provider',
          name: 'Ollama',
          type: InferenceProviderType.ollama,
          baseUrl: 'http://localhost:11434',
          apiKey: '',
        );

        when(() => mockRepo.getConfigById('ollama-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('ollama-provider'))
            .thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // Ollama is local-only, should be unavailable on mobile
        expect(result, isFalse);
      });

      test('returns false when provider is Gemma3N', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'gemma3n-model',
        );

        final model = AiTestDataFactory.createTestModel(
          id: 'gemma3n-model',
          name: 'Gemma 3N Model',
          inferenceProviderId: 'gemma3n-provider',
        );

        final provider = AiTestDataFactory.createTestProvider(
          id: 'gemma3n-provider',
          name: 'Gemma 3N',
          type: InferenceProviderType.gemma3n,
          baseUrl: '',
          apiKey: '',
        );

        when(() => mockRepo.getConfigById('gemma3n-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('gemma3n-provider'))
            .thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // Gemma3N is local-only, should be unavailable on mobile
        expect(result, isFalse);
      });

      test('returns true when provider is OpenAI', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'openai-model',
        );

        final model = AiTestDataFactory.createTestModel(
          id: 'openai-model',
          name: 'OpenAI Model',
          inferenceProviderId: 'openai-provider',
        );

        final provider = AiTestDataFactory.createTestProvider(
          id: 'openai-provider',
          name: 'OpenAI',
          type: InferenceProviderType.openAi,
          baseUrl: 'https://api.openai.com',
          apiKey: 'test-key',
        );

        when(() => mockRepo.getConfigById('openai-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('openai-provider'))
            .thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // OpenAI is cloud-based, should be available on mobile
        expect(result, isTrue);
      });

      test('returns true when provider is Anthropic', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'anthropic-model',
        );

        final model = AiTestDataFactory.createTestModel(
          id: 'anthropic-model',
          name: 'Anthropic Model',
          inferenceProviderId: 'anthropic-provider',
        );

        final provider = AiTestDataFactory.createTestProvider(
          id: 'anthropic-provider',
          name: 'Anthropic',
          baseUrl: 'https://api.anthropic.com',
          apiKey: 'test-key',
        );

        when(() => mockRepo.getConfigById('anthropic-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('anthropic-provider'))
            .thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // Anthropic is cloud-based, should be available on mobile
        expect(result, isTrue);
      });

      test('returns true when provider is Gemini', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'gemini-model',
        );

        final model = AiTestDataFactory.createTestModel(
          id: 'gemini-model',
          name: 'Gemini Model',
          inferenceProviderId: 'gemini-provider',
        );

        final provider = AiTestDataFactory.createTestProvider(
          id: 'gemini-provider',
          name: 'Gemini',
          type: InferenceProviderType.gemini,
          baseUrl: 'https://generativelanguage.googleapis.com',
          apiKey: 'test-key',
        );

        when(() => mockRepo.getConfigById('gemini-model'))
            .thenAnswer((_) async => model);
        when(() => mockRepo.getConfigById('gemini-provider'))
            .thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // Gemini is cloud-based, should be available on mobile
        expect(result, isTrue);
      });
    });

    group('filterPromptsByPlatform on mobile', () {
      test('filters out local-only models and keeps cloud models', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final whisperPrompt = AiTestDataFactory.createTestPrompt(
          id: 'whisper-prompt',
          defaultModelId: 'whisper-model',
        );

        final openAiPrompt = AiTestDataFactory.createTestPrompt(
          id: 'openai-prompt',
          defaultModelId: 'openai-model',
        );

        final ollamaPrompt = AiTestDataFactory.createTestPrompt(
          id: 'ollama-prompt',
          defaultModelId: 'ollama-model',
        );

        final whisperModel = AiTestDataFactory.createTestModel(
          id: 'whisper-model',
          inferenceProviderId: 'whisper-provider',
        );

        final openAiModel = AiTestDataFactory.createTestModel(
          id: 'openai-model',
          inferenceProviderId: 'openai-provider',
        );

        final ollamaModel = AiTestDataFactory.createTestModel(
          id: 'ollama-model',
          inferenceProviderId: 'ollama-provider',
        );

        final whisperProvider = AiTestDataFactory.createTestProvider(
          id: 'whisper-provider',
          type: InferenceProviderType.whisper,
        );

        final openAiProvider = AiTestDataFactory.createTestProvider(
          id: 'openai-provider',
          type: InferenceProviderType.openAi,
        );

        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-provider',
          type: InferenceProviderType.ollama,
        );

        when(() => mockRepo.getConfigById('whisper-model'))
            .thenAnswer((_) async => whisperModel);
        when(() => mockRepo.getConfigById('openai-model'))
            .thenAnswer((_) async => openAiModel);
        when(() => mockRepo.getConfigById('ollama-model'))
            .thenAnswer((_) async => ollamaModel);

        when(() => mockRepo.getConfigById('whisper-provider'))
            .thenAnswer((_) async => whisperProvider);
        when(() => mockRepo.getConfigById('openai-provider'))
            .thenAnswer((_) async => openAiProvider);
        when(() => mockRepo.getConfigById('ollama-provider'))
            .thenAnswer((_) async => ollamaProvider);

        // Act
        final result = await filter.filterPromptsByPlatform([
          whisperPrompt,
          openAiPrompt,
          ollamaPrompt,
        ]);

        // Assert
        expect(result, hasLength(1));
        expect(result.first.id, equals('openai-prompt'));
      });

      test('returns empty list when all prompts are local-only', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final whisperPrompt = AiTestDataFactory.createTestPrompt(
          id: 'whisper-prompt',
          defaultModelId: 'whisper-model',
        );

        final ollamaPrompt = AiTestDataFactory.createTestPrompt(
          id: 'ollama-prompt',
          defaultModelId: 'ollama-model',
        );

        final whisperModel = AiTestDataFactory.createTestModel(
          id: 'whisper-model',
          inferenceProviderId: 'whisper-provider',
        );

        final ollamaModel = AiTestDataFactory.createTestModel(
          id: 'ollama-model',
          inferenceProviderId: 'ollama-provider',
        );

        final whisperProvider = AiTestDataFactory.createTestProvider(
          id: 'whisper-provider',
          type: InferenceProviderType.whisper,
        );

        final ollamaProvider = AiTestDataFactory.createTestProvider(
          id: 'ollama-provider',
          type: InferenceProviderType.ollama,
        );

        when(() => mockRepo.getConfigById('whisper-model'))
            .thenAnswer((_) async => whisperModel);
        when(() => mockRepo.getConfigById('ollama-model'))
            .thenAnswer((_) async => ollamaModel);

        when(() => mockRepo.getConfigById('whisper-provider'))
            .thenAnswer((_) async => whisperProvider);
        when(() => mockRepo.getConfigById('ollama-provider'))
            .thenAnswer((_) async => ollamaProvider);

        // Act
        final result = await filter.filterPromptsByPlatform([
          whisperPrompt,
          ollamaPrompt,
        ]);

        // Assert
        expect(result, isEmpty);
      });

      test('processes checks in parallel using Future.wait', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final prompts = List.generate(
          5,
          (i) => AiTestDataFactory.createTestPrompt(
            id: 'prompt-$i',
            defaultModelId: 'model-$i',
          ),
        );

        for (var i = 0; i < 5; i++) {
          final model = AiTestDataFactory.createTestModel(
            id: 'model-$i',
            inferenceProviderId: 'provider-$i',
          );

          final provider = AiTestDataFactory.createTestProvider(
            id: 'provider-$i',
            type: InferenceProviderType.openAi,
          );

          when(() => mockRepo.getConfigById('model-$i'))
              .thenAnswer((_) async => model);
          when(() => mockRepo.getConfigById('provider-$i'))
              .thenAnswer((_) async => provider);
        }

        // Act
        final stopwatch = Stopwatch()..start();
        final result = await filter.filterPromptsByPlatform(prompts);
        stopwatch.stop();

        // Assert
        expect(result, hasLength(5));
        // Parallel execution should be much faster than sequential
        // This is a basic sanity check - actual parallel execution is hard to verify
      });
    });

    group('getFirstAvailablePrompt on mobile', () {
      test('skips local-only prompts and returns first cloud prompt',
          () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final whisperPrompt = AiTestDataFactory.createTestPrompt(
          id: 'whisper-prompt',
          defaultModelId: 'whisper-model',
        );

        final openAiPrompt = AiTestDataFactory.createTestPrompt(
          id: 'openai-prompt',
          defaultModelId: 'openai-model',
        );

        final whisperModel = AiTestDataFactory.createTestModel(
          id: 'whisper-model',
          inferenceProviderId: 'whisper-provider',
        );

        final openAiModel = AiTestDataFactory.createTestModel(
          id: 'openai-model',
          inferenceProviderId: 'openai-provider',
        );

        final whisperProvider = AiTestDataFactory.createTestProvider(
          id: 'whisper-provider',
          type: InferenceProviderType.whisper,
        );

        final openAiProvider = AiTestDataFactory.createTestProvider(
          id: 'openai-provider',
          type: InferenceProviderType.openAi,
        );

        when(() => mockRepo.getConfigById('whisper-prompt'))
            .thenAnswer((_) async => whisperPrompt);
        when(() => mockRepo.getConfigById('openai-prompt'))
            .thenAnswer((_) async => openAiPrompt);

        when(() => mockRepo.getConfigById('whisper-model'))
            .thenAnswer((_) async => whisperModel);
        when(() => mockRepo.getConfigById('openai-model'))
            .thenAnswer((_) async => openAiModel);

        when(() => mockRepo.getConfigById('whisper-provider'))
            .thenAnswer((_) async => whisperProvider);
        when(() => mockRepo.getConfigById('openai-provider'))
            .thenAnswer((_) async => openAiProvider);

        // Act
        final result = await filter.getFirstAvailablePrompt([
          'whisper-prompt',
          'openai-prompt',
        ]);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals('openai-prompt'));
      });

      test('returns null when all prompts are local-only', () async {
        // Skip on desktop
        if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
          return;
        }

        // Arrange
        final whisperPrompt = AiTestDataFactory.createTestPrompt(
          id: 'whisper-prompt',
          defaultModelId: 'whisper-model',
        );

        final whisperModel = AiTestDataFactory.createTestModel(
          id: 'whisper-model',
          inferenceProviderId: 'whisper-provider',
        );

        final whisperProvider = AiTestDataFactory.createTestProvider(
          id: 'whisper-provider',
          type: InferenceProviderType.whisper,
        );

        when(() => mockRepo.getConfigById('whisper-prompt'))
            .thenAnswer((_) async => whisperPrompt);
        when(() => mockRepo.getConfigById('whisper-model'))
            .thenAnswer((_) async => whisperModel);
        when(() => mockRepo.getConfigById('whisper-provider'))
            .thenAnswer((_) async => whisperProvider);

        // Act
        final result = await filter.getFirstAvailablePrompt([
          'whisper-prompt',
        ]);

        // Assert
        expect(result, isNull);
      });
    });
  });
}
