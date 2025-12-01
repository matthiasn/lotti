import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

class MockLoggingService extends Mock implements LoggingService {}

class MockCategoryRepository extends Mock implements CategoryRepository {}

class MockAiConfigRepository extends Mock implements AiConfigRepository {}

class MockPromptCapabilityFilter extends Mock
    implements PromptCapabilityFilter {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockCategoryRepository mockCategoryRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockPromptCapabilityFilter mockPromptCapabilityFilter;
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

  // Helper to create an AiConfigPrompt for testing
  AiConfigPrompt createTestPrompt({
    required String id,
    AiResponseType aiResponseType = AiResponseType.imageAnalysis,
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
    mockAiConfigRepository = MockAiConfigRepository();
    mockPromptCapabilityFilter = MockPromptCapabilityFilter();

    // Register mocks with GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

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

    // Create container with overridden providers
    container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        promptCapabilityFilterProvider
            .overrideWithValue(mockPromptCapabilityFilter),
        // Override the trigger provider to capture calls
        triggerNewInferenceProvider(
          entityId: '',
          promptId: '',
        ).overrideWith((ref) async {}),
      ],
    );
  });

  tearDown(() {
    container.dispose();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  group('AutomaticImageAnalysisTrigger', () {
    test(
        'triggers image analysis when category has automatic prompts configured',
        () async {
      // Arrange
      const categoryId = 'test-category';
      const imageEntryId = 'test-image';
      const linkedTaskId = 'test-task';
      const promptId = 'image-analysis-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.imageAnalysis: [promptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]))
          .thenAnswer((_) async => createTestPrompt(id: promptId));

      // Create a new container that tracks inference calls
      var inferenceCalled = false;
      String? capturedEntityId;
      String? capturedPromptId;
      String? capturedLinkedEntityId;

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          triggerNewInferenceProvider(
            entityId: imageEntryId,
            promptId: promptId,
            linkedEntityId: linkedTaskId,
          ).overrideWith((ref) async {
            inferenceCalled = true;
            capturedEntityId = imageEntryId;
            capturedPromptId = promptId;
            capturedLinkedEntityId = linkedTaskId;
          }),
        ],
      );

      final trigger = testContainer.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: imageEntryId,
        categoryId: categoryId,
        linkedTaskId: linkedTaskId,
      );

      // Assert
      expect(inferenceCalled, isTrue);
      expect(capturedEntityId, equals(imageEntryId));
      expect(capturedPromptId, equals(promptId));
      expect(capturedLinkedEntityId, equals(linkedTaskId));

      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verify(() =>
              mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]))
          .called(1);

      testContainer.dispose();
    });

    test('does not trigger when categoryId is null', () async {
      // Arrange
      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: null,
      );

      // Assert
      verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      verifyNever(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()));
    });

    test('does not trigger when category has no automatic prompts', () async {
      // Arrange
      const categoryId = 'test-category';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        // ignore: avoid_redundant_argument_values
        automaticPrompts: null,
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()));
    });

    test('does not trigger when category has empty image analysis prompts list',
        () async {
      // Arrange
      const categoryId = 'test-category';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.imageAnalysis: [], // Empty list
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()));
    });

    test(
        'does not trigger when category has other prompts but no image analysis',
        () async {
      // Arrange
      const categoryId = 'test-category';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.taskSummary: ['summary-prompt'],
          AiResponseType.audioTranscription: ['transcription-prompt'],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()));
    });

    test('handles missing category gracefully', () async {
      // Arrange
      const categoryId = 'non-existent-category';

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => null);

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act - should not throw
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockCategoryRepository.getCategoryById(categoryId))
          .called(1);
      verifyNever(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()));
    });

    test('logs warning when no available prompts for platform', () async {
      // Arrange
      const categoryId = 'test-category';
      const promptId = 'image-analysis-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.imageAnalysis: [promptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]))
          .thenAnswer((_) async => null); // No available prompt

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(() => mockLoggingService.captureEvent(
            'No available image analysis prompts for current platform',
            domain: 'automatic_image_analysis_trigger',
            subDomain: 'triggerAutomaticImageAnalysis',
          )).called(1);
    });

    test('uses first available prompt from multiple prompts', () async {
      // Arrange
      const categoryId = 'test-category';
      const promptId1 = 'prompt-1';
      const promptId2 = 'prompt-2';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.imageAnalysis: [promptId1, promptId2],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      when(() => mockPromptCapabilityFilter
              .getFirstAvailablePrompt([promptId1, promptId2]))
          .thenAnswer((_) async => createTestPrompt(id: promptId1));

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert - verify it called with the full list, not just one
      verify(() => mockPromptCapabilityFilter
          .getFirstAvailablePrompt([promptId1, promptId2])).called(1);
    });

    test('handles exception during category lookup gracefully', () async {
      // Arrange
      const categoryId = 'test-category';

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenThrow(Exception('Database error'));

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act - should not throw
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert - exception should be logged
      verify(() => mockLoggingService.captureException(
            any<dynamic>(),
            domain: 'automatic_image_analysis_trigger',
            subDomain: 'triggerAutomaticImageAnalysis',
            stackTrace: any<StackTrace?>(named: 'stackTrace'),
          )).called(1);
    });

    test('works without linkedTaskId', () async {
      // Arrange
      const categoryId = 'test-category';
      const imageEntryId = 'test-image';
      const promptId = 'image-analysis-prompt';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        automaticPrompts: {
          AiResponseType.imageAnalysis: [promptId],
        },
      );

      when(() => mockCategoryRepository.getCategoryById(categoryId))
          .thenAnswer((_) async => category);

      when(() => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]))
          .thenAnswer((_) async => createTestPrompt(id: promptId));

      // Create container that tracks inference calls
      var inferenceCalled = false;

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider
              .overrideWithValue(mockPromptCapabilityFilter),
          triggerNewInferenceProvider(
            entityId: imageEntryId,
            promptId: promptId,
            // Note: linkedEntityId is null
          ).overrideWith((ref) async {
            inferenceCalled = true;
          }),
        ],
      );

      final trigger = testContainer.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: imageEntryId,
        categoryId: categoryId,
        // No linkedTaskId
      );

      // Assert
      expect(inferenceCalled, isTrue);

      testContainer.dispose();
    });
  });
}
