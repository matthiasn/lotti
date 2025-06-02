import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class FakeAiConfigModel extends Fake implements AiConfigModel {}

void main() {
  late ProviderContainer container;
  late MockAiConfigRepository mockAiConfigRepository;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigModel());
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

  group('InferenceModelFormController - Dirty State Tracking', () {
    const testConfigId = 'test-model-id';
    final testConfig = AiConfigModel(
      id: testConfigId,
      name: 'Test Model',
      providerModelId: 'test-provider-model',
      description: 'Test Description',
      inferenceProviderId: 'provider1',
      inputModalities: [Modality.text],
      outputModalities: [Modality.text],
      isReasoningModel: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    test(
        'form should start with clean (non-dirty) state when loading existing config',
        () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      final state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;

      expect(state, isNotNull);
      expect(state!.isDirty, isFalse,
          reason: 'Form should not be dirty when initially loaded');
    });

    test('changing inferenceProviderId should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      final controller = container.read(
          inferenceModelFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change inferenceProviderId
      controller.inferenceProviderIdChanged('provider2');

      // Should be dirty now
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing inferenceProviderId');
    });

    test('changing inputModalities should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      final controller = container.read(
          inferenceModelFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change inputModalities
      controller.inputModalitiesChanged([Modality.text, Modality.image]);

      // Should be dirty now
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing inputModalities');
    });

    test('changing outputModalities should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      final controller = container.read(
          inferenceModelFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change outputModalities
      controller.outputModalitiesChanged([Modality.text, Modality.image]);

      // Should be dirty now
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing outputModalities');
    });

    test('changing isReasoningModel should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      final controller = container.read(
          inferenceModelFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Change isReasoningModel
      controller.isReasoningModelChanged(false); // testConfig has true

      // Should be dirty now
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing isReasoningModel');
    });

    test('changing text fields should make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      final controller = container.read(
          inferenceModelFormControllerProvider(configId: testConfigId)
              .notifier);

      // Test name field
      var state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      controller.nameChanged('Modified Model Name');
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
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
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      // Test provider model ID field
      container
          .read(inferenceModelFormControllerProvider(configId: testConfigId)
              .notifier)
          .providerModelIdChanged('modified-provider-model');
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isTrue,
          reason: 'Form should be dirty after changing providerModelId');
    });

    test('setting same value should not make form dirty', () async {
      when(() => mockAiConfigRepository.getConfigById(testConfigId))
          .thenAnswer((_) async => testConfig);

      await container.read(
          inferenceModelFormControllerProvider(configId: testConfigId).future);

      final controller = container.read(
          inferenceModelFormControllerProvider(configId: testConfigId)
              .notifier);

      // Initially clean
      var state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse);

      // Set same isReasoningModel value
      controller.isReasoningModelChanged(true); // testConfig already has true

      // Should still be clean
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse,
          reason: 'Form should not be dirty when setting same value');

      // Set same inputModalities
      controller.inputModalitiesChanged(
          [Modality.text]); // testConfig already has [Modality.text]

      // Should still be clean
      state = container
          .read(inferenceModelFormControllerProvider(configId: testConfigId))
          .value;
      expect(state!.isDirty, isFalse,
          reason: 'Form should not be dirty when setting same modalities');
    });
  });
}
