import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/cloud_inference_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockCloudInferenceRepository extends Mock
    implements CloudInferenceRepository {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  late AiConfigPrompt testPromptConfig;
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockLoggingService mockLoggingService;
  late MockCloudInferenceRepository mockCloudRepository;

  setUpAll(() {
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(StackTrace.current);
    registerFallbackValue(FakeAiConfigPrompt());
  });

  setUp(() {
    final now = DateTime.now();
    testPromptConfig = AiConfig.prompt(
      id: 'test-prompt-1',
      name: 'Test Prompt',
      systemMessage: 'You are a helpful assistant',
      userMessage: 'Please help with this task',
      defaultModelId: 'model-1',
      modelIds: ['model-1'],
      createdAt: now,
      useReasoning: false,
      requiredInputData: [InputDataType.task],
      aiResponseType: AiResponseType.taskSummary,
      description: 'A test prompt for testing purposes',
    ) as AiConfigPrompt;

    mockRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockLoggingService();
    mockCloudRepository = MockCloudInferenceRepository();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Mock logging methods
    when(
      () => mockLoggingService.captureEvent(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any(named: 'domain'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any<dynamic>(named: 'stackTrace'),
      ),
    ).thenReturn(null);
  });

  tearDown(() {
    // Unregister LoggingService after each test to ensure a clean state
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

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
        useConversationApproach: any(named: 'useConversationApproach'),
      ),
    ).thenAnswer((invocation) async {
      final onProgress =
          invocation.namedArguments[#onProgress] as void Function(String);
      final onStatusChange = invocation.namedArguments[#onStatusChange] as void
          Function(InferenceStatus);

      // Simulate inference
      onStatusChange(InferenceStatus.running);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      onProgress('Starting...');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      onProgress('Complete!');
      onStatusChange(InferenceStatus.idle);
      completer.complete();
    });

    final container = ProviderContainer(
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
        cloudInferenceRepositoryProvider.overrideWithValue(mockCloudRepository),
        aiConfigByIdProvider(testPromptId).overrideWith(
          (ref) => Future.value(testPromptConfig),
        ),
      ],
    )

      // Listen to state changes
      ..listen(
        unifiedAiControllerProvider(
          entityId: testEntityId,
          promptId: testPromptId,
        ),
        (previous, next) {
          stateChanges.add(next);
        },
      );

    // Get initial state
    final initialState = container.read(
      unifiedAiControllerProvider(
        entityId: testEntityId,
        promptId: testPromptId,
      ),
    );
    expect(initialState, '');

    // Trigger inference
    await container.read(
      triggerNewInferenceProvider(
        entityId: testEntityId,
        promptId: testPromptId,
      ).future,
    );

    // Wait for completion
    await completer.future;

    // Get final state
    final finalState = container.read(
      unifiedAiControllerProvider(
        entityId: testEntityId,
        promptId: testPromptId,
      ),
    );

    // Verify state changes
    expect(stateChanges, contains('Starting...'));
    expect(stateChanges, contains('Complete!'));
    expect(finalState, 'Complete!');

    container.dispose();
  });
}
