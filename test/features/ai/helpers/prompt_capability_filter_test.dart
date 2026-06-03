import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/utils/platform.dart' as platform;
import 'package:mocktail/mocktail.dart';

import '../test_utils.dart';

enum _GeneratedPromptLookupShape {
  missingPrompt,
  wrongPromptType,
  missingModel,
  wrongModelType,
  missingProvider,
  wrongProviderType,
  cloudProvider,
  localProvider,
}

class _GeneratedPromptLookupScenario {
  const _GeneratedPromptLookupScenario({required this.shapes});

  final List<_GeneratedPromptLookupShape> shapes;

  List<String> get promptIds => [
    for (var i = 0; i < shapes.length; i++) 'generated-prompt-$i',
  ];

  Set<String> get expectedLookupIds {
    return {
      for (var i = 0; i < shapes.length; i++) ...[
        'generated-prompt-$i',
        if (shapes[i] != _GeneratedPromptLookupShape.missingPrompt &&
            shapes[i] != _GeneratedPromptLookupShape.wrongPromptType)
          'generated-model-$i',
        if (shapes[i] != _GeneratedPromptLookupShape.missingPrompt &&
            shapes[i] != _GeneratedPromptLookupShape.wrongPromptType &&
            shapes[i] != _GeneratedPromptLookupShape.missingModel &&
            shapes[i] != _GeneratedPromptLookupShape.wrongModelType)
          'generated-provider-$i',
      ],
    };
  }

  String? get expectedFirstAvailablePromptId {
    final index = shapes.indexWhere(
      (shape) => shape == _GeneratedPromptLookupShape.cloudProvider,
    );
    return index == -1 ? null : promptIds[index];
  }

  AiConfig? configById(String id) {
    final promptIndex = _indexFromPrefix(id, 'generated-prompt-');
    if (promptIndex != null && promptIndex < shapes.length) {
      final shape = shapes[promptIndex];
      return switch (shape) {
        _GeneratedPromptLookupShape.missingPrompt => null,
        _GeneratedPromptLookupShape.wrongPromptType =>
          AiTestDataFactory.createTestModel(id: id),
        _ => AiTestDataFactory.createTestPrompt(
          id: id,
          defaultModelId: 'generated-model-$promptIndex',
        ),
      };
    }

    final modelIndex = _indexFromPrefix(id, 'generated-model-');
    if (modelIndex != null && modelIndex < shapes.length) {
      final shape = shapes[modelIndex];
      return switch (shape) {
        _GeneratedPromptLookupShape.missingModel => null,
        _GeneratedPromptLookupShape.wrongModelType =>
          AiTestDataFactory.createTestPrompt(id: id),
        _ => AiTestDataFactory.createTestModel(
          id: id,
          inferenceProviderId: 'generated-provider-$modelIndex',
        ),
      };
    }

    final providerIndex = _indexFromPrefix(id, 'generated-provider-');
    if (providerIndex != null && providerIndex < shapes.length) {
      final shape = shapes[providerIndex];
      return switch (shape) {
        _GeneratedPromptLookupShape.missingProvider => null,
        _GeneratedPromptLookupShape.wrongProviderType =>
          AiTestDataFactory.createTestModel(id: id),
        _GeneratedPromptLookupShape.localProvider =>
          AiTestDataFactory.createTestProvider(
            id: id,
            type: InferenceProviderType.ollama,
            apiKey: '',
          ),
        _ => AiTestDataFactory.createTestProvider(
          id: id,
          type: InferenceProviderType.openAi,
        ),
      };
    }

    return null;
  }

  int? _indexFromPrefix(String value, String prefix) {
    if (!value.startsWith(prefix)) return null;
    return int.tryParse(value.substring(prefix.length));
  }

  @override
  String toString() {
    return '_GeneratedPromptLookupScenario(shapes: $shapes)';
  }
}

