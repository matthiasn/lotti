import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/repository/unified_ai_inference_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/settings/ai_config_by_type_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockUnifiedAiInferenceRepository extends Mock
    implements UnifiedAiInferenceRepository {}

class MockLoggingService extends Mock implements LoggingService {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class FakeAiConfigPrompt extends Fake implements AiConfigPrompt {}

void main() {
  late ProviderContainer container;
  final containersToDispose = <ProviderContainer>[];
  late MockUnifiedAiInferenceRepository mockRepository;
  late MockLoggingService mockLoggingService;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockCategoryRepository mockCategoryRepository;

  setUpAll(() {
    registerFallbackValue(FakeAiConfigPrompt());
    registerFallbackValue(InferenceStatus.idle);
    registerFallbackValue(<String, dynamic>{});
    registerFallbackValue(StackTrace.current);
  });

  setUp(() {
    mockRepository = MockUnifiedAiInferenceRepository();
    mockLoggingService = MockLoggingService();
    mockAiConfigRepository = MockAiConfigRepository();
    mockCategoryRepository = MockCategoryRepository();

    // Set up GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    if (getIt.isRegistered<AiConfigRepository>()) {
      getIt.unregister<AiConfigRepository>();
    }
    getIt.registerSingleton<AiConfigRepository>(mockAiConfigRepository);

    // Set up default mock behavior for AI config repository
    when(() => mockAiConfigRepository.watchConfigsByType(AiConfigType.prompt))
        .thenAnswer((_) => Stream.value([]));

    container = ProviderContainer(
      overrides: [
        unifiedAiInferenceRepositoryProvider.overrideWithValue(mockRepository),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
      ],
    );

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
    // Dispose all containers created during tests
    for (final c in containersToDispose) {
      c.dispose();
    }
    containersToDispose.clear();
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
      final stateUpdates = <String>[];

      // Override the aiConfigByIdProvider to return our test prompt
      final testContainer = ProviderContainer(
        overrides: [
          unifiedAiInferenceRepositoryProvider
              .overrideWithValue(mockRepository),
          aiConfigByIdProvider('prompt-1').overrideWith(
            (ref) => Future.value(promptConfig),
          ),
        ],
      );
      containersToDispose.add(testContainer);

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
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        // Simulate progress updates
        onStatusChange(InferenceStatus.running);
        statusChangeCount++;
        onProgress('Starting inference...');
        progressUpdates.add('Starting inference...');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        onProgress('Processing...');
        progressUpdates.add('Processing...');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        onProgress('Complete!');
        progressUpdates.add('Complete!');
        onStatusChange(InferenceStatus.idle);
        statusChangeCount++;
      });

