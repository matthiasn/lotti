import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/helpers/prompt_capability_filter.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/repository/ai_config_repository.dart'
    show aiConfigRepositoryProvider;
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/unified_ai_controller.dart';
import 'package:lotti/features/categories/repository/categories_repository.dart'
    show categoryRepositoryProvider;
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

class MockPromptCapabilityFilter extends Mock
    implements PromptCapabilityFilter {}

void main() {
  late MockLoggingService mockLoggingService;
  late MockCategoryRepository mockCategoryRepository;
  late MockAiConfigRepository mockAiConfigRepository;
  late MockPromptCapabilityFilter mockPromptCapabilityFilter;
  late MockProfileAutomationService mockProfileAutomationService;
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
    mockProfileAutomationService = MockProfileAutomationService();

    // By default, profile automation returns not-handled so legacy path runs.
    when(
      () => mockProfileAutomationService.tryAnalyzeImage(
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => AutomationResult.notHandled);

    // Register mocks with GetIt
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

    // Setup default mock behavior for logging
    when(
      () => mockLoggingService.captureEvent(
        any<String>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockLoggingService.captureException(
        any<dynamic>(),
        domain: any<String>(named: 'domain'),
        subDomain: any<String>(named: 'subDomain'),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
      ),
    ).thenAnswer((_) async {});

    // Create container with overridden providers
    container = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
        aiConfigRepositoryProvider.overrideWithValue(mockAiConfigRepository),
        promptCapabilityFilterProvider.overrideWithValue(
          mockPromptCapabilityFilter,
        ),
        profileAutomationServiceProvider.overrideWithValue(
          mockProfileAutomationService,
        ),
        // Override the trigger provider to capture calls
        triggerNewInferenceProvider((
          entityId: '',
          promptId: '',
          linkedEntityId: null,
        )).overrideWith((ref) async {}),
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

        when(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).thenAnswer((_) async => category);

        when(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]),
        ).thenAnswer((_) async => createTestPrompt(id: promptId));

        // Create a new container that tracks inference calls
        var inferenceCalled = false;
        String? capturedEntityId;
        String? capturedPromptId;
        String? capturedLinkedEntityId;

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            promptCapabilityFilterProvider.overrideWithValue(
              mockPromptCapabilityFilter,
            ),
            profileAutomationServiceProvider.overrideWithValue(
              mockProfileAutomationService,
            ),
            triggerNewInferenceProvider((
              entityId: imageEntryId,
              promptId: promptId,
              linkedEntityId: linkedTaskId,
            )).overrideWith((ref) async {
              inferenceCalled = true;
              capturedEntityId = imageEntryId;
              capturedPromptId = promptId;
              capturedLinkedEntityId = linkedTaskId;
            }),
          ],
        );

        final trigger = testContainer.read(
          automaticImageAnalysisTriggerProvider,
        );

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

        verify(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).called(1);
        verify(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]),
        ).called(1);

        testContainer.dispose();
      },
    );

    test('does not trigger legacy path when categoryId is null', () async {
      // Arrange
      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act — no linkedTaskId, so profile path is skipped too.
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: null,
      );

      // Assert — legacy path not entered.
      verifyNever(() => mockCategoryRepository.getCategoryById(any()));
      verifyNever(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
      );
    });

    test(
      'tries profile-driven path when categoryId is null but task linked',
      () async {
        // Arrange — profile automation returns handled.
        final skill =
            AiConfig.skill(
                  id: 'skill-1',
                  name: 'Image Analysis',
                  skillType: SkillType.imageAnalysis,
                  requiredInputModalities: const [Modality.image],
                  systemInstructions: 'Analyze.',
                  userInstructions: 'Describe.',
                  createdAt: DateTime(2024),
                )
                as AiConfigSkill;

        final automationResult = AutomationResult(
          handled: true,
          skill: skill,
        );

        when(
          () => mockProfileAutomationService.tryAnalyzeImage(
            taskId: 'test-task',
          ),
        ).thenAnswer((_) async => automationResult);

        final mockRunner = MockSkillInferenceRunner();
        when(
          () => mockRunner.runImageAnalysis(
            imageEntryId: 'test-image',
            automationResult: automationResult,
            linkedTaskId: 'test-task',
          ),
        ).thenAnswer((_) async {});

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            promptCapabilityFilterProvider.overrideWithValue(
              mockPromptCapabilityFilter,
            ),
            profileAutomationServiceProvider.overrideWithValue(
              mockProfileAutomationService,
            ),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
          ],
        );

        final trigger = testContainer.read(
          automaticImageAnalysisTriggerProvider,
        );

        // Act — null categoryId but with linkedTaskId.
        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: 'test-image',
          categoryId: null,
          linkedTaskId: 'test-task',
        );

        // Assert — profile path ran, legacy path skipped.
        verify(
          () => mockRunner.runImageAnalysis(
            imageEntryId: 'test-image',
            automationResult: automationResult,
            linkedTaskId: 'test-task',
          ),
        ).called(1);
        verifyNever(() => mockCategoryRepository.getCategoryById(any()));

        testContainer.dispose();
      },
    );

    test('does not trigger when category has no automatic prompts', () async {
      // Arrange
      const categoryId = 'test-category';

      final category = createTestCategory(
        id: categoryId,
        name: 'Test Category',
        // ignore: avoid_redundant_argument_values
        automaticPrompts: null,
      );

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).called(1);
      verifyNever(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
      );
    });

    test(
      'does not trigger when category has empty image analysis prompts list',
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

        when(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).thenAnswer((_) async => category);

        final trigger = container.read(automaticImageAnalysisTriggerProvider);

        // Act
        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: 'test-image',
          categoryId: categoryId,
        );

        // Assert
        verify(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).called(1);
        verifyNever(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
        );
      },
    );

    test(
      'does not trigger when category has other prompts but no image analysis',
      () async {
        // Arrange
        const categoryId = 'test-category';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
          automaticPrompts: {
            // ignore: deprecated_member_use_from_same_package
            AiResponseType.taskSummary: ['summary-prompt'],
            AiResponseType.audioTranscription: ['transcription-prompt'],
          },
        );

        when(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).thenAnswer((_) async => category);

        final trigger = container.read(automaticImageAnalysisTriggerProvider);

        // Act
        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: 'test-image',
          categoryId: categoryId,
        );

        // Assert
        verify(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).called(1);
        verifyNever(
          () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
        );
      },
    );

    test('handles missing category gracefully', () async {
      // Arrange
      const categoryId = 'non-existent-category';

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => null);

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act - should not throw
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).called(1);
      verifyNever(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt(any()),
      );
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

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      when(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]),
      ).thenAnswer((_) async => null); // No available prompt

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert
      verify(
        () => mockLoggingService.captureEvent(
          'No available image analysis prompts for current platform',
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
        ),
      ).called(1);
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

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      when(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt([
          promptId1,
          promptId2,
        ]),
      ).thenAnswer((_) async => createTestPrompt(id: promptId1));

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert - verify it called with the full list, not just one
      verify(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt([
          promptId1,
          promptId2,
        ]),
      ).called(1);
    });

    test('handles exception during category lookup gracefully', () async {
      // Arrange
      const categoryId = 'test-category';

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenThrow(Exception('Database error'));

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      // Act - should not throw
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'test-image',
        categoryId: categoryId,
      );

      // Assert - exception should be logged
      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
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

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      when(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]),
      ).thenAnswer((_) async => createTestPrompt(id: promptId));

      // Create container that tracks inference calls
      var inferenceCalled = false;

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider.overrideWithValue(
            mockPromptCapabilityFilter,
          ),
          triggerNewInferenceProvider((
            entityId: imageEntryId,
            promptId: promptId,
            // Note: linkedEntityId is null
            linkedEntityId: null,
          )).overrideWith((ref) async {
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

    test('callback invocation triggers analysis with correct parameters', () async {
      // This test verifies the integration between image import and analysis trigger.
      // When createImageEntry's onCreated callback is invoked, it should trigger
      // automatic image analysis with the correct parameters.

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

      when(
        () => mockCategoryRepository.getCategoryById(categoryId),
      ).thenAnswer((_) async => category);

      when(
        () => mockPromptCapabilityFilter.getFirstAvailablePrompt([promptId]),
      ).thenAnswer((_) async => createTestPrompt(id: promptId));

      // Track the parameters passed to inference
      String? capturedEntityId;
      String? capturedPromptId;
      String? capturedLinkedId;

      final testContainer = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(mockCategoryRepository),
          promptCapabilityFilterProvider.overrideWithValue(
            mockPromptCapabilityFilter,
          ),
          profileAutomationServiceProvider.overrideWithValue(
            mockProfileAutomationService,
          ),
          triggerNewInferenceProvider((
            entityId: imageEntryId,
            promptId: promptId,
            linkedEntityId: linkedTaskId,
          )).overrideWith((ref) async {
            capturedEntityId = imageEntryId;
            capturedPromptId = promptId;
            capturedLinkedId = linkedTaskId;
          }),
        ],
      );

      final trigger = testContainer.read(automaticImageAnalysisTriggerProvider);

      // Simulate what happens when createImageEntry's onCreated callback is invoked
      // This is the same pattern used in createAnalysisCallback in image_import.dart
      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: imageEntryId,
        categoryId: categoryId,
        linkedTaskId: linkedTaskId,
      );

      // Verify the inference was called with correct parameters
      expect(capturedEntityId, equals(imageEntryId));
      expect(capturedPromptId, equals(promptId));
      expect(capturedLinkedId, equals(linkedTaskId));

      testContainer.dispose();
    });

    group('Profile-driven path', () {
      test('skips legacy path when profile handles image analysis', () async {
        const categoryId = 'test-category';
        const imageEntryId = 'test-image';
        const linkedTaskId = 'test-task';

        final mockAutomationService = MockProfileAutomationService();
        final mockRunner = MockSkillInferenceRunner();
        final skill =
            AiConfig.skill(
                  id: 'skill-vision',
                  name: 'Profile Vision',
                  skillType: SkillType.imageAnalysis,
                  requiredInputModalities: const [Modality.image],
                  systemInstructions: 'Analyze.',
                  userInstructions: 'Image.',
                  createdAt: DateTime(2024),
                )
                as AiConfigSkill;

        final automationResult = AutomationResult(
          handled: true,
          skill: skill,
        );

        when(
          () => mockAutomationService.tryAnalyzeImage(taskId: linkedTaskId),
        ).thenAnswer((_) async => automationResult);

        when(
          () => mockRunner.runImageAnalysis(
            imageEntryId: imageEntryId,
            automationResult: automationResult,
            linkedTaskId: linkedTaskId,
          ),
        ).thenAnswer((_) async {});

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            promptCapabilityFilterProvider.overrideWithValue(
              mockPromptCapabilityFilter,
            ),
            profileAutomationServiceProvider.overrideWithValue(
              mockAutomationService,
            ),
            skillInferenceRunnerProvider.overrideWithValue(mockRunner),
          ],
        );

        final trigger = testContainer.read(
          automaticImageAnalysisTriggerProvider,
        );

        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: imageEntryId,
          categoryId: categoryId,
          linkedTaskId: linkedTaskId,
        );

        // Profile path should have been used
        verify(
          () => mockRunner.runImageAnalysis(
            imageEntryId: imageEntryId,
            automationResult: automationResult,
            linkedTaskId: linkedTaskId,
          ),
        ).called(1);

        // Legacy category lookup should NOT have been called
        verifyNever(
          () => mockCategoryRepository.getCategoryById(any()),
        );

        verify(
          () => mockLoggingService.captureEvent(
            any<String>(that: contains('Profile-driven image analysis')),
            domain: 'automatic_image_analysis_trigger',
            subDomain: 'triggerAutomaticImageAnalysis',
          ),
        ).called(1);

        testContainer.dispose();
      });

      test('falls through to legacy when profile does not handle', () async {
        const categoryId = 'test-category';
        const imageEntryId = 'test-image';
        const linkedTaskId = 'test-task';

        final mockAutomationService = MockProfileAutomationService();

        when(
          () => mockAutomationService.tryAnalyzeImage(taskId: linkedTaskId),
        ).thenAnswer((_) async => AutomationResult.notHandled);

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
        );

        when(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).thenAnswer((_) async => category);

        final testContainer = ProviderContainer(
          overrides: [
            categoryRepositoryProvider.overrideWithValue(
              mockCategoryRepository,
            ),
            promptCapabilityFilterProvider.overrideWithValue(
              mockPromptCapabilityFilter,
            ),
            profileAutomationServiceProvider.overrideWithValue(
              mockAutomationService,
            ),
          ],
        );

        final trigger = testContainer.read(
          automaticImageAnalysisTriggerProvider,
        );

        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: imageEntryId,
          categoryId: categoryId,
          linkedTaskId: linkedTaskId,
        );

        // Should have fallen through to legacy path
        verify(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).called(1);

        testContainer.dispose();
      });

      test('skips profile path when no linkedTaskId', () async {
        const categoryId = 'test-category';
        const imageEntryId = 'test-image';

        final category = createTestCategory(
          id: categoryId,
          name: 'Test Category',
        );

        when(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).thenAnswer((_) async => category);

        final trigger = container.read(automaticImageAnalysisTriggerProvider);

        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: imageEntryId,
          categoryId: categoryId,
        );

        // Should go directly to legacy path
        verify(
          () => mockCategoryRepository.getCategoryById(categoryId),
        ).called(1);
      });
    });
  });
}
