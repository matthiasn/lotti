import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';
import '../../../agents/test_utils.dart';

enum _GeneratedConfigTypeSlot {
  inferenceProvider,
  prompt,
  model,
  inferenceProfile,
  skill,
}

enum _GeneratedConfigBatchSlot {
  empty,
  provider,
  modelPair,
  profile,
  promptAndSkill,
  mixed,
}

AiConfigType _generatedConfigType(_GeneratedConfigTypeSlot slot) {
  return switch (slot) {
    _GeneratedConfigTypeSlot.inferenceProvider =>
      AiConfigType.inferenceProvider,
    _GeneratedConfigTypeSlot.prompt => AiConfigType.prompt,
    _GeneratedConfigTypeSlot.model => AiConfigType.model,
    _GeneratedConfigTypeSlot.inferenceProfile => AiConfigType.inferenceProfile,
    _GeneratedConfigTypeSlot.skill => AiConfigType.skill,
  };
}

List<AiConfig> _generatedConfigBatch(_GeneratedConfigBatchSlot slot) {
  final prompt = AiConfig.prompt(
    id: 'generated-prompt',
    name: 'Generated Prompt',
    systemMessage: 'System',
    userMessage: 'User',
    defaultModelId: 'generated-model-1',
    modelIds: const ['generated-model-1'],
    createdAt: DateTime(2024, 3, 15),
    useReasoning: false,
    requiredInputData: const [],
    aiResponseType: AiResponseType.promptGeneration,
  );
  final skill = AiConfig.skill(
    id: 'generated-skill',
    name: 'Generated Skill',
    createdAt: DateTime(2024, 3, 15),
    skillType: SkillType.promptGeneration,
    requiredInputModalities: const [Modality.text],
    systemInstructions: 'System',
    userInstructions: 'User',
  );

  return switch (slot) {
    _GeneratedConfigBatchSlot.empty => <AiConfig>[],
    _GeneratedConfigBatchSlot.provider => [
      testInferenceProvider(id: 'generated-provider'),
    ],
    _GeneratedConfigBatchSlot.modelPair => [
      testAiModel(id: 'generated-model-1'),
      testAiModel(
        id: 'generated-model-2',
        providerModelId: 'generated-provider-model',
      ),
    ],
    _GeneratedConfigBatchSlot.profile => [
      testInferenceProfile(id: 'generated-profile'),
    ],
    _GeneratedConfigBatchSlot.promptAndSkill => [prompt, skill],
    _GeneratedConfigBatchSlot.mixed => [
      testInferenceProvider(id: 'generated-provider'),
      testAiModel(id: 'generated-model-1'),
      testInferenceProfile(id: 'generated-profile'),
      prompt,
      skill,
    ],
  };
}

class _GeneratedConfigStreamScenario {
  const _GeneratedConfigStreamScenario({
    required this.typeSlot,
    required this.batchSlots,
  });

  final _GeneratedConfigTypeSlot typeSlot;
  final List<_GeneratedConfigBatchSlot> batchSlots;

  AiConfigType get configType => _generatedConfigType(typeSlot);

  Iterable<List<AiConfig>> get batches => batchSlots.map(_generatedConfigBatch);

  @override
  String toString() {
    return '_GeneratedConfigStreamScenario('
        'typeSlot: $typeSlot, batchSlots: $batchSlots)';
  }
}

extension _AnyGeneratedConfigStreamScenario on glados.Any {
  glados.Generator<_GeneratedConfigTypeSlot> get configTypeSlot =>
      glados.AnyUtils(this).choose(_GeneratedConfigTypeSlot.values);

  glados.Generator<_GeneratedConfigBatchSlot> get configBatchSlot =>
      glados.AnyUtils(this).choose(_GeneratedConfigBatchSlot.values);

  glados.Generator<_GeneratedConfigStreamScenario> get configStreamScenario =>
      glados.CombinableAny(this).combine2(
        configTypeSlot,
        glados.ListAnys(this).listWithLengthInRange(1, 25, configBatchSlot),
        (
          _GeneratedConfigTypeSlot typeSlot,
          List<_GeneratedConfigBatchSlot> batchSlots,
        ) => _GeneratedConfigStreamScenario(
          typeSlot: typeSlot,
          batchSlots: batchSlots,
        ),
      );
}

