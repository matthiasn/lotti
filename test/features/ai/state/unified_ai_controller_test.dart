import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  late ProviderContainer container;
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockLoggingService mockLoggingService;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockLoggingService();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    container = ProviderContainer(
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );

    // Mock logging methods
    when(() => mockLoggingService.captureEvent(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
        )).thenReturn(null);

    when(() => mockLoggingService.captureException(
          any(),
          domain: any(named: 'domain'),
          subDomain: any(named: 'subDomain'),
          stackTrace: any(named: 'stackTrace'),
        )).thenReturn(null);
  });

  tearDown(() {
    container.dispose();
  });

  group('UnifiedAiController', () {
    test('successfully runs inference and updates state', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      );

      final progressUpdates = <String>[];
      var statusChangeCount = 0;

      // Override the aiConfigByIdProvider to return our test prompt
      container = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider
              .overrideWithValue(mockRepository),
          aiConfigByIdProvider('prompt-1').overrideWith(
            (ref) => Future.value(promptConfig),
          ),
        ],
      );

      when(() => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
          )).thenAnswer((invocation) async {
        final onProgress =
            invocation.namedArguments[#onProgress] as void Function(String);
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        // Simulate progress updates
        onStatusChange(InferenceStatus.running);
        statusChangeCount++;
        onProgress('Starting inference...');
        progressUpdates.add('Starting inference...');
        await Future.delayed(const Duration(milliseconds: 10));
        onProgress('Processing...');
        progressUpdates.add('Processing...');
        await Future.delayed(const Duration(milliseconds: 10));
        onProgress('Complete!');
        progressUpdates.add('Complete!');
        onStatusChange(InferenceStatus.idle);
        statusChangeCount++;
      });

      // Create controller and read state to trigger build
      final initialState = container.read(
        unifiedAiControllerProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ),
      );
      expect(initialState, ''); // Initial state should be empty

      // Wait for async operations - need more time for the delayed runInference
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify inference was called
      verify(() => mockRepository.runInference(
            entityId: 'test-entity',
            promptConfig: promptConfig,
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
          )).called(1);

      // Verify progress updates
      expect(progressUpdates.length, 3);
      expect(progressUpdates, [
        'Starting inference...',
        'Processing...',
        'Complete!',
      ]);

      // Verify status changes
      expect(statusChangeCount, 2);

      // Verify final state
      final finalState = container.read(
        unifiedAiControllerProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ),
      );
      expect(finalState, 'Complete!');
    });

    test('handles errors during inference', () async {
      final promptConfig = AiConfigPrompt(
        id: 'prompt-1',
        name: 'Test Prompt',
        systemMessage: 'System',
        userMessage: 'User',
        defaultModelId: 'model-1',
        modelIds: ['model-1'],
        createdAt: DateTime.now(),
        useReasoning: false,
        requiredInputData: [InputDataType.task],
        aiResponseType: AiResponseType.taskSummary,
      );

      // Override the aiConfigByIdProvider to return our test prompt
      container = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider
              .overrideWithValue(mockRepository),
          aiConfigByIdProvider('prompt-1').overrideWith(
            (ref) => Future.value(promptConfig),
          ),
        ],
      );

      when(() => mockRepository.runInference(
            entityId: any(named: 'entityId'),
            promptConfig: any(named: 'promptConfig'),
            onProgress: any(named: 'onProgress'),
            onStatusChange: any(named: 'onStatusChange'),
          )).thenAnswer((invocation) async {
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);
        onStatusChange(InferenceStatus.running);
        throw Exception('Test error');
      });

      // Create controller and read state to trigger build
      final initialState = container.read(
        unifiedAiControllerProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ),
      );
      expect(initialState, ''); // Initial state should be empty

      // Wait for async operations - need more time for the delayed runInference
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify error handling
      verify(() => mockLoggingService.captureException(
            any(),
            domain: 'UnifiedAiController',
            subDomain: 'runInference',
            stackTrace: any(named: 'stackTrace'),
          )).called(1);

      // Verify final state contains error
      final state = container.read(
        unifiedAiControllerProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ),
      );
      expect(state, contains('Test error'));
    });
  });

  group('availablePrompts provider', () {
    test('returns available prompts for entity', () async {
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: TaskData(
          status: TaskStatus.started(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      final expectedPrompts = [
        AiConfigPrompt(
          id: 'prompt-1',
          name: 'Task Summary',
          systemMessage: 'System',
          userMessage: 'User',
          defaultModelId: 'model-1',
          modelIds: ['model-1'],
          createdAt: DateTime.now(),
          useReasoning: false,
          requiredInputData: [InputDataType.task],
          aiResponseType: AiResponseType.taskSummary,
        ),
      ];

      when(() => mockRepository.getActivePromptsForContext(
            entity: taskEntity,
          )).thenAnswer((_) async => expectedPrompts);

      final prompts = await container.read(
        availablePromptsProvider(entity: taskEntity).future,
      );

      expect(prompts, expectedPrompts);
      verify(() => mockRepository.getActivePromptsForContext(
            entity: taskEntity,
          )).called(1);
    });
  });

  group('hasAvailablePrompts provider', () {
    test('returns true when prompts are available', () async {
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
        data: TaskData(
          status: TaskStatus.started(
            id: 'status-1',
            createdAt: DateTime.now(),
            utcOffset: 0,
          ),
          title: 'Test Task',
          statusHistory: [],
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      when(() => mockRepository.getActivePromptsForContext(
            entity: taskEntity,
          )).thenAnswer((_) async => [
            AiConfigPrompt(
              id: 'prompt-1',
              name: 'Test',
              systemMessage: 'System',
              userMessage: 'User',
              defaultModelId: 'model-1',
              modelIds: ['model-1'],
              createdAt: DateTime.now(),
              useReasoning: false,
              requiredInputData: [],
              aiResponseType: AiResponseType.taskSummary,
            ),
          ]);

      final hasPrompts = await container.read(
        hasAvailablePromptsProvider(entity: taskEntity).future,
      );

      expect(hasPrompts, true);
    });

    test('returns false when no prompts are available', () async {
      final journalEntry = JournalEntry(
        meta: Metadata(
          id: 'entry-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
        ),
      );

      when(() => mockRepository.getActivePromptsForContext(
            entity: journalEntry,
          )).thenAnswer((_) async => []);

      final hasPrompts = await container.read(
        hasAvailablePromptsProvider(entity: journalEntry).future,
      );

      expect(hasPrompts, false);
    });
  });
}
