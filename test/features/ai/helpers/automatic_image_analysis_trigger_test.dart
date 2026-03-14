import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

void main() {
  late MockLoggingService mockLoggingService;
  late MockProfileAutomationService mockProfileAutomationService;
  late MockSkillInferenceRunner mockRunner;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue(AutomationResult.notHandled);
  });

  AiConfigSkill testSkill() {
    return AiConfig.skill(
          id: 'skill-vision',
          name: 'Image Analysis',
          skillType: SkillType.imageAnalysis,
          requiredInputModalities: const [Modality.image],
          systemInstructions: 'Analyze.',
          userInstructions: 'Describe.',
          createdAt: DateTime(2024),
        )
        as AiConfigSkill;
  }

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockProfileAutomationService = MockProfileAutomationService();
    mockRunner = MockSkillInferenceRunner();

    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
    getIt.registerSingleton<LoggingService>(mockLoggingService);

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

    when(
      () => mockProfileAutomationService.tryAnalyzeImage(
        taskId: any(named: 'taskId'),
      ),
    ).thenAnswer((_) async => AutomationResult.notHandled);

    container = ProviderContainer(
      overrides: [
        profileAutomationServiceProvider.overrideWithValue(
          mockProfileAutomationService,
        ),
        skillInferenceRunnerProvider.overrideWithValue(mockRunner),
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
    test('logs and returns when no linkedTaskId', () async {
      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'image-1',
        categoryId: 'category-1',
      );

      verify(
        () => mockLoggingService.captureEvent(
          any<String>(that: contains('No linked task')),
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
        ),
      ).called(1);

      verifyNever(
        () => mockProfileAutomationService.tryAnalyzeImage(
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('logs and returns when no linkedTaskId and null categoryId', () async {
      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'image-1',
        categoryId: null,
      );

      verify(
        () => mockLoggingService.captureEvent(
          any<String>(that: contains('No linked task')),
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
        ),
      ).called(1);
    });

    test('handles exception gracefully', () async {
      when(
        () => mockProfileAutomationService.tryAnalyzeImage(
          taskId: any(named: 'taskId'),
        ),
      ).thenThrow(Exception('Service error'));

      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'image-1',
        categoryId: 'category-1',
        linkedTaskId: 'task-1',
      );

      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'automatic_image_analysis_trigger',
          subDomain: 'triggerAutomaticImageAnalysis',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    group('Profile-driven path', () {
      test('runs image analysis when profile handles it', () async {
        const taskId = 'test-task';
        const imageEntryId = 'test-image';
        final skill = testSkill();

        final result = AutomationResult(handled: true, skill: skill);

        when(
          () => mockProfileAutomationService.tryAnalyzeImage(taskId: taskId),
        ).thenAnswer((_) async => result);

        when(
          () => mockRunner.runImageAnalysis(
            imageEntryId: imageEntryId,
            automationResult: result,
            linkedTaskId: taskId,
          ),
        ).thenAnswer((_) async {});

        final trigger = container.read(automaticImageAnalysisTriggerProvider);

        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: imageEntryId,
          categoryId: 'category-1',
          linkedTaskId: taskId,
        );

        verify(
          () => mockRunner.runImageAnalysis(
            imageEntryId: imageEntryId,
            automationResult: result,
            linkedTaskId: taskId,
          ),
        ).called(1);

        verify(
          () => mockLoggingService.captureEvent(
            any<String>(that: contains('Profile-driven image analysis')),
            domain: 'automatic_image_analysis_trigger',
            subDomain: 'triggerAutomaticImageAnalysis',
          ),
        ).called(1);
      });

      test('logs when profile does not handle image analysis', () async {
        const taskId = 'test-task';
        const imageEntryId = 'test-image';

        when(
          () => mockProfileAutomationService.tryAnalyzeImage(taskId: taskId),
        ).thenAnswer((_) async => AutomationResult.notHandled);

        final trigger = container.read(automaticImageAnalysisTriggerProvider);

        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: imageEntryId,
          categoryId: 'category-1',
          linkedTaskId: taskId,
        );

        verify(
          () => mockLoggingService.captureEvent(
            any<String>(that: contains('did not handle image analysis')),
            domain: 'automatic_image_analysis_trigger',
            subDomain: 'triggerAutomaticImageAnalysis',
          ),
        ).called(1);

        verifyNever(
          () => mockRunner.runImageAnalysis(
            imageEntryId: any(named: 'imageEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        );
      });

      test('works with null categoryId when task linked', () async {
        const taskId = 'test-task';
        const imageEntryId = 'test-image';
        final skill = testSkill();

        final result = AutomationResult(handled: true, skill: skill);

        when(
          () => mockProfileAutomationService.tryAnalyzeImage(taskId: taskId),
        ).thenAnswer((_) async => result);

        when(
          () => mockRunner.runImageAnalysis(
            imageEntryId: imageEntryId,
            automationResult: result,
            linkedTaskId: taskId,
          ),
        ).thenAnswer((_) async {});

        final trigger = container.read(automaticImageAnalysisTriggerProvider);

        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: imageEntryId,
          categoryId: null,
          linkedTaskId: taskId,
        );

        verify(
          () => mockRunner.runImageAnalysis(
            imageEntryId: imageEntryId,
            automationResult: result,
            linkedTaskId: taskId,
          ),
        ).called(1);
      });
    });
  });
}
