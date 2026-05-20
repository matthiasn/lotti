import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/inference_model_form_state.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/settings/inference_model_form_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../mocks/mocks.dart';

enum _GeneratedModelFormOperationKind {
  name,
  providerModelId,
  description,
  maxCompletionTokens,
  inferenceProviderId,
  inputModalities,
  outputModalities,
  isReasoningModel,
  supportsFunctionCalling,
}

enum _GeneratedModelFormTextSlot {
  empty,
  short,
  valid,
  other,
  numeric,
  invalidNumber,
}

enum _GeneratedModelFormModalitiesSlot {
  text,
  textImage,
  audioText,
  all,
  empty,
}

String _generatedModelFormText(_GeneratedModelFormTextSlot slot) {
  return switch (slot) {
    _GeneratedModelFormTextSlot.empty => '',
    _GeneratedModelFormTextSlot.short => 'xy',
    _GeneratedModelFormTextSlot.valid => 'Generated value',
    _GeneratedModelFormTextSlot.other => 'Other generated value',
    _GeneratedModelFormTextSlot.numeric => '4096',
    _GeneratedModelFormTextSlot.invalidNumber => '-3',
  };
}

List<Modality> _generatedModelFormModalities(
  _GeneratedModelFormModalitiesSlot slot,
) {
  return switch (slot) {
    _GeneratedModelFormModalitiesSlot.text => [Modality.text],
    _GeneratedModelFormModalitiesSlot.textImage => [
      Modality.text,
      Modality.image,
    ],
    _GeneratedModelFormModalitiesSlot.audioText => [
      Modality.audio,
      Modality.text,
    ],
    _GeneratedModelFormModalitiesSlot.all => [
      Modality.text,
      Modality.audio,
      Modality.image,
    ],
    _GeneratedModelFormModalitiesSlot.empty => <Modality>[],
  };
}

class _GeneratedModelFormOperation {
  const _GeneratedModelFormOperation({
    required this.kind,
    required this.textSlot,
    required this.modalitiesSlot,
    required this.flag,
  });

  final _GeneratedModelFormOperationKind kind;
  final _GeneratedModelFormTextSlot textSlot;
  final _GeneratedModelFormModalitiesSlot modalitiesSlot;
  final bool flag;

  String get text => _generatedModelFormText(textSlot);

  List<Modality> get modalities => _generatedModelFormModalities(
    modalitiesSlot,
  );

  @override
  String toString() {
    return '_GeneratedModelFormOperation('
        'kind: $kind, textSlot: $textSlot, '
        'modalitiesSlot: $modalitiesSlot, flag: $flag)';
  }
}

class _GeneratedModelFormScenario {
  const _GeneratedModelFormScenario({required this.operations});

  final List<_GeneratedModelFormOperation> operations;

  @override
  String toString() {
    return '_GeneratedModelFormScenario(operations: $operations)';
  }
}

class _ExpectedModelFormState {
  String name = '';
  String providerModelId = '';
  String description = '';
  String maxCompletionTokens = '';
  String inferenceProviderId = '';
  List<Modality> inputModalities = [Modality.text];
  List<Modality> outputModalities = [Modality.text];
  bool isReasoningModel = false;
  bool supportsFunctionCalling = false;

  void apply(_GeneratedModelFormOperation operation) {
    switch (operation.kind) {
      case _GeneratedModelFormOperationKind.name:
        name = operation.text;
      case _GeneratedModelFormOperationKind.providerModelId:
        providerModelId = operation.text;
      case _GeneratedModelFormOperationKind.description:
        description = operation.text;
      case _GeneratedModelFormOperationKind.maxCompletionTokens:
        maxCompletionTokens = operation.text;
      case _GeneratedModelFormOperationKind.inferenceProviderId:
        inferenceProviderId = operation.text;
      case _GeneratedModelFormOperationKind.inputModalities:
        inputModalities = operation.modalities;
      case _GeneratedModelFormOperationKind.outputModalities:
        outputModalities = operation.modalities;
      case _GeneratedModelFormOperationKind.isReasoningModel:
        isReasoningModel = operation.flag;
      case _GeneratedModelFormOperationKind.supportsFunctionCalling:
        supportsFunctionCalling = operation.flag;
    }
  }
}

