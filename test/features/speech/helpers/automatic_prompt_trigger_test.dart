import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  late MockLoggingService mockLoggingService;
  late MockProfileAutomationService mockProfileAutomationService;
  late MockSkillInferenceRunner mockRunner;
  late MockTaskAgentService mockTaskAgentService;
  late MockWakeOrchestrator mockWakeOrchestrator;
  late ProviderContainer container;

  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(AutomationResult.notHandled);
  });

  AudioRecorderState stoppedState({bool? enableSpeechRecognition}) {
    return AudioRecorderState(
      status: AudioRecorderStatus.stopped,
      enableSpeechRecognition: enableSpeechRecognition,
      vu: 0,
      dBFS: -60,
      progress: Duration.zero,
      showIndicator: false,
      modalVisible: false,
    );
  }

  AiConfigSkill testSkill() {
    return AiConfig.skill(
          id: 'skill-1',
          name: 'Profile Transcription',
          skillType: SkillType.transcription,
          requiredInputModalities: const [Modality.audio],
          systemInstructions: 'Transcribe.',
          userInstructions: 'Audio.',
          createdAt: DateTime(2024),
        )
        as AiConfigSkill;
  }

  setUp(() {
    mockLoggingService = MockLoggingService();
    mockProfileAutomationService = MockProfileAutomationService();
    mockRunner = MockSkillInferenceRunner();
    mockTaskAgentService = MockTaskAgentService();
    mockWakeOrchestrator = MockWakeOrchestrator();

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
      () => mockProfileAutomationService.tryTranscribe(
        taskId: any(named: 'taskId'),
        enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
      ),
    ).thenAnswer((_) async => AutomationResult.notHandled);

    when(
      () => mockTaskAgentService.getTaskAgentForTask(any()),
    ).thenAnswer((_) async => null);

    when(
      () => mockWakeOrchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn(null);

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

  tearDown(() {
    container.dispose();
    if (getIt.isRegistered<LoggingService>()) {
      getIt.unregister<LoggingService>();
    }
  });

  group('AutomaticPromptTrigger', () {
    test('logs and returns when no linkedTaskId', () async {
      final trigger = container.read(automaticPromptTriggerProvider);

      await trigger.triggerAutomaticPrompts(
        'entry-1',
        stoppedState(),
      );

      verify(
        () => mockLoggingService.captureEvent(
          any<String>(that: contains('No linked task')),
          domain: 'automatic_prompt_trigger',
          subDomain: 'triggerAutomaticPrompts',
        ),
      ).called(1);

      verifyNever(
        () => mockProfileAutomationService.tryTranscribe(
          taskId: any(named: 'taskId'),
          enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
        ),
      );
    });

    test('handles exception gracefully', () async {
      when(
        () => mockProfileAutomationService.tryTranscribe(
          taskId: any(named: 'taskId'),
          enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
        ),
      ).thenThrow(Exception('Service error'));

      final trigger = container.read(automaticPromptTriggerProvider);

      await trigger.triggerAutomaticPrompts(
        'entry-1',
        stoppedState(),
        linkedTaskId: 'task-1',
      );

      verify(
        () => mockLoggingService.captureException(
          any<dynamic>(),
          domain: 'automatic_prompt_trigger',
          subDomain: 'triggerAutomaticPrompts',
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
        ),
      ).called(1);
    });

    group('Profile-driven path', () {
      test('runs transcription when profile handles it', () async {
        const taskId = 'test-task';
        const entryId = 'test-entry';
        final skill = testSkill();

        final result = AutomationResult(handled: true, skill: skill);

        when(
          () => mockProfileAutomationService.tryTranscribe(
            taskId: taskId,
            enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
          ),
        ).thenAnswer((_) async => result);

        when(
          () => mockRunner.runTranscription(
            audioEntryId: entryId,
            automationResult: result,
            linkedTaskId: taskId,
          ),
        ).thenAnswer((_) async {});

        final trigger = container.read(automaticPromptTriggerProvider);

        await trigger.triggerAutomaticPrompts(
          entryId,
          stoppedState(),
          linkedTaskId: taskId,
        );

        verify(
          () => mockRunner.runTranscription(
            audioEntryId: entryId,
            automationResult: result,
            linkedTaskId: taskId,
          ),
        ).called(1);

        verify(
          () => mockLoggingService.captureEvent(
            any<String>(that: contains('Profile-driven transcription')),
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          ),
        ).called(1);
      });

      test('skips transcription when realtime transcript provided', () async {
        const taskId = 'test-task';
        const entryId = 'test-entry';
        final skill = testSkill();

        final result = AutomationResult(handled: true, skill: skill);

        when(
          () => mockProfileAutomationService.tryTranscribe(
            taskId: taskId,
            enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
          ),
        ).thenAnswer((_) async => result);

        final trigger = container.read(automaticPromptTriggerProvider);

        await trigger.triggerAutomaticPrompts(
          entryId,
          stoppedState(),
          linkedTaskId: taskId,
          realtimeTranscriptProvided: true,
        );

        // Should log that it was not handled due to realtime
        verify(
          () => mockLoggingService.captureEvent(
            any<String>(
              that: contains('realtimeProvided=true'),
            ),
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          ),
        ).called(1);

        verifyNever(
          () => mockRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        );
      });

      test('logs when profile does not handle transcription', () async {
        const taskId = 'test-task';
        const entryId = 'test-entry';

        when(
          () => mockProfileAutomationService.tryTranscribe(
            taskId: taskId,
            enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
          ),
        ).thenAnswer((_) async => AutomationResult.notHandled);

        final trigger = container.read(automaticPromptTriggerProvider);

        await trigger.triggerAutomaticPrompts(
          entryId,
          stoppedState(),
          linkedTaskId: taskId,
        );

        verify(
          () => mockLoggingService.captureEvent(
            any<String>(that: contains('did not handle transcription')),
            domain: 'automatic_prompt_trigger',
            subDomain: 'triggerAutomaticPrompts',
          ),
        ).called(1);

        verifyNever(
          () => mockRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        );
      });

      test('passes enableSpeechRecognition to automation service', () async {
        const taskId = 'test-task';

        final trigger = container.read(automaticPromptTriggerProvider);

        await trigger.triggerAutomaticPrompts(
          'entry-1',
          stoppedState(enableSpeechRecognition: false),
          linkedTaskId: taskId,
        );

        verify(
          () => mockProfileAutomationService.tryTranscribe(
            taskId: taskId,
            enableSpeechRecognition: false,
          ),
        ).called(1);
      });
    });

    group('agent nudge on transcription completion', () {
      test(
        'enqueues a manual wake after a successful profile-driven '
        'transcription so the user does not wait through the throttle',
        () async {
          const taskId = 'task-nudge';
          const entryId = 'entry-nudge';
          final skill = testSkill();
          final result = AutomationResult(handled: true, skill: skill);
          final agent = makeTestIdentity(agentId: 'agent-nudge');

          when(
            () => mockProfileAutomationService.tryTranscribe(
              taskId: taskId,
              enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
            ),
          ).thenAnswer((_) async => result);
          when(
            () => mockRunner.runTranscription(
              audioEntryId: entryId,
              automationResult: result,
              linkedTaskId: taskId,
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockTaskAgentService.getTaskAgentForTask(taskId),
          ).thenAnswer((_) async => agent);

          final trigger = container.read(automaticPromptTriggerProvider);

          await trigger.triggerAutomaticPrompts(
            entryId,
            stoppedState(),
            linkedTaskId: taskId,
          );

          verify(
            () => mockWakeOrchestrator.enqueueManualWake(
              agentId: 'agent-nudge',
              reason: 'transcriptionComplete',
              triggerTokens: {taskId, entryId},
            ),
          ).called(1);
        },
      );

      test(
        'still nudges the agent when the realtime transcript was already '
        'provided (cloud transcription is skipped, but the content is fresh)',
        () async {
          const taskId = 'task-rt';
          const entryId = 'entry-rt';
          final skill = testSkill();
          final result = AutomationResult(handled: true, skill: skill);
          final agent = makeTestIdentity(agentId: 'agent-rt');

          when(
            () => mockProfileAutomationService.tryTranscribe(
              taskId: taskId,
              enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
            ),
          ).thenAnswer((_) async => result);
          when(
            () => mockTaskAgentService.getTaskAgentForTask(taskId),
          ).thenAnswer((_) async => agent);

          final trigger = container.read(automaticPromptTriggerProvider);

          await trigger.triggerAutomaticPrompts(
            entryId,
            stoppedState(),
            linkedTaskId: taskId,
            realtimeTranscriptProvided: true,
          );

          verifyNever(
            () => mockRunner.runTranscription(
              audioEntryId: any(named: 'audioEntryId'),
              automationResult: any(named: 'automationResult'),
              linkedTaskId: any(named: 'linkedTaskId'),
            ),
          );
          verify(
            () => mockWakeOrchestrator.enqueueManualWake(
              agentId: 'agent-rt',
              reason: 'transcriptionComplete',
              triggerTokens: {taskId, entryId},
            ),
          ).called(1);
        },
      );

      test(
        'does not nudge when no task agent is registered for the task',
        () async {
          const taskId = 'task-orphan';
          const entryId = 'entry-orphan';
          final skill = testSkill();
          final result = AutomationResult(handled: true, skill: skill);

          when(
            () => mockProfileAutomationService.tryTranscribe(
              taskId: taskId,
              enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
            ),
          ).thenAnswer((_) async => result);
          when(
            () => mockRunner.runTranscription(
              audioEntryId: entryId,
              automationResult: result,
              linkedTaskId: taskId,
            ),
          ).thenAnswer((_) async {});
          when(
            () => mockTaskAgentService.getTaskAgentForTask(taskId),
          ).thenAnswer((_) async => null);

          final trigger = container.read(automaticPromptTriggerProvider);

          await trigger.triggerAutomaticPrompts(
            entryId,
            stoppedState(),
            linkedTaskId: taskId,
          );

          verifyNever(
            () => mockWakeOrchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          );
        },
      );

      test(
        'does not nudge when transcription was not handled by automation',
        () async {
          const taskId = 'task-skip';
          const entryId = 'entry-skip';

          when(
            () => mockProfileAutomationService.tryTranscribe(
              taskId: taskId,
              enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
            ),
          ).thenAnswer((_) async => AutomationResult.notHandled);

          final trigger = container.read(automaticPromptTriggerProvider);

          await trigger.triggerAutomaticPrompts(
            entryId,
            stoppedState(),
            linkedTaskId: taskId,
          );

          verifyNever(
            () => mockWakeOrchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          );
        },
      );
    });
  });
}
