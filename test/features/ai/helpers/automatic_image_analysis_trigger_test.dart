import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';

void main() {
  late MockDomainLogger mockDomainLogger;
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

  setUp(() async {
    mockDomainLogger = MockDomainLogger();
    mockProfileAutomationService = MockProfileAutomationService();
    mockRunner = MockSkillInferenceRunner();

    // setUpTestGetIt registers a real DomainLogger; swap in the mock so the
    // tests can verify log/error calls directly.
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(mockDomainLogger);
      },
    );

    when(
      () => mockDomainLogger.log(
        any<LogDomain>(),
        any<String>(),
        subDomain: any<String>(named: 'subDomain'),
      ),
    ).thenReturn(null);

    when(
      () => mockDomainLogger.error(
        any<LogDomain>(),
        any<Object>(),
        stackTrace: any<StackTrace?>(named: 'stackTrace'),
        subDomain: any<String>(named: 'subDomain'),
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

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  group('AutomaticImageAnalysisTrigger', () {
    test('logs and returns when no linkedTaskId', () async {
      final trigger = container.read(automaticImageAnalysisTriggerProvider);

      await trigger.triggerAutomaticImageAnalysis(
        imageEntryId: 'image-1',
      );

      verify(
        () => mockDomainLogger.log(
          LogDomain.ai,
          any<String>(that: contains('No linked task')),
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
      );

      verify(
        () => mockDomainLogger.log(
          LogDomain.ai,
          any<String>(that: contains('No linked task')),
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
        linkedTaskId: 'task-1',
      );

      verify(
        () => mockDomainLogger.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'triggerAutomaticImageAnalysis',
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
          () => mockDomainLogger.log(
            LogDomain.ai,
            any<String>(that: contains('Profile-driven image analysis')),
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
          linkedTaskId: taskId,
        );

        verify(
          () => mockDomainLogger.log(
            LogDomain.ai,
            any<String>(that: contains('did not handle image analysis')),
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