void main() {
  // Setup for all tests
  setUpAll(() {
    // Create a fallback AiConfig instance that Mocktail can use
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final fallbackConfig = AiConfig.inferenceProvider(
      id: 'fallback-id',
      baseUrl: 'https://fallback.example.com',
      apiKey: 'fallback-key',
      name: 'Fallback API',
      createdAt: testDate,
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    // Register fallback values for the types we'll be using with matchers
    registerFallbackValue(fallbackConfig);
    registerFallbackValue(const Stream<List<AiConfig>>.empty());
    registerFallbackValue(<AiConfig>[]);
    registerFallbackValue(const AsyncData<List<AiConfig>>(<AiConfig>[]));
    registerFallbackValue(const AsyncLoading<List<AiConfig>>());
    registerFallbackValue(
      AsyncError<List<AiConfig>>(
        Exception('fallback error'),
        StackTrace.empty,
      ),
    );
  });

  // Helper function to create a ProviderContainer with mocked dependencies
  ProviderContainer createContainer({
    List<Override> overrides = const [],
  }) {
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);
    return container;
  }

  // Helper to clean up stream subscriptions
  void Function()? subscription;

  tearDown(() {
    subscription?.call();
  });

  group('AiConfigByTypeController Tests', () {
    late MockAiConfigRepository mockRepository;
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final testApiConfig = AiConfig.inferenceProvider(
      id: 'test-id',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      name: 'Test API',
      createdAt: testDate,
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    setUp(() {
      mockRepository = MockAiConfigRepository();
    });

    test('should return configs of the specified type', () async {
      // Arrange
      final streamController = StreamController<List<AiConfig>>(sync: true);
      when(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).thenAnswer((_) => streamController.stream);

      final container = createContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Act & Assert
      subscription = container
          .listen(
            aiConfigByTypeControllerProvider(
              configType: AiConfigType.inferenceProvider,
            ),
            (_, _) {},
            fireImmediately: true,
          )
          .close;

      expect(
        container.read(
          aiConfigByTypeControllerProvider(
            configType: AiConfigType.inferenceProvider,
          ),
        ),
        const AsyncValue<List<AiConfig>>.loading(),
      );

      streamController.add([testApiConfig]);

      // Verify data state with the correct data
      final state = container.read(
        aiConfigByTypeControllerProvider(
          configType: AiConfigType.inferenceProvider,
        ),
      );
      expect(state.hasValue, isTrue);
      expect(state.value, [testApiConfig]);

      // Verify the repository method was called with the correct type
      verify(
        () => mockRepository.watchConfigsByType(AiConfigType.inferenceProvider),
      ).called(1);

      await streamController.close();
    });

    glados.Glados(
      glados.any.configStreamScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('passes generated config stream batches unchanged', (
      scenario,
    ) async {
      final generatedRepository = MockAiConfigRepository();
      final streamController = StreamController<List<AiConfig>>(sync: true);
      final generatedContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(generatedRepository),
        ],
      );

      when(
        () => generatedRepository.watchConfigsByType(scenario.configType),
      ).thenAnswer((_) => streamController.stream);

      final provider = aiConfigByTypeControllerProvider(
        configType: scenario.configType,
      );
      final generatedSubscription = generatedContainer.listen(
        provider,
        (_, _) {},
      );

      try {
        expect(
          generatedContainer.read(provider),
          const AsyncValue<List<AiConfig>>.loading(),
        );

        for (final batch in scenario.batches) {
          streamController.add(batch);

          final state = generatedContainer.read(provider);
          expect(state.hasValue, isTrue, reason: '$scenario');
          expect(
            state.value,
            equals(batch),
            reason: '$scenario',
          );
        }
      } finally {
        generatedSubscription.close();
        await streamController.close();
        generatedContainer.dispose();
      }

      verify(
        () => generatedRepository.watchConfigsByType(scenario.configType),
      ).called(1);
    });
  });

  group('aiConfigById Tests', () {
    late MockAiConfigRepository mockRepository;
    final testDate = DateTime(2024, 3, 15, 10, 30);
    final testApiConfig = AiConfig.inferenceProvider(
      id: 'test-id',
      baseUrl: 'https://api.example.com',
      apiKey: 'test-api-key',
      name: 'Test API',
      createdAt: testDate,
      inferenceProviderType: InferenceProviderType.genericOpenAi,
    );

    setUp(() {
      mockRepository = MockAiConfigRepository();
    });

    test('should return a config by ID', () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testApiConfig,
      );

      final container = createContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Act
      final result = await container.read(
        aiConfigByIdProvider('test-id').future,
      );

      // Assert
      expect(result, equals(testApiConfig));
      verify(() => mockRepository.getConfigById('test-id')).called(1);
    });

    test('should return null for non-existent ID', () async {
      // Arrange
      when(() => mockRepository.getConfigById('non-existent')).thenAnswer(
        (_) async => null,
      );

      final container = createContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockRepository),
        ],
      );

      // Act
      final result = await container.read(
        aiConfigByIdProvider('non-existent').future,
      );

      // Assert
      expect(result, isNull);
      verify(() => mockRepository.getConfigById('non-existent')).called(1);
    });
  });
}
