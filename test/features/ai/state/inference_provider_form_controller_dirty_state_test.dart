import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/settings/inference_provider_form_controller.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class FakeAiConfigInferenceProvider extends Fake
    implements AiConfigInferenceProvider {}

void main() {
  late ProviderContainer container;
  late MockAiConfigRepository mockAiConfigRepository;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigInferenceProvider());
  });

  setUp(() {
    mockAiConfigRepository = MockAiConfigRepository();
    container = ProviderContainer(
      overrides: [
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('InferenceProviderFormController - Dirty State Tracking', () {
    const testConfigId = 'test-provider-id';
    final testConfig = AiConfigInferenceProvider(
      id: testConfigId,
      name: 'Test Provider',
      apiKey: 'test-api-key',
      baseUrl: 'https://api.test.com',
      description: 'Test Description',
      inferenceProviderType: InferenceProviderType.genericOpenAi,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test(
        'form should start with clean (non-dirty) state when loading existing config',
        () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      final state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;

      expect(state, isNotNull);
      expect(state!.isDirty, isFalse,
          reason: 'Form should not be dirty when initially loaded');
    });

    test('changing inferenceProviderType should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      final controller = container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change inferenceProviderType
      controller.inferenceProviderTypeChanged(InferenceProviderType.anthropic);

      // Should be dirty now
      state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing inferenceProviderType');
    });

    test('changing text fields should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      final controller = container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .notifier);

      // Test name field
      var state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      controller.nameChanged('Modified Provider Name');
      state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing name');

      // Reset for next test
      container.dispose();
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        ],
      );
      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      // Test API key field
      container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId)
              .notifier)
          .apiKeyChanged('modified-api-key');
      state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing apiKey');

      // Reset for next test
      container.dispose();
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        ],
      );
      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      // Test base URL field
      container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId)
              .notifier)
          .baseUrlChanged('https://modified.test.com');
      state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing baseUrl');
    });

    test('setting same value should not make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      final controller = container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Set same inferenceProviderType value
      controller.inferenceProviderTypeChanged(
          InferenceProviderType.genericOpenAi); // testConfig already has this

      // Should still be clean
      state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse,
          reason: 'Form should not be dirty when setting same value');
    });

    test(
        'changing provider type to predefined types should update fields and make form dirty',
        () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      final controller = container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change to Gemini - should update baseUrl
      controller.inferenceProviderTypeChanged(InferenceProviderType.gemini);

      state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing to Gemini');
      expect(state.baseUrl.value,
          'https://generativelanguage.googleapis.com/v1beta/openai');

      // Reset
      container.dispose();
      container = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        ],
      );

      // Test with empty name so it gets auto-populated
      final emptyNameConfig = testConfig.copyWith(name: '');
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => emptyNameConfig);

      await container.read(
          inferenceProviderFormControllerProvider(configId: testConfigId)
              .future);

      // Change to Nebius - should update both baseUrl and name
      container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId)
              .notifier)
          .inferenceProviderTypeChanged(InferenceProviderType.nebiusAiStudio);

      state = container
          .read(inferenceProviderFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing to Nebius');
      expect(state.baseUrl.value, 'https://api.studio.nebius.com/v1');
      expect(state.name.value, 'Nebius AI Studio');
    });
  });
}
