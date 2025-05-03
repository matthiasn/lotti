import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/inference_model_form_controller.dart';
import 'package:mocktail/mocktail.dart';

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

void main() {
  late MockAiConfigRepository mockRepository;
  late ProviderContainer container;
  const testProviderId = 'provider-123';

  final testConfig = AiConfig.model(
    id: 'test-id',
    name: 'Test Model',
    inferenceProviderId: testProviderId,
    createdAt: DateTime.now(),
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    description: 'Test description',
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

  group('InferenceModelFormController Tests', () {
    test('should load existing config in build when configId is provided',
        () async {
      // Arrange
      when(() => mockRepository.getConfigById('test-id')).thenAnswer(
        (_) async => testConfig,
      );

      // Act
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: 'test-id').notifier,
      );
      final formState = await container.read(
        inferenceModelFormControllerProvider(configId: 'test-id').future,
      );

      // Assert
      expect(formState, isA<InferenceModelFormState>());
      expect(controller.nameController.text, equals('Test Model'));
      expect(controller.descriptionController.text, equals('Test description'));
      expect(formState?.inferenceProviderId, equals(testProviderId));
      expect(formState?.inputModalities, equals([Modality.text]));
      expect(formState?.outputModalities, equals([Modality.text]));
      expect(formState?.isReasoningModel, isTrue);
      verify(() => mockRepository.getConfigById('test-id')).called(1);
    });

    test('should have empty form state when configId is null', () async {
      // Act
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      final formState = await container
          .read(inferenceModelFormControllerProvider(configId: null).future);

      // Assert
      expect(formState, isA<InferenceModelFormState>());
      expect(controller.nameController.text, isEmpty);
      expect(controller.descriptionController.text, isEmpty);
      expect(formState?.inferenceProviderId, isEmpty);
      expect(formState?.inputModalities, equals([Modality.text]));
      expect(formState?.outputModalities, equals([Modality.text]));
      expect(formState?.isReasoningModel, isFalse);
      verifyNever(() => mockRepository.getConfigById(any()));
    });

    test('should add a new configuration', () async {
      // Arrange
      when(() => mockRepository.saveConfig(any())).thenAnswer((_) async {});

      // Act
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
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
        inferenceModelFormControllerProvider(configId: 'test-id').notifier,
      );
      await container.read(
        inferenceModelFormControllerProvider(configId: 'test-id').future,
      );

      // Create an updated config
      final updatedConfig = AiConfig.model(
        id: 'test-id',
        name: 'Updated Model',
        inferenceProviderId: testProviderId,
        createdAt: DateTime.now(),
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text],
        isReasoningModel: false,
        description: 'Updated description',
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
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
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
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: 'test-id').notifier,
      );
      await container.read(
        inferenceModelFormControllerProvider(configId: 'test-id').future,
      );

      // Verify fields are populated
      expect(controller.nameController.text, isNotEmpty);
      expect(controller.descriptionController.text, isNotEmpty);

      // Act
      controller.reset();

      // Assert
      expect(controller.nameController.text, isEmpty);
      expect(controller.descriptionController.text, isEmpty);
    });

    test('should update form state when name is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceModelFormControllerProvider(configId: null).future);

      // Act
      controller.nameChanged('New Name');
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.name.value, equals('New Name'));
    });

    test('should update form state when description is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceModelFormControllerProvider(configId: null).future);

      // Act
      controller.descriptionChanged('New description');
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.description.value, equals('New description'));
    });

    test('should update form state when inferenceProviderId is changed',
        () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceModelFormControllerProvider(configId: null).future);

      // Act
      controller.inferenceProviderIdChanged('new-provider-id');
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.inferenceProviderId, equals('new-provider-id'));
    });

    test('should update form state when inputModalities is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceModelFormControllerProvider(configId: null).future);

      // Act
      controller.inputModalitiesChanged([Modality.text, Modality.image]);
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        formState?.inputModalities,
        equals([Modality.text, Modality.image]),
      );
    });

    test('should update form state when outputModalities is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceModelFormControllerProvider(configId: null).future);

      // Act
      controller.outputModalitiesChanged([Modality.text, Modality.audio]);
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(
        formState?.outputModalities,
        equals([Modality.text, Modality.audio]),
      );
    });

    test('should update form state when isReasoningModel is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container
          .read(inferenceModelFormControllerProvider(configId: null).future);

      // Act
      controller.isReasoningModelChanged(true);
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .valueOrNull;

      // Assert
      expect(formState?.isReasoningModel, isTrue);
    });
  });
}