extension _AnyGeneratedModelFormScenario on glados.Any {
  glados.Generator<_GeneratedModelFormOperationKind>
  get modelFormOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedModelFormOperationKind.values);

  glados.Generator<_GeneratedModelFormTextSlot> get modelFormTextSlot =>
      glados.AnyUtils(this).choose(_GeneratedModelFormTextSlot.values);

  glados.Generator<_GeneratedModelFormModalitiesSlot>
  get modelFormModalitiesSlot =>
      glados.AnyUtils(this).choose(_GeneratedModelFormModalitiesSlot.values);

  glados.Generator<_GeneratedModelFormOperation> get modelFormOperation =>
      glados.CombinableAny(this).combine4(
        modelFormOperationKind,
        modelFormTextSlot,
        modelFormModalitiesSlot,
        glados.any.bool,
        (
          _GeneratedModelFormOperationKind kind,
          _GeneratedModelFormTextSlot textSlot,
          _GeneratedModelFormModalitiesSlot modalitiesSlot,
          bool flag,
        ) => _GeneratedModelFormOperation(
          kind: kind,
          textSlot: textSlot,
          modalitiesSlot: modalitiesSlot,
          flag: flag,
        ),
      );

  glados.Generator<_GeneratedModelFormScenario> get modelFormScenario =>
      glados.ListAnys(this)
          .listWithLengthInRange(0, 45, modelFormOperation)
          .map(
            (operations) => _GeneratedModelFormScenario(
              operations: operations,
            ),
          );
}