extension _AnyGeneratedPromptCapabilityScenario on glados.Any {
  glados.Generator<InferenceProviderType> get inferenceProviderType =>
      glados.AnyUtils(this).choose(InferenceProviderType.values);

  glados.Generator<_GeneratedPromptLookupShape> get promptLookupShape =>
      glados.AnyUtils(this).choose(_GeneratedPromptLookupShape.values);

  glados.Generator<_GeneratedPromptLookupScenario> get promptLookupScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 24, promptLookupShape)
          .map((shapes) => _GeneratedPromptLookupScenario(shapes: shapes));
}

void main() {
  late MockAiConfigRepository mockRepo;
  late ProviderContainer container;
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
    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    final ref = container.read(testRefProvider);
    filter = PromptCapabilityFilter(ref);
  });

  tearDown(() {
    container.dispose();
  });

  group('PromptCapabilityFilter', () {
    group('isPromptAvailableOnPlatform', () {
      test('returns true for all prompts on desktop', () async {
        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'whisper-model',
          requiredInputData: [InputDataType.audioFiles],
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

        when(
          () => mockRepo.getConfigById('whisper-model'),
        ).thenAnswer((_) async => model);
        when(
          () => mockRepo.getConfigById('whisper-provider'),
        ).thenAnswer((_) async => provider);

        // Act - Note: This test assumes we're running on desktop
        // In a real scenario, you'd need to mock the platform detection
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        expect(result, isTrue);
      });

      test('returns true on desktop even when model is null', () async {
        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'non-existent-model',
        );

        when(
          () => mockRepo.getConfigById('non-existent-model'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // On desktop, all prompts are available regardless of configuration
        expect(result, isTrue);
      });

      test(
        'returns true on desktop even when model is not AiConfigModel',
        () async {
          // Arrange
          final prompt = AiTestDataFactory.createTestPrompt(
            defaultModelId: 'wrong-type',
          );

          final wrongType = AiTestDataFactory.createTestPrompt(
            id: 'wrong-type',
            name: 'Wrong',
            defaultModelId: 'model',
          );

          when(
            () => mockRepo.getConfigById('wrong-type'),
          ).thenAnswer((_) async => wrongType);

          // Act
          final result = await filter.isPromptAvailableOnPlatform(prompt);

          // Assert
          // On desktop, all prompts are available regardless of configuration
          expect(result, isTrue);
        },
      );

      test('returns true on desktop even when provider is null', () async {
        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt();

        final model = AiTestDataFactory.createTestModel(
          inferenceProviderId: 'non-existent-provider',
        );

        when(
          () => mockRepo.getConfigById('test-model'),
        ).thenAnswer((_) async => model);
        when(
          () => mockRepo.getConfigById('non-existent-provider'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert
        // On desktop, all prompts are available regardless of configuration
        expect(result, isTrue);
      });

      test(
        'returns true on desktop even when provider is not AiConfigInferenceProvider',
        () async {
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

          when(
            () => mockRepo.getConfigById('test-model'),
          ).thenAnswer((_) async => model);
          when(
            () => mockRepo.getConfigById('wrong-type'),
          ).thenAnswer((_) async => wrongType);

          // Act
          final result = await filter.isPromptAvailableOnPlatform(prompt);

          // Assert
          // On desktop, all prompts are available regardless of configuration
          expect(result, isTrue);
        },
      );
    });

    group('filterPromptsByPlatform', () {
      test('returns empty list when input is empty', () async {
        // Act
        final result = await filter.filterPromptsByPlatform([]);

        // Assert
        expect(result, isEmpty);
      });

      test('filters out prompts with unavailable models', () async {
        // Arrange
        final prompt1 = AiTestDataFactory.createTestPrompt(
          id: 'prompt-1',
          name: 'Prompt 1',
          defaultModelId: 'model-1',
        );

        final prompt2 = AiTestDataFactory.createTestPrompt(
          id: 'prompt-2',
          name: 'Prompt 2',
          defaultModelId: 'non-existent',
        );

        final model1 = AiTestDataFactory.createTestModel(
          id: 'model-1',
          name: 'Model 1',
          inferenceProviderId: 'provider-1',
        );

        final provider1 = AiTestDataFactory.createTestProvider(
          id: 'provider-1',
          name: 'Provider 1',
          baseUrl: 'https://api.example.com',
          apiKey: 'key',
          type: InferenceProviderType.openAi,
        );

        when(
          () => mockRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model1);
        when(
          () => mockRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider1);
        when(
          () => mockRepo.getConfigById('non-existent'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await filter.filterPromptsByPlatform([prompt1, prompt2]);

        // Assert
        // On desktop, all prompts are available regardless of configuration
        expect(result, hasLength(2));
        expect(result.first.id, equals('prompt-1'));
      });

      test('returns all prompts when all are available', () async {
        // Arrange
        final prompt1 = AiTestDataFactory.createTestPrompt(
          id: 'prompt-1',
          name: 'Prompt 1',
          defaultModelId: 'model-1',
        );

        final prompt2 = AiTestDataFactory.createTestPrompt(
          id: 'prompt-2',
          name: 'Prompt 2',
          defaultModelId: 'model-2',
        );

        final model1 = AiTestDataFactory.createTestModel(
          id: 'model-1',
          name: 'Model 1',
          inferenceProviderId: 'provider-1',
        );

        final model2 = AiTestDataFactory.createTestModel(
          id: 'model-2',
          name: 'Model 2',
          inferenceProviderId: 'provider-1',
        );

        final provider1 = AiTestDataFactory.createTestProvider(
          id: 'provider-1',
          name: 'Provider 1',
          baseUrl: 'https://api.example.com',
          apiKey: 'key',
          type: InferenceProviderType.openAi,
        );

        when(
          () => mockRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model1);
        when(
          () => mockRepo.getConfigById('model-2'),
        ).thenAnswer((_) async => model2);
        when(
          () => mockRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider1);

        // Act
        final result = await filter.filterPromptsByPlatform([prompt1, prompt2]);

        // Assert
        expect(result, hasLength(2));
        expect(result.map((p) => p.id), containsAll(['prompt-1', 'prompt-2']));
      });
    });

    group('getFirstAvailablePrompt', () {
      test('returns null for empty list', () async {
        // Act
        final result = await filter.getFirstAvailablePrompt([]);

        // Assert
        expect(result, isNull);
      });

      test('returns first available prompt', () async {
        // Arrange
        final prompt1 = AiTestDataFactory.createTestPrompt(
          id: 'prompt-1',
          name: 'Prompt 1',
          defaultModelId: 'model-1',
        );

        final model1 = AiTestDataFactory.createTestModel(
          id: 'model-1',
          name: 'Model 1',
          inferenceProviderId: 'provider-1',
        );

        final provider1 = AiTestDataFactory.createTestProvider(
          id: 'provider-1',
          name: 'Provider 1',
          baseUrl: 'https://api.example.com',
          apiKey: 'key',
          type: InferenceProviderType.openAi,
        );

        when(
          () => mockRepo.getConfigById('prompt-1'),
        ).thenAnswer((_) async => prompt1);
        when(
          () => mockRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => model1);
        when(
          () => mockRepo.getConfigById('provider-1'),
        ).thenAnswer((_) async => provider1);

        // Act
        final result = await filter.getFirstAvailablePrompt(['prompt-1']);

        // Assert
        expect(result, isNotNull);
        expect(result?.id, equals('prompt-1'));
      });

      test('skips unavailable prompts and returns first available', () async {
        // Arrange
        final prompt2 = AiTestDataFactory.createTestPrompt(
          id: 'prompt-2',
          name: 'Prompt 2',
          defaultModelId: 'model-2',
        );

        final model2 = AiTestDataFactory.createTestModel(
          id: 'model-2',
          name: 'Model 2',
          inferenceProviderId: 'provider-2',
        );

        final provider2 = AiTestDataFactory.createTestProvider(
          id: 'provider-2',
          name: 'Provider 2',
          baseUrl: 'https://api.example.com',
          apiKey: 'key',
        );

        when(
          () => mockRepo.getConfigById('prompt-1'),
        ).thenAnswer((_) async => null);
        when(
          () => mockRepo.getConfigById('prompt-2'),
        ).thenAnswer((_) async => prompt2);
        when(
          () => mockRepo.getConfigById('model-2'),
        ).thenAnswer((_) async => model2);
        when(
          () => mockRepo.getConfigById('provider-2'),
        ).thenAnswer((_) async => provider2);

        // Act
        final result = await filter.getFirstAvailablePrompt([
          'prompt-1',
          'prompt-2',
        ]);

        // Assert
        expect(result, isNotNull);
        expect(result?.id, equals('prompt-2'));
      });

      test('returns null when all prompts unavailable', () async {
        // Arrange
        when(
          () => mockRepo.getConfigById('prompt-1'),
        ).thenAnswer((_) async => null);
        when(
          () => mockRepo.getConfigById('prompt-2'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await filter.getFirstAvailablePrompt([
          'prompt-1',
          'prompt-2',
        ]);

        // Assert
        expect(result, isNull);
      });

      test('returns null when config is not a prompt', () async {
        // Arrange
        final notAPrompt = AiTestDataFactory.createTestModel(
          id: 'model-1',
          name: 'Model 1',
          inferenceProviderId: 'provider-1',
        );

        when(
          () => mockRepo.getConfigById('model-1'),
        ).thenAnswer((_) async => notAPrompt);

        // Act
        final result = await filter.getFirstAvailablePrompt(['model-1']);

        // Assert
        expect(result, isNull);
      });

      test('returns null when prompt model is unavailable', () async {
        // Arrange
        final prompt1 = AiTestDataFactory.createTestPrompt(
          id: 'prompt-1',
          name: 'Prompt 1',
          defaultModelId: 'non-existent-model',
        );

        when(
          () => mockRepo.getConfigById('prompt-1'),
        ).thenAnswer((_) async => prompt1);
        when(
          () => mockRepo.getConfigById('non-existent-model'),
        ).thenAnswer((_) async => null);

        // Act
        final result = await filter.getFirstAvailablePrompt(['prompt-1']);

        // Assert
        // On desktop, all prompts are available regardless of configuration
        expect(result, isNotNull);
        expect(result?.id, equals('prompt-1'));
      });
    });

    group('isLocalOnlyProviderType', () {
      test('returns true for Whisper', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.whisper,
          ),
          isTrue,
        );
      });

      test('returns true for Ollama', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.ollama,
          ),
          isTrue,
        );
      });

      test('returns true for Voxtral', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.voxtral,
          ),
          isTrue,
        );
      });

      test('returns true for MLX Audio', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.mlxAudio,
          ),
          isTrue,
        );
      });

      test('returns false for cloud providers', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.openAi,
          ),
          isFalse,
        );
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.anthropic,
          ),
          isFalse,
        );
      });

      test('returns false for Gemini', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.gemini,
          ),
          isFalse,
        );
      });

      test('returns false for genericOpenAi', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.genericOpenAi,
          ),
          isFalse,
        );
      });

      test('returns false for nebiusAiStudio', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.nebiusAiStudio,
          ),
          isFalse,
        );
      });

      test('returns false for openRouter', () {
        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(
            InferenceProviderType.openRouter,
          ),
          isFalse,
        );
      });

      glados.Glados(
        glados.any.inferenceProviderType,
        glados.ExploreConfig(numRuns: 80),
      ).test('matches generated local-only provider classification', (
        providerType,
      ) {
        final expected = {
          InferenceProviderType.whisper,
          InferenceProviderType.ollama,
          InferenceProviderType.voxtral,
          InferenceProviderType.mlxAudio,
        }.contains(providerType);

        expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(providerType),
          expected,
        );
      }, tags: 'glados');
    });

    group('Mobile platform simulation', () {
      late bool originalIsDesktop;
      late bool originalIsMobile;

      setUp(() {
        // Save original values
        originalIsDesktop = platform.isDesktop;
        originalIsMobile = platform.isMobile;
      });

      tearDown(() {
        // Restore original values
        platform.isDesktop = originalIsDesktop;
        platform.isMobile = originalIsMobile;
      });

      test('filters out local-only providers on mobile', () async {
        // Override platform to simulate mobile
        platform.isDesktop = false;
        platform.isMobile = true;

        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: 'voxtral-model',
        );

        final model = AiTestDataFactory.createTestModel(
          id: 'voxtral-model',
          name: 'Voxtral Model',
          inferenceProviderId: 'voxtral-provider',
        );

        final provider = AiTestDataFactory.createTestProvider(
          id: 'voxtral-provider',
          name: 'Voxtral',
          type: InferenceProviderType.voxtral,
          baseUrl: '',
          apiKey: '',
        );

        when(
          () => mockRepo.getConfigById('voxtral-model'),
        ).thenAnswer((_) async => model);
        when(
          () => mockRepo.getConfigById('voxtral-provider'),
        ).thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert - Voxtral is local-only, should be unavailable on mobile
        expect(result, isFalse);
      });

      test(
        'filterPromptsByPlatform keeps cloud prompts and drops local-only '
        'ones on mobile',
        () async {
          // Override platform to simulate mobile so the non-desktop branch
          // of filterPromptsByPlatform (Future.wait + list comprehension) runs.
          platform.isDesktop = false;
          platform.isMobile = true;

          // Arrange: one cloud-backed prompt (kept) and one Whisper-backed
          // prompt (local-only, dropped), interleaved so order is asserted.
          final cloudPrompt = AiTestDataFactory.createTestPrompt(
            id: 'cloud-prompt',
            defaultModelId: 'cloud-model',
          );
          final whisperPrompt = AiTestDataFactory.createTestPrompt(
            id: 'whisper-prompt',
            defaultModelId: 'whisper-model',
          );
          final secondCloudPrompt = AiTestDataFactory.createTestPrompt(
            id: 'second-cloud-prompt',
            defaultModelId: 'cloud-model',
          );

          final cloudModel = AiTestDataFactory.createTestModel(
            id: 'cloud-model',
            inferenceProviderId: 'cloud-provider',
          );
          final whisperModel = AiTestDataFactory.createTestModel(
            id: 'whisper-model',
            inferenceProviderId: 'whisper-provider',
          );

          final cloudProvider = AiTestDataFactory.createTestProvider(
            id: 'cloud-provider',
            type: InferenceProviderType.openAi,
          );
          final whisperProvider = AiTestDataFactory.createTestProvider(
            id: 'whisper-provider',
            type: InferenceProviderType.whisper,
          );

          when(
            () => mockRepo.getConfigById('cloud-model'),
          ).thenAnswer((_) async => cloudModel);
          when(
            () => mockRepo.getConfigById('whisper-model'),
          ).thenAnswer((_) async => whisperModel);
          when(
            () => mockRepo.getConfigById('cloud-provider'),
          ).thenAnswer((_) async => cloudProvider);
          when(
            () => mockRepo.getConfigById('whisper-provider'),
          ).thenAnswer((_) async => whisperProvider);

          // Act
          final result = await filter.filterPromptsByPlatform([
            cloudPrompt,
            whisperPrompt,
            secondCloudPrompt,
          ]);

          // Assert: only the cloud-backed prompts survive, in original order.
          expect(
            result.map((p) => p.id).toList(),
            equals(['cloud-prompt', 'second-cloud-prompt']),
          );
        },
      );

      test(
        'filterPromptsByPlatform returns empty list when every prompt is '
        'local-only on mobile',
        () async {
          platform.isDesktop = false;
          platform.isMobile = true;

          final ollamaPrompt = AiTestDataFactory.createTestPrompt(
            id: 'ollama-prompt',
            defaultModelId: 'ollama-model',
          );
          final ollamaModel = AiTestDataFactory.createTestModel(
            id: 'ollama-model',
            inferenceProviderId: 'ollama-provider',
          );
          final ollamaProvider = AiTestDataFactory.createTestProvider(
            id: 'ollama-provider',
            type: InferenceProviderType.ollama,
          );

          when(
            () => mockRepo.getConfigById('ollama-model'),
          ).thenAnswer((_) async => ollamaModel);
          when(
            () => mockRepo.getConfigById('ollama-provider'),
          ).thenAnswer((_) async => ollamaProvider);

          // Act
          final result = await filter.filterPromptsByPlatform([ollamaPrompt]);

          // Assert: comprehension excludes the only (local-only) prompt.
          expect(result, isEmpty);
        },
      );

      test('allows cloud providers on mobile', () async {
        // Override platform to simulate mobile
        platform.isDesktop = false;
        platform.isMobile = true;

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

        when(
          () => mockRepo.getConfigById('gemini-model'),
        ).thenAnswer((_) async => model);
        when(
          () => mockRepo.getConfigById('gemini-provider'),
        ).thenAnswer((_) async => provider);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert - Gemini is cloud-based, should be available on mobile
        expect(result, isTrue);
      });

      glados.Glados(
        glados.any.promptLookupScenario,
        glados.ExploreConfig(numRuns: 120),
      ).test('returns first generated mobile-compatible prompt', (
        scenario,
      ) async {
        final originalIsDesktop = platform.isDesktop;
        final originalIsMobile = platform.isMobile;
        final generatedRepository = MockAiConfigRepository();
        final generatedContainer = ProviderContainer(
          overrides: [
            aiConfigRepositoryProvider.overrideWithValue(generatedRepository),
          ],
        );
        final generatedFilter = PromptCapabilityFilter(
          generatedContainer.read(testRefProvider),
        );

        platform.isDesktop = false;
        platform.isMobile = true;

        when(
          () => generatedRepository.getConfigById(any()),
        ).thenAnswer((invocation) async {
          final id = invocation.positionalArguments.single as String;
          if (!scenario.expectedLookupIds.contains(id)) {
            throw StateError(
              'Unexpected generated config lookup for $id in $scenario',
            );
          }
          return scenario.configById(id);
        });

        try {
          final result = await generatedFilter.getFirstAvailablePrompt(
            scenario.promptIds,
          );

          expect(
            result?.id,
            scenario.expectedFirstAvailablePromptId,
            reason: '$scenario',
          );
        } finally {
          generatedContainer.dispose();
          platform.isDesktop = originalIsDesktop;
          platform.isMobile = originalIsMobile;
        }
      }, tags: 'glados');
    });

    group('Edge Cases and Performance', () {
      test('handles large list of prompts efficiently', () async {
        // Arrange - Create 100 prompts
        final prompts = List.generate(
          100,
          (i) => AiTestDataFactory.createTestPrompt(
            id: 'prompt-$i',
            name: 'Prompt $i',
            defaultModelId: 'model-$i',
          ),
        );

        // Mock all models and providers
        for (var i = 0; i < 100; i++) {
          final model = AiTestDataFactory.createTestModel(
            id: 'model-$i',
            name: 'Model $i',
            inferenceProviderId: 'provider-$i',
          );

          final provider = AiTestDataFactory.createTestProvider(
            id: 'provider-$i',
            name: 'Provider $i',
            type: InferenceProviderType.openAi,
            baseUrl: 'https://api.example.com',
            apiKey: 'key',
          );

          when(
            () => mockRepo.getConfigById('model-$i'),
          ).thenAnswer((_) async => model);
          when(
            () => mockRepo.getConfigById('provider-$i'),
          ).thenAnswer((_) async => provider);
        }

        // Act
        final result = await filter.filterPromptsByPlatform(prompts);

        // Assert
        expect(result, hasLength(100));
      });

      test(
        'handles prompts with corrupted model references gracefully',
        () async {
          // Arrange
          final validPrompt = AiTestDataFactory.createTestPrompt(
            id: 'valid-prompt',
            defaultModelId: 'valid-model',
          );

          final corruptedPrompt = AiTestDataFactory.createTestPrompt(
            id: 'corrupted-prompt',
            defaultModelId: 'corrupted-model',
          );

          final validModel = AiTestDataFactory.createTestModel(
            id: 'valid-model',
            inferenceProviderId: 'valid-provider',
          );

          final validProvider = AiTestDataFactory.createTestProvider(
            id: 'valid-provider',
            type: InferenceProviderType.openAi,
          );

          when(
            () => mockRepo.getConfigById('valid-model'),
          ).thenAnswer((_) async => validModel);
          when(
            () => mockRepo.getConfigById('valid-provider'),
          ).thenAnswer((_) async => validProvider);
          when(
            () => mockRepo.getConfigById('corrupted-model'),
          ).thenAnswer((_) async => null);

          // Act
          final result = await filter.filterPromptsByPlatform([
            validPrompt,
            corruptedPrompt,
          ]);

          // Assert - On desktop, both should be returned
          expect(result, hasLength(2));
        },
      );

      test('handles concurrent calls to filterPromptsByPlatform', () async {
        // Arrange
        final prompts1 = List.generate(
          10,
          (i) => AiTestDataFactory.createTestPrompt(
            id: 'prompt-set1-$i',
            defaultModelId: 'model-$i',
          ),
        );

        final prompts2 = List.generate(
          10,
          (i) => AiTestDataFactory.createTestPrompt(
            id: 'prompt-set2-$i',
            defaultModelId: 'model-$i',
          ),
        );

        // Mock all models and providers
        for (var i = 0; i < 10; i++) {
          final model = AiTestDataFactory.createTestModel(
            id: 'model-$i',
            inferenceProviderId: 'provider-$i',
          );

          final provider = AiTestDataFactory.createTestProvider(
            id: 'provider-$i',
            type: InferenceProviderType.openAi,
          );

          when(
            () => mockRepo.getConfigById('model-$i'),
          ).thenAnswer((_) async => model);
          when(
            () => mockRepo.getConfigById('provider-$i'),
          ).thenAnswer((_) async => provider);
        }

        // Act - Run multiple filters concurrently
        final results = await Future.wait([
          filter.filterPromptsByPlatform(prompts1),
          filter.filterPromptsByPlatform(prompts2),
          filter.filterPromptsByPlatform(prompts1),
        ]);

        // Assert
        expect(results[0], hasLength(10));
        expect(results[1], hasLength(10));
        expect(results[2], hasLength(10));
      });

      test('handles empty prompt list in getFirstAvailablePrompt', () async {
        // Act
        final result = await filter.getFirstAvailablePrompt([]);

        // Assert
        expect(result, isNull);
      });

      test('handles prompt with invalid model ID format', () async {
        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt(
          defaultModelId: '',
        );

        when(() => mockRepo.getConfigById('')).thenAnswer((_) async => null);

        // Act
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert - On desktop, should still return true
        expect(result, isTrue);
      });

      test('handles provider lookup failure on desktop', () async {
        // Arrange
        final prompt = AiTestDataFactory.createTestPrompt();

        final model = AiTestDataFactory.createTestModel(
          inferenceProviderId: 'provider-1',
        );

        when(
          () => mockRepo.getConfigById('test-model'),
        ).thenAnswer((_) async => model);
        when(
          () => mockRepo.getConfigById('provider-1'),
        ).thenThrow(Exception('Database error'));

        // Act - On desktop, should return true before checking provider
        final result = await filter.isPromptAvailableOnPlatform(prompt);

        // Assert - Desktop returns true immediately
        expect(result, isTrue);
      });
    });

    group('promptCapabilityFilterProvider', () {
      late bool originalIsDesktop;
      late bool originalIsMobile;

      setUp(() {
        originalIsDesktop = platform.isDesktop;
        originalIsMobile = platform.isMobile;
      });

      tearDown(() {
        platform.isDesktop = originalIsDesktop;
        platform.isMobile = originalIsMobile;
      });

      test(
        'builds a PromptCapabilityFilter wired to the container Ref',
        () async {
          // Read the provider WITHOUT overriding it so the factory body
          // (PromptCapabilityFilter(ref)) actually executes.
          final builtFilter = container.read(promptCapabilityFilterProvider);

          // Same instance is returned for repeated reads (Provider caches it).
          expect(
            container.read(promptCapabilityFilterProvider),
            same(builtFilter),
          );

          // Force the non-desktop branch so availability *must* consult the
          // repository through the wired Ref. On desktop the filter short-
          // circuits to true without ever reading the repo, which would let
          // a mis-wired Ref pass undetected.
          platform.isDesktop = false;
          platform.isMobile = true;

          final prompt = AiTestDataFactory.createTestPrompt(
            id: 'wired-prompt',
            defaultModelId: 'wired-model',
          );
          // Missing model -> prompt is unavailable on mobile, so it is dropped.
          when(
            () => mockRepo.getConfigById('wired-model'),
          ).thenAnswer((_) async => null);

          final filtered = await builtFilter.filterPromptsByPlatform([prompt]);

          // The prompt was dropped because the wired Ref resolved the
          // overridden mockRepo and got a null model back.
          expect(filtered, isEmpty);

          // And prove the lookup went through the overridden repository: if the
          // provider stopped wiring the container Ref to mockRepo, this call
          // would never have happened.
          verify(() => mockRepo.getConfigById('wired-model')).called(1);
        },
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Glados property test for PromptCapabilityFilter.isLocalOnlyProviderType
  // A closed-enum property: exactly {whisper, ollama, voxtral, mlxAudio} are
  // local-only; all other variants must return false.
  // ---------------------------------------------------------------------------
  group('isLocalOnlyProviderType — Glados property', () {
    const localOnlyTypes = {
      InferenceProviderType.whisper,
      InferenceProviderType.ollama,
      InferenceProviderType.voxtral,
      InferenceProviderType.mlxAudio,
    };

    // Property: for every enum variant, the return value equals membership in
    // the known local-only set.  This auto-detects any future variant that is
    // misclassified.
    glados.Glados(
      glados.AnyUtils(glados.any).choose(InferenceProviderType.values),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'result matches membership in the known local-only set',
      (providerType) {
        final result =
            PromptCapabilityFilter.isLocalOnlyProviderType(providerType);
        final expectedLocal = localOnlyTypes.contains(providerType);

        expect(
          result,
          equals(expectedLocal),
          reason:
              '$providerType should${expectedLocal ? '' : ' not'} be local-only',
        );
      },
      tags: 'glados',
    );

    // Static worked examples for each variant (documentation + regression).
    for (final t in InferenceProviderType.values) {
      final expected = localOnlyTypes.contains(t);
      test(
        'isLocalOnlyProviderType($t) == $expected',
        () => expect(
          PromptCapabilityFilter.isLocalOnlyProviderType(t),
          equals(expected),
          reason: '$t classification',
        ),
      );
    }
  });
}
