import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

import '../../../mocks/mocks.dart';

void main() {
  late MockLoggingService mockLoggingService;
  late MockProfileAutomationService mockProfileAutomationService;
  late MockSkillInferenceRunner mockRunner;
  late ProviderContainer container;

  setUpAll(() {
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
  });
}
