import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/helpers/smart_task_summary_trigger.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/state/active_inference_controller.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/direct_task_summary_refresh_controller.dart';
import 'package:lotti/features/ai/state/latest_summary_controller.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockUpdateNotifications extends Mock implements UpdateNotifications {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockPromptCapabilityFilter extends Mock
    implements PromptCapabilityFilter {}

class MockDirectTaskSummaryRefreshController extends Mock
    implements DirectTaskSummaryRefreshController {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockCategoryRepository mockCategoryRepository;
  late MockPromptCapabilityFilter mockPromptCapabilityFilter;
  late MockDirectTaskSummaryRefreshController mockRefreshController;
  late MockUpdateNotifications mockUpdateNotifications;
  late ProviderContainer container;

  // Helper to create a test category with all required fields
  CategoryDefinition createTestCategory({
    required String id,
    required String name,
    Map<AiResponseType, List<String>>? automaticPrompts,
  }) {
    return CategoryDefinition(
      id: id,
      name: name,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
      vectorClock: null,
      color: '#FF0000',
      private: false,
      active: true,
      favorite: false,
      automaticPrompts: automaticPrompts,
    );
  }

  // Helper to create a test AI response entry (task summary)
  AiResponseEntry createTestAiResponseEntry({
    required String id,
    AiResponseType type = AiResponseType.taskSummary,
  }) {
    final now = DateTime(2024);
    return AiResponseEntry(
      meta: Metadata(
        id: id,
        createdAt: now,
        updatedAt: now,
        dateFrom: now,
        dateTo: now,
      ),
      data: AiResponseData(
        model: 'test-model',
        temperature: 0.7,
        systemMessage: 'test',
        prompt: 'test',
        promptId: 'test-prompt',
        thoughts: '',
        response: 'Test summary',
        type: type,
      ),
    );
  }

  // Helper to create an AiConfigPrompt for testing
  AiConfigPrompt createTestPrompt({
    required String id,
    AiResponseType aiResponseType = AiResponseType.taskSummary,
  }) {
    return AiConfigPrompt(
      id: id,
      name: 'Test Prompt',
      defaultModelId: 'test-model',
      modelIds: [],
      systemMessage: 'Test system message',
      userMessage: 'Test user message',
      requiredInputData: [],
      useReasoning: false,
      createdAt: DateTime(2024),
      aiResponseType: aiResponseType,
    );
  }

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockCategoryRepository = MockCategoryRepository();
    mockPromptCapabilityFilter = MockPromptCapabilityFilter();
    mockRefreshController = MockDirectTaskSummaryRefreshController();
    mockUpdateNotifications = MockUpdateNotifications();

    // Register mocks with GetIt
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
    getIt.registerSingleton<UpdateNotifications>(mockUpdateNotifications);

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Setup default mock behavior for UpdateNotifications
    when(() => mockUpdateNotifications.updateStream)
        .thenAnswer((_) => const Stream.empty());

    // Setup default mock behavior for logging
    when(() => mockLoggingService.captureEvent(
          any<String>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
        )).thenReturn(null);

    when(() => mockLoggingService.captureException(
          any<dynamic>(),
          domain: any<String>(named: 'domain'),
          subDomain: any<String>(named: 'subDomain'),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        )).thenReturn(null);

    // Setup default mock for refresh controller
    when(() => mockRefreshController.requestTaskSummaryRefresh(any()))
        .thenAnswer((_) async {});

    // Create container with overridden providers
    container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        promptCapabilityFilterProvider
            .overrideWithValue(mockPromptCapabilityFilter),
        directTaskSummaryRefreshControllerProvider
            .overrideWith(() => mockRefreshController),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    if (getIt.isRegistered<UpdateNotifications>()) {
      getIt.unregister<UpdateNotifications>();
    }
  });

  group('SmartTaskSummaryTrigger', () {
    test('does nothing when categoryId is null', () async {
      // Arrange
      const taskId = 'test-task';
      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: null,
      );

      // Assert - nothing should be called because categoryId is null
      verifyNever(() => mockCategoryRepository.getCategoryById(any()));

      testContainer.dispose();
    });

    test('requests refresh when summary exists', () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';

      final existingSummary = createTestAiResponseEntry(id: 'existing-summary');

      // Track refresh calls
      String? refreshedTaskId;
      final trackingController = _TrackingRefreshController(
        onRequestRefresh: (id) => refreshedTaskId = id,
      );

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => trackingController),
          // Summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => existingSummary,
          ),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert - should request refresh since summary exists
      expect(refreshedTaskId, equals(taskId));
      // Should NOT look up category since summary already exists
      verifyNever(() => mockCategoryRepository.getCategoryById(any()));

      testContainer.dispose();
    });

    test('schedules refresh when no summary but inference already running',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';

      // Track refresh calls
      String? refreshedTaskId;
      final trackingController = _TrackingRefreshController(
        onRequestRefresh: (id) => refreshedTaskId = id,
      );

      // Create active inference data to simulate running inference
      final activeInference = ActiveInferenceData(
        entityId: taskId,
        promptId: 'some-prompt',
        aiResponseType: AiResponseType.taskSummary,
      );

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => trackingController),
          // No summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
          // But inference IS running
          activeInferenceControllerProvider(
            entityId: taskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => _MockActiveInferenceController(activeInference)),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert - should schedule refresh instead of creating duplicate
      expect(refreshedTaskId, equals(taskId));
      // Should NOT look up category since we're deduping
      verifyNever(() => mockCategoryRepository.getCategoryById(any()));

      // Verify log message
      verify(() => mockLoggingService.captureEvent(
            'Task $taskId has inference running, scheduling 5-min update',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          )).called(1);

      testContainer.dispose();
    });

    test('does nothing when no summary and category has no automatic prompts',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        // ignore: avoid_redundant_argument_values
        automaticPrompts: null,
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
          // No summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(() => mockRefreshController.requestTaskSummaryRefresh(any()));

      testContainer.dispose();
    });

    test(
        'does nothing when no summary and category has no task summary prompts',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.imageAnalysis: ['image-prompt'],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
          // No summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(() => mockRefreshController.requestTaskSummaryRefresh(any()));

      testContainer.dispose();
    });

    test(
        'creates first summary when no summary exists and auto-summary enabled',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';
      const promptId = 'summary-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.taskSummary: [promptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]))
          .thenAnswer((_) async => createTestPrompt(id: promptId));

      // Track if inference was triggered
      var inferenceCalled = false;
      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
          // No summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
          // Track inference call
          triggerNewInferenceProvider.overrideWith((ref, arg) async {
            inferenceCalled = true;
          }),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert
      expect(inferenceCalled, isTrue);
      verifyNever(() => mockRefreshController.requestTaskSummaryRefresh(any()));

      testContainer.dispose();
    });

    test('logs warning when no prompts available for platform', () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';
      const promptId = 'summary-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.taskSummary: [promptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      // No available prompts for platform
      when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]))
          .thenAnswer((_) async => null);

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
          // No summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockLoggingService.captureEvent(
            'No available task summary prompts for current platform',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          )).called(1);

      testContainer.dispose();
    });

    test('handles exception during summary lookup gracefully', () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
          // Summary lookup throws
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => throw Exception('Database error'),
          ),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act - should not throw
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert - exception should be logged
      verify(() => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);

      testContainer.dispose();
    });

    test('handles missing category gracefully', () async {
      // Arrange
      const categoryId = 'non-existent-category';
      const taskId = 'test-task';

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => null);

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
          // No summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act - should not throw
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(() => mockRefreshController.requestTaskSummaryRefresh(any()));

      testContainer.dispose();
    });

    test('logs appropriate message when no summary and no auto-summary',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const taskId = 'test-task';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        // No automatic prompts
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider
              .overrideWith(() => mockRefreshController),
          // No summary exists
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Act
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockLoggingService.captureEvent(
            'No summary and no auto-summary configured for task $taskId, skipping',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          )).called(1);

      testContainer.dispose();
    });

    test(
        'multi-source dedupe: second trigger defers when first inference is running',
        () async {
      // This test simulates two different sources (e.g., image analysis + text save)
      // both trying to create the first task summary. When an inference is already
      // running, subsequent triggers should defer to 5-min countdown.
      const categoryId = 'test-category';
      const taskId = 'test-task';
      const promptId = 'summary-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.taskSummary: [promptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]))
          .thenAnswer((_) async => createTestPrompt(id: promptId));

      // Scenario: Inference IS already running (simulates first trigger completed)
      // Both second and third triggers should defer to refresh
      var refreshCallCount = 0;

      final activeInference = ActiveInferenceData(
        entityId: taskId,
        promptId: promptId,
        aiResponseType: AiResponseType.taskSummary,
      );

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          directTaskSummaryRefreshControllerProvider.overrideWith(
            () => _TrackingRefreshController(
              onRequestRefresh: (_) => refreshCallCount++,
            ),
          ),
          // No summary exists yet
          latestSummaryControllerProvider.overrideWithBuild(
            (ref, params) async => null,
          ),
          // Inference IS running (simulates first trigger already started it)
          activeInferenceControllerProvider(
            entityId: taskId,
            aiResponseType: AiResponseType.taskSummary,
          ).overrideWith(() => _MockActiveInferenceController(activeInference)),
        ],
      );

      final trigger = testContainer.read(smartTaskSummaryTriggerProvider);

      // Second trigger (simulates text save) - inference already running
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Third trigger (simulates another event) - still running
      await trigger.triggerTaskSummary(
        taskId: taskId,
        categoryId: categoryId,
      );

      // Assert: BOTH deferred to refresh (no new inference started)
      expect(refreshCallCount, equals(2));

      // Verify the log messages indicate deferred behavior
      verify(() => mockLoggingService.captureEvent(
            'Task $taskId has inference running, scheduling 5-min update',
            domain: 'smart_task_summary_trigger',
            subDomain: 'triggerTaskSummary',
          )).called(2);

      testContainer.dispose();
    });
  });
}

/// Mock refresh controller that tracks method calls
class _TrackingRefreshController extends DirectTaskSummaryRefreshController {
  _TrackingRefreshController({
    required this.onRequestRefresh,
  });

  final void Function(String taskId) onRequestRefresh;

  @override
  ScheduledRefreshState build() {
    return ScheduledRefreshState({});
  }

  @override
  Future<void> requestTaskSummaryRefresh(String taskId) async {
    onRequestRefresh(taskId);
  }
}

/// Mock active inference controller that returns a fixed value
class _MockActiveInferenceController extends ActiveInferenceController {
  _MockActiveInferenceController(this._value);
  final ActiveInferenceData? _value;

  @override
  ActiveInferenceData? build({
    required String entityId,
    required AiResponseType aiResponseType,
  }) {
    return _value;
  }
}