void main() {
  late MockAiConfigRepository mockRepository;
  late ProviderContainer container;
  const testProviderId = 'provider-123';

  final testConfig = AiConfig.model(
    id: 'test-id',
    name: 'Test Model',
    providerModelId: 'test-provider-model-id',
    inferenceProviderId: testProviderId,
    createdAt: DateTime(2024, 3, 15, 10, 30),
    inputModalities: [Modality.text],
    outputModalities: [Modality.text],
    isReasoningModel: true,
    supportsFunctionCalling: true,
    description: 'Test description',
    maxCompletionTokens: 4000,
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
    test(
      'should load existing config in build when configId is provided',
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
        expect(
          controller.providerModelIdController.text,
          equals('test-provider-model-id'),
        );
        expect(
          controller.descriptionController.text,
          equals('Test description'),
        );
        expect(controller.maxCompletionTokensController.text, equals('4000'));
        expect(formState?.inferenceProviderId, equals(testProviderId));
        expect(formState?.inputModalities, equals([Modality.text]));
        expect(formState?.outputModalities, equals([Modality.text]));
        expect(formState?.isReasoningModel, isTrue);
        verify(() => mockRepository.getConfigById('test-id')).called(1);
      },
    );

    test('should have empty form state when configId is null', () async {
      // Act
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      final formState = await container.read(
        inferenceModelFormControllerProvider(configId: null).future,
      );

      // Assert
      expect(formState, isA<InferenceModelFormState>());
      expect(controller.nameController.text, isEmpty);
      expect(controller.providerModelIdController.text, isEmpty);
      expect(controller.descriptionController.text, isEmpty);
      expect(controller.maxCompletionTokensController.text, isEmpty);
      expect(formState?.inferenceProviderId, isEmpty);
      expect(formState?.inputModalities, equals([Modality.text]));
      expect(formState?.outputModalities, equals([Modality.text]));
      expect(formState?.isReasoningModel, isFalse);
      verifyNever(() => mockRepository.getConfigById(any()));
    });

    test(
      'should seed inferenceProviderId from preselectedProviderId in '
      'create mode — skips the otherwise-mandatory provider picker when '
      'the caller already has provider context (e.g. "Add Model" from a '
      'provider detail page). Repository must NOT be hit for create mode',
      () async {
        // Act
        final formState = await container.read(
          inferenceModelFormControllerProvider(
            configId: null,
            preselectedProviderId: 'provider-from-detail',
          ).future,
        );

        // Assert
        expect(formState?.inferenceProviderId, 'provider-from-detail');
        // Other fields stay blank — preselection is scoped to provider id.
        expect(formState?.name.value, isEmpty);
        expect(formState?.providerModelId.value, isEmpty);
        verifyNever(() => mockRepository.getConfigById(any()));
      },
    );

    test(
      'preselectedProviderId is ignored when configId is non-null — '
      'existing models carry their own inferenceProviderId, so a stray '
      'preselection arg should not silently rewrite it on the edit form',
      () async {
        when(() => mockRepository.getConfigById('test-id')).thenAnswer(
          (_) async => testConfig,
        );

        // Act
        final formState = await container.read(
          inferenceModelFormControllerProvider(
            configId: 'test-id',
            preselectedProviderId: 'overriding-id-should-be-ignored',
          ).future,
        );

        // Assert — form state reflects the stored model's provider id,
        // not the preselection arg.
        expect(formState?.inferenceProviderId, testProviderId);
        verify(() => mockRepository.getConfigById('test-id')).called(1);
      },
    );

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
        providerModelId: 'updated-provider-model-id',
        inferenceProviderId: testProviderId,
        createdAt: DateTime(2024, 3, 15, 10, 30),
        inputModalities: [Modality.text, Modality.image],
        outputModalities: [Modality.text],
        isReasoningModel: false,
        description: 'Updated description',
        maxCompletionTokens: 8000,
      );

      // Act
      await controller.updateConfig(updatedConfig);

      // Assert
      verify(() => mockRepository.saveConfig(any())).called(1);
    });

    test('should update form state when name is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceModelFormControllerProvider(configId: null).future,
      );

      // Act
      controller.nameChanged('New Name');
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.name.value, equals('New Name'));
    });

    test('should update form state when description is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceModelFormControllerProvider(configId: null).future,
      );

      // Act
      controller.descriptionChanged('New description');
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.description.value, equals('New description'));
    });

    test(
      'should update form state when maxCompletionTokens is changed',
      () async {
        // Arrange
        final controller = container.read(
          inferenceModelFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceModelFormControllerProvider(configId: null).future,
        );

        // Act
        controller.maxCompletionTokensChanged('2000');
        final formState = container
            .read(inferenceModelFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(formState?.maxCompletionTokens.value, equals('2000'));
      },
    );

    test(
      'should update form state when inferenceProviderId is changed',
      () async {
        // Arrange
        final controller = container.read(
          inferenceModelFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceModelFormControllerProvider(configId: null).future,
        );

        // Act
        controller.inferenceProviderIdChanged('new-provider-id');
        final formState = container
            .read(inferenceModelFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(formState?.inferenceProviderId, equals('new-provider-id'));
      },
    );

    test('should update form state when providerModelId is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceModelFormControllerProvider(configId: null).future,
      );

      // Act
      controller.providerModelIdChanged('new-provider-model-id');
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.providerModelId.value, equals('new-provider-model-id'));
    });

    test('should update form state when inputModalities is changed', () async {
      // Arrange
      final controller = container.read(
        inferenceModelFormControllerProvider(configId: null).notifier,
      );
      await container.read(
        inferenceModelFormControllerProvider(configId: null).future,
      );

      // Act
      controller.inputModalitiesChanged([Modality.text, Modality.image]);
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .value;

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
      await container.read(
        inferenceModelFormControllerProvider(configId: null).future,
      );

      // Act
      controller.outputModalitiesChanged([Modality.text, Modality.audio]);
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .value;

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
      await container.read(
        inferenceModelFormControllerProvider(configId: null).future,
      );

      // Act
      controller.isReasoningModelChanged(true);
      final formState = container
          .read(inferenceModelFormControllerProvider(configId: null))
          .value;

      // Assert
      expect(formState?.isReasoningModel, isTrue);
    });

    test(
      'should update form state when supportsFunctionCalling is changed',
      () async {
        // Arrange
        final controller = container.read(
          inferenceModelFormControllerProvider(configId: null).notifier,
        );
        await container.read(
          inferenceModelFormControllerProvider(configId: null).future,
        );

        // Act
        controller.supportsFunctionCallingChanged(true);
        final formState = container
            .read(inferenceModelFormControllerProvider(configId: null))
            .value;

        // Assert
        expect(formState?.supportsFunctionCalling, isTrue);
      },
    );

    glados.Glados(
      glados.any.modelFormScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated edit sequence semantics', (scenario) async {
      final generatedRepository = MockAiConfigRepository();
      final generatedContainer = ProviderContainer(
        overrides: [
          aiConfigRepositoryProvider.overrideWithValue(generatedRepository),
        ],
      );
      final expected = _ExpectedModelFormState();

      try {
        final controller = generatedContainer.read(
          inferenceModelFormControllerProvider(configId: null).notifier,
        );
        await generatedContainer.read(
          inferenceModelFormControllerProvider(configId: null).future,
        );

        for (final operation in scenario.operations) {
          switch (operation.kind) {
            case _GeneratedModelFormOperationKind.name:
              controller.nameChanged(operation.text);
            case _GeneratedModelFormOperationKind.providerModelId:
              controller.providerModelIdChanged(operation.text);
            case _GeneratedModelFormOperationKind.description:
              controller.descriptionChanged(operation.text);
            case _GeneratedModelFormOperationKind.maxCompletionTokens:
              controller.maxCompletionTokensChanged(operation.text);
            case _GeneratedModelFormOperationKind.inferenceProviderId:
              controller.inferenceProviderIdChanged(operation.text);
            case _GeneratedModelFormOperationKind.inputModalities:
              controller.inputModalitiesChanged(operation.modalities);
            case _GeneratedModelFormOperationKind.outputModalities:
              controller.outputModalitiesChanged(operation.modalities);
            case _GeneratedModelFormOperationKind.isReasoningModel:
              controller.isReasoningModelChanged(operation.flag);
            case _GeneratedModelFormOperationKind.supportsFunctionCalling:
              controller.supportsFunctionCallingChanged(operation.flag);
          }
          expected.apply(operation);

          final formState = generatedContainer
              .read(inferenceModelFormControllerProvider(configId: null))
              .value!;

          expect(formState.name.value, expected.name, reason: '$scenario');
          expect(controller.nameController.text, expected.name);
          expect(
            formState.providerModelId.value,
            expected.providerModelId,
            reason: '$scenario',
          );
          expect(
            controller.providerModelIdController.text,
            expected.providerModelId,
          );
          expect(
            formState.description.value,
            expected.description,
            reason: '$scenario',
          );
          expect(controller.descriptionController.text, expected.description);
          expect(
            formState.maxCompletionTokens.value,
            expected.maxCompletionTokens,
            reason: '$scenario',
          );
          expect(
            controller.maxCompletionTokensController.text,
            expected.maxCompletionTokens,
          );
          expect(
            formState.inferenceProviderId,
            expected.inferenceProviderId,
          );
          expect(formState.inputModalities, expected.inputModalities);
          expect(formState.outputModalities, expected.outputModalities);
          expect(formState.isReasoningModel, expected.isReasoningModel);
          expect(
            formState.supportsFunctionCalling,
            expected.supportsFunctionCalling,
          );
        }
      } finally {
        generatedContainer.dispose();
      }
    }, tags: 'glados');
  });
}