      // Listen to the provider to capture state updates
      final subscription = testContainer.listen(
        unifiedAiControllerProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ),
        (previous, next) {
          stateUpdates.add(next);
        },
        fireImmediately: true,
      );

      // Trigger inference explicitly since it no longer runs automatically
      await testContainer.read(
        triggerNewInferenceProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ).future,
      );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify inference was called
      verify(
        () => mockRepository.runInference(
          entityId: 'test-entity',
          promptConfig: promptConfig,
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).called(1);

      // Verify progress updates
      expect(progressUpdates.length, 3);
      expect(progressUpdates, [
        'Starting inference...',
        'Processing...',
        'Complete!',
      ]);

      // Verify status changes
      expect(statusChangeCount, 2);

      // Verify state updates
      expect(stateUpdates.contains(''), true); // Initial state
      expect(stateUpdates.contains('Starting inference...'), true);
      expect(stateUpdates.contains('Processing...'), true);
      expect(stateUpdates.contains('Complete!'), true);

      // Clean up
      subscription.close();
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

      final stateUpdates = <String>[];

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

      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);
        onStatusChange(InferenceStatus.running);
        throw Exception('Test error');
      });

      // Listen to the provider to capture state updates
      final subscription = container.listen(
        unifiedAiControllerProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ),
        (previous, next) {
          stateUpdates.add(next);
        },
        fireImmediately: true,
      );

      // Trigger inference explicitly since it no longer runs automatically
      await container.read(
        triggerNewInferenceProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ).future,
      );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Verify error handling
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'UnifiedAiController',
          subDomain: 'runInference',
          stackTrace: any<dynamic>(named: 'stackTrace'),
        ),
      ).called(1);

      // Verify state updates - should contain error message
      expect(
          stateUpdates.any((s) => s.contains('error') || s.contains('Error')),
          true);

      // Clean up
      subscription.close();
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
          status: TaskStatus.inProgress(
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

      // Mock the AI config stream
      when(() => mockAiConfigRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value(expectedPrompts));

      when(
        () => mockRepository.getActivePromptsForContext(
          entity: taskEntity,
        ),
      ).thenAnswer((_) async => expectedPrompts);

      final prompts = await container.read(
        availablePromptsProvider(entity: taskEntity).future,
      );

      expect(prompts, expectedPrompts);
      verify(
        () => mockRepository.getActivePromptsForContext(
          entity: taskEntity,
        ),
      ).called(1);
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
          status: TaskStatus.inProgress(
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

      final availablePrompt = AiConfigPrompt(
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
      );

      // Mock the AI config stream
      when(() => mockAiConfigRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value([availablePrompt]));

      when(
        () => mockRepository.getActivePromptsForContext(
          entity: taskEntity,
        ),
      ).thenAnswer((_) async => [availablePrompt]);

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

      // Mock the AI config stream
      when(() => mockAiConfigRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value([]));

      when(
        () => mockRepository.getActivePromptsForContext(
          entity: journalEntry,
        ),
      ).thenAnswer((_) async => []);

      final hasPrompts = await container.read(
        hasAvailablePromptsProvider(entity: journalEntry).future,
      );

      expect(hasPrompts, false);
    });
  });

  group('triggerNewInference provider', () {
    test('triggers inference when called', () async {
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

      var runInferenceCallCount = 0;

      // Set up mock for runInference
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        runInferenceCallCount++;
      });

      // Trigger inference
      await container.read(
        triggerNewInferenceProvider(
          entityId: 'test-entity',
          promptId: 'prompt-1',
        ).future,
      );

      // Verify inference was called
      expect(runInferenceCallCount, 1);

      verify(
        () => mockRepository.runInference(
          entityId: 'test-entity',
          promptConfig: promptConfig,
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).called(1);
    });

    test('updates inference status for linked entity when provided', () async {
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
        aiResponseType: AiResponseType.audioTranscription,
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

      // Track status updates for both entities
      final mainEntityStatuses = <InferenceStatus>[];
      final linkedEntityStatuses = <InferenceStatus>[];

      // Listen to inference status for main entity
      container
        ..listen(
          inferenceStatusControllerProvider(
            id: 'audio-entry-id',
            aiResponseType: AiResponseType.audioTranscription,
          ),
          (previous, next) {
            mainEntityStatuses.add(next);
          },
          fireImmediately: true,
        )

        // Listen to inference status for linked entity
        ..listen(
          inferenceStatusControllerProvider(
            id: 'linked-task-id',
            aiResponseType: AiResponseType.audioTranscription,
          ),
          (previous, next) {
            linkedEntityStatuses.add(next);
          },
          fireImmediately: true,
        );

      // Set up mock for runInference
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        // Simulate status changes
        onStatusChange(InferenceStatus.running);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        onStatusChange(InferenceStatus.idle);
      });

      // Trigger inference with linkedEntityId
      await container.read(
        triggerNewInferenceProvider(
          entityId: 'audio-entry-id',
          promptId: 'prompt-1',
          linkedEntityId: 'linked-task-id',
        ).future,
      );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Both entities should have received the same status updates
      expect(mainEntityStatuses, contains(InferenceStatus.idle));
      expect(mainEntityStatuses, contains(InferenceStatus.running));
      expect(linkedEntityStatuses, contains(InferenceStatus.idle));
      expect(linkedEntityStatuses, contains(InferenceStatus.running));
    });

    test('updates error status for linked entity on failure', () async {
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
        aiResponseType: AiResponseType.audioTranscription,
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

      // Track status updates for both entities
      final mainEntityStatuses = <InferenceStatus>[];
      final linkedEntityStatuses = <InferenceStatus>[];

      // Listen to inference status for main entity
      container
        ..listen(
          inferenceStatusControllerProvider(
            id: 'audio-entry-id',
            aiResponseType: AiResponseType.audioTranscription,
          ),
          (previous, next) {
            mainEntityStatuses.add(next);
          },
          fireImmediately: true,
        )

        // Listen to inference status for linked entity
        // ignore_for_fi
        ..listen(
          inferenceStatusControllerProvider(
            id: 'linked-task-id',
            aiResponseType: AiResponseType.audioTranscription,
          ),
          (previous, next) {
            linkedEntityStatuses.add(next);
          },
          fireImmediately: true,
        );

      // Set up mock for runInference to fail
      when(
        () => mockRepository.runInference(
          entityId: any(named: 'entityId'),
          promptConfig: any(named: 'promptConfig'),
          onProgress: any(named: 'onProgress'),
          onStatusChange: any(named: 'onStatusChange'),
        ),
      ).thenAnswer((invocation) async {
        final onStatusChange = invocation.namedArguments[#onStatusChange]
            as void Function(InferenceStatus);

        // Simulate running status then error
        onStatusChange(InferenceStatus.running);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        throw Exception('Test error');
      });

      // Trigger inference with linkedEntityId
      await container.read(
        triggerNewInferenceProvider(
          entityId: 'audio-entry-id',
          promptId: 'prompt-1',
          linkedEntityId: 'linked-task-id',
        ).future,
      );

      // Wait for async operations
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Both entities should have error status
      expect(mainEntityStatuses, contains(InferenceStatus.running));
      expect(mainEntityStatuses, contains(InferenceStatus.error));
      expect(linkedEntityStatuses, contains(InferenceStatus.running));
      expect(linkedEntityStatuses, contains(InferenceStatus.error));
    });
  });

  group('categoryChanges provider', () {
    test('returns stream of category changes', () async {
      const categoryId = 'test-category';
      final categoryChangesStream = StreamController<CategoryDefinition>();

      final testCategory = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCategoryRepository.watchCategory(categoryId))
          .thenAnswer((_) => categoryChangesStream.stream);

      // Start listening to the provider
      final subscription = container.listen(
        categoryChangesProvider(categoryId),
        (previous, next) {},
      );

      // Verify watchCategory was called
      verify(() => mockCategoryRepository.watchCategory(categoryId)).called(1);

      // Emit a change
      categoryChangesStream.add(testCategory);

      // Clean up
      await categoryChangesStream.close();
      subscription.close();
    });
  });

  group('availablePrompts with category', () {
    test('watches for category changes when entity has categoryId', () async {
      const categoryId = 'test-category';
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          categoryId: categoryId, // Entity has a category
        ),
        data: TaskData(
          status: TaskStatus.inProgress(
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

      // Mock the AI config stream
      when(() => mockAiConfigRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value(expectedPrompts));

      // Mock category watching with an immediate value
      final testCategory = CategoryDefinition(
        id: categoryId,
        name: 'Test Category',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        vectorClock: null,
        private: false,
        active: true,
      );

      when(() => mockCategoryRepository.watchCategory(categoryId))
          .thenAnswer((_) => Stream.value(testCategory));

      when(() => mockRepository.getActivePromptsForContext(entity: taskEntity))
          .thenAnswer((_) async => expectedPrompts);

      // Track if categoryChangesProvider was accessed
      var categoryChangesProviderAccessed = false;
      container.listen(
        categoryChangesProvider(categoryId),
        (previous, next) {
          categoryChangesProviderAccessed = true;
        },
        fireImmediately: true,
      );

      // Read the provider
      final prompts = await container.read(
        availablePromptsProvider(entity: taskEntity).future,
      );

      expect(prompts, expectedPrompts);

      // Verify that categoryChangesProvider was accessed (which triggers category watching)
      expect(categoryChangesProviderAccessed, true);
      verify(() => mockCategoryRepository.watchCategory(categoryId)).called(1);
    });

    test('does not watch category when entity has no categoryId', () async {
      final taskEntity = Task(
        meta: Metadata(
          id: 'task-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          dateFrom: DateTime.now(),
          dateTo: DateTime.now(),
          // No categoryId
        ),
        data: TaskData(
          status: TaskStatus.inProgress(
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

      // Mock the AI config stream
      when(() => mockAiConfigRepository.watchConfigsByType(AiConfigType.prompt))
          .thenAnswer((_) => Stream.value(expectedPrompts));

      when(() => mockRepository.getActivePromptsForContext(entity: taskEntity))
          .thenAnswer((_) async => expectedPrompts);

      // Read the provider
      final prompts = await container.read(
        availablePromptsProvider(entity: taskEntity).future,
      );

      expect(prompts, expectedPrompts);

      // Verify that category watching was NOT triggered
      verifyNever(() => mockCategoryRepository.watchCategory(any()));
    });
  });
}
