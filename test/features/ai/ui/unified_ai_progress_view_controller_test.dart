import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart' show setUpTestGetIt, tearDownTestGetIt;

void main() {
  late AiConfigPrompt testPromptConfig;
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockCloudInferenceRepository mockCloudRepository;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(InferenceStatus.idle);
  });

  setUp(() async {
    final now = DateTime(2024, 3, 15, 10);
    testPromptConfig =
        AiConfig.prompt(
              id: 'test-prompt-1',
              name: 'Test Prompt',
              systemMessage: 'You are a helpful assistant',
              userMessage: 'Please help with this task',
              defaultModelId: 'model-1',
              modelIds: ['model-1'],
              createdAt: now,
              useReasoning: false,
              requiredInputData: [InputDataType.task],
              // ignore: deprecated_member_use_from_same_package
              aiResponseType: AiResponseType.taskSummary,
              description: 'A test prompt for testing purposes',
            )
            as AiConfigPrompt;

    mockRepository = MockUnifiedAiInferenceRepository();
    mockCloudRepository = MockCloudInferenceRepository();

    // Registers core services (including a test-env DomainLogger) in GetIt.
    await setUpTestGetIt();
  });

  tearDown(tearDownTestGetIt);

  test('Controller state updates correctly during inference', () async {
    const testEntityId = 'test-entity-1';
    const testPromptId = 'test-prompt-1';

    final stateChanges = <String>[];
    final completer = Completer<void>();

    when(
      () => mockRepository.runInference(
        entityId: any(named: 'entityId'),
        promptConfig: any(named: 'promptConfig'),
        onProgress: any(named: 'onProgress'),
        onStatusChange: any(named: 'onStatusChange'),
      ),
    ).thenAnswer((invocation) async {
      final onProgress =
          invocation.namedArguments[#onProgress] as void Function(String);
      final onStatusChange =
          invocation.namedArguments[#onStatusChange]
              as void Function(InferenceStatus);

      // Simulate inference
      onStatusChange(InferenceStatus.running);
      await Future<void>.value();
      onProgress('Starting...');
      await Future<void>.value();
      onProgress('Complete!');
      onStatusChange(InferenceStatus.idle);
      completer.complete();
    });

    final container =
        ProviderContainer(
            overrides: [
              unifiedAiInferenceRepositoryProvider.overrideWithValue(
                mockRepository,
              ),
              cloudInferenceRepositoryProvider.overrideWithValue(
                mockCloudRepository,
              ),
              aiConfigByIdProvider(testPromptId).overrideWith(
                (ref) => Future.value(testPromptConfig),
              ),
            ],
          )
          // Listen to state changes
          ..listen(
            unifiedAiControllerProvider((
              entityId: testEntityId,
              promptId: testPromptId,
            )),
            (previous, next) {
              stateChanges.add(next.message);
            },
          );

    // Get initial state
    final initialState = container.read(
      unifiedAiControllerProvider((
        entityId: testEntityId,
        promptId: testPromptId,
      )),
    );
    expect(initialState.message, '');

    // Trigger inference
    await container.read(
      triggerNewInferenceProvider((
        entityId: testEntityId,
        promptId: testPromptId,
        linkedEntityId: null,
      )).future,
    );

    // Wait for completion
    await completer.future;

    // Get final state
    final finalState = container.read(
      unifiedAiControllerProvider((
        entityId: testEntityId,
        promptId: testPromptId,
      )),
    );

    // Verify state changes
    expect(stateChanges, contains('Starting...'));
    expect(stateChanges, contains('Complete!'));
    expect(finalState.message, 'Complete!');

    container.dispose();
  });
}
