import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/helpers/automatic_image_analysis_trigger.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  late MockDomainLogger mockDomainLogger;
  late MockProfileAutomationService mockProfileAutomationService;
  late MockSkillInferenceRunner mockRunner;
  late MockTaskAgentService mockTaskAgentService;
  late MockWakeOrchestrator mockWakeOrchestrator;
  late ProviderContainer container;

  setUpAll(() {
    registerAllFallbackValues();
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
    mockTaskAgentService = MockTaskAgentService();
    mockWakeOrchestrator = MockWakeOrchestrator();

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

    when(
      () => mockTaskAgentService.getTaskAgentForTask(any()),
    ).thenAnswer((_) async => null);

    when(
      () => mockWakeOrchestrator.requestContentWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn(true);

    container = ProviderContainer(
      overrides: [
        profileAutomationServiceProvider.overrideWithValue(
          mockProfileAutomationService,
        ),
        skillInferenceRunnerProvider.overrideWithValue(mockRunner),
        taskAgentServiceProvider.overrideWithValue(mockTaskAgentService),
        wakeOrchestratorProvider.overrideWithValue(mockWakeOrchestrator),
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

    group('Task-agent nudge after analysis', () {
      const taskId = 'task-nudge';
      const imageEntryId = 'image-nudge';

      AutomationResult handledResult() =>
          AutomationResult(handled: true, skill: testSkill());

      void stubHandledRun(AutomationResult result) {
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
      }

      test(
        'wakes the task agent with imageAnalysisComplete once the analysis '
        'is stored',
        () async {
          final result = handledResult();
          stubHandledRun(result);
          when(
            () => mockTaskAgentService.getTaskAgentForTask(taskId),
          ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-nudge'));

          final trigger = container.read(automaticImageAnalysisTriggerProvider);
          await trigger.triggerAutomaticImageAnalysis(
            imageEntryId: imageEntryId,
            linkedTaskId: taskId,
          );

          verify(
            () => mockWakeOrchestrator.requestContentWake(
              agentId: 'agent-nudge',
              reason: 'imageAnalysisComplete',
              triggerTokens: {taskId, imageEntryId},
            ),
          ).called(1);
          verify(
            () => mockDomainLogger.log(
              LogDomain.ai,
              any<String>(that: contains('Nudged')),
              subDomain: 'nudgeTaskAgent',
            ),
          ).called(1);
        },
      );

      test(
        'logs the stale outcome when the orchestrator only marks the report '
        'stale instead of waking',
        () async {
          final result = handledResult();
          stubHandledRun(result);
          when(
            () => mockTaskAgentService.getTaskAgentForTask(taskId),
          ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-stale'));
          when(
            () => mockWakeOrchestrator.requestContentWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          ).thenReturn(false);

          final trigger = container.read(automaticImageAnalysisTriggerProvider);
          await trigger.triggerAutomaticImageAnalysis(
            imageEntryId: imageEntryId,
            linkedTaskId: taskId,
          );

          verify(
            () => mockDomainLogger.log(
              LogDomain.ai,
              any<String>(that: contains('Marked report stale')),
              subDomain: 'nudgeTaskAgent',
            ),
          ).called(1);
        },
      );

      test('skips the nudge silently when the task has no agent', () async {
        final result = handledResult();
        stubHandledRun(result);

        final trigger = container.read(automaticImageAnalysisTriggerProvider);
        await trigger.triggerAutomaticImageAnalysis(
          imageEntryId: imageEntryId,
          linkedTaskId: taskId,
        );

        verifyNever(
          () => mockWakeOrchestrator.requestContentWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        );
      });

      test(
        'does not nudge when the profile did not handle the image',
        () async {
          final trigger = container.read(automaticImageAnalysisTriggerProvider);
          await trigger.triggerAutomaticImageAnalysis(
            imageEntryId: imageEntryId,
            linkedTaskId: taskId,
          );

          verifyNever(() => mockTaskAgentService.getTaskAgentForTask(any()));
          verifyNever(
            () => mockWakeOrchestrator.requestContentWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          );
        },
      );

      test(
        'a nudge failure is logged but never aborts the analysis flow',
        () async {
          final result = handledResult();
          stubHandledRun(result);
          when(
            () => mockTaskAgentService.getTaskAgentForTask(taskId),
          ).thenThrow(Exception('agent lookup failed'));

          final trigger = container.read(automaticImageAnalysisTriggerProvider);
          await trigger.triggerAutomaticImageAnalysis(
            imageEntryId: imageEntryId,
            linkedTaskId: taskId,
          );

          verify(
            () => mockDomainLogger.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'nudgeTaskAgent',
            ),
          ).called(1);
          // The outer trigger path must not report a failure of its own.
          verifyNever(
            () => mockDomainLogger.error(
              LogDomain.ai,
              any<Object>(),
              stackTrace: any<StackTrace?>(named: 'stackTrace'),
              subDomain: 'triggerAutomaticImageAnalysis',
            ),
          );
        },
      );
    });
  });
}
