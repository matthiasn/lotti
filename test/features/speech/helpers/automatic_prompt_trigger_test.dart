import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/service/subject_agent_lookup.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/services/skill_inference_runner.dart';
import 'package:lotti/features/ai/skills/built_in_skills.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/ai/state/inference_error_controller.dart';
import 'package:lotti/features/ai/state/inference_status_controller.dart';
import 'package:lotti/features/ai/state/profile_automation_providers.dart';
import 'package:lotti/features/ai/state/skill_trigger_providers.dart';
import 'package:lotti/features/speech/helpers/automatic_prompt_trigger.dart';
import 'package:lotti/features/speech/state/recorder_state.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/l10n/app_localizations_en.dart';
import 'package:lotti/providers/service_providers.dart' show journalDbProvider;
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../../widget_test_utils.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  late MockDomainLogger mockDomainLogger;
  late MockProfileAutomationService mockProfileAutomationService;
  late MockSkillInferenceRunner mockRunner;
  late MockJournalDb mockJournalDb;
  late MockSubjectAgentResolver mockSubjectAgentResolver;
  late MockWakeOrchestrator mockWakeOrchestrator;
  late ProviderContainer container;
  late List<TriggerSkillParams> skillTriggers;

  const entryId = 'entry-1';

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

  /// Makes [subjectId] resolve to an entity of the given kind, and makes
  /// transcription succeed for it. Returns the handled result so callers can
  /// assert on what was forwarded to the runner.
  Future<AutomationResult> stubHandledTranscription(
    String subjectId, {
    JournalEntity? entity,
  }) async {
    final result = AutomationResult(handled: true, skill: testSkill());
    when(
      () => mockProfileAutomationService.tryTranscribe(
        subjectId: subjectId,
        enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
      ),
    ).thenAnswer((_) async => result);
    when(
      () => mockJournalDb.journalEntityById(subjectId),
    ).thenAnswer((_) async => entity);
    when(
      () => mockRunner.runTranscription(
        audioEntryId: any(named: 'audioEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    ).thenAnswer((_) async {});
    return result;
  }

  setUp(() async {
    mockDomainLogger = MockDomainLogger();
    mockProfileAutomationService = MockProfileAutomationService();
    mockRunner = MockSkillInferenceRunner();
    mockJournalDb = MockJournalDb();
    mockSubjectAgentResolver = MockSubjectAgentResolver();
    when(
      () => mockSubjectAgentResolver(any<String>()),
    ).thenAnswer((_) async => null);
    mockWakeOrchestrator = MockWakeOrchestrator();
    skillTriggers = [];

    // The trigger resolves `getIt<DomainLogger>()`; swap the real logger
    // registered by setUpTestGetIt for the mock so log/error calls can be
    // verified. tearDownTestGetIt resets GetIt afterwards.
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
      () => mockProfileAutomationService.tryTranscribe(
        subjectId: any(named: 'subjectId'),
        enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
      ),
    ).thenAnswer((_) async => AutomationResult.notHandled);

    when(
      () => mockJournalDb.journalEntityById(any<String>()),
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
        journalDbProvider.overrideWithValue(mockJournalDb),
        subjectAgentResolverProvider.overrideWithValue(
          mockSubjectAgentResolver,
        ),
        wakeOrchestratorProvider.overrideWithValue(mockWakeOrchestrator),
        triggerSkillProvider.overrideWith((ref, params) async {
          skillTriggers.add(params);
        }),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestGetIt();
  });

  AutomaticPromptTrigger trigger() =>
      container.read(automaticPromptTriggerProvider);

  group('no linked subject', () {
    test('logs and never asks automation to transcribe', () async {
      await trigger().triggerAutomaticPrompts(entryId, stoppedState());

      verify(
        () => mockDomainLogger.log(
          LogDomain.ai,
          any<String>(that: contains('No linked subject')),
          subDomain: 'triggerAutomaticPrompts',
        ),
      ).called(1);
      verifyNever(
        () => mockProfileAutomationService.tryTranscribe(
          subjectId: any(named: 'subjectId'),
          enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
        ),
      );
    });
  });

  group('automation gate', () {
    test('runs the transcription skill when the profile handles it', () async {
      const subjectId = 'task-1';
      final result = await stubHandledTranscription(
        subjectId,
        entity: testTask,
      );

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockRunner.runTranscription(
          audioEntryId: entryId,
          automationResult: result,
          linkedTaskId: any(named: 'linkedTaskId'),
        ),
      ).called(1);
      verify(
        () => mockDomainLogger.log(
          LogDomain.ai,
          any<String>(that: contains('Profile-driven transcription')),
          subDomain: 'triggerAutomaticPrompts',
        ),
      ).called(1);
    });

    test('does not run the skill when the profile declines', () async {
      const subjectId = 'task-declined';
      when(
        () => mockProfileAutomationService.tryTranscribe(
          subjectId: subjectId,
          enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
        ),
      ).thenAnswer((_) async => AutomationResult.notHandled);

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockDomainLogger.log(
          LogDomain.ai,
          any<String>(that: contains('did not handle transcription')),
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

    test('forwards the per-recording speech opt-out verbatim', () async {
      const subjectId = 'task-optout';

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(enableSpeechRecognition: false),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockProfileAutomationService.tryTranscribe(
          subjectId: subjectId,
          enableSpeechRecognition: false,
        ),
      ).called(1);
    });

    test('logs and swallows a throwing automation service', () async {
      when(
        () => mockProfileAutomationService.tryTranscribe(
          subjectId: any(named: 'subjectId'),
          enableSpeechRecognition: any(named: 'enableSpeechRecognition'),
        ),
      ).thenThrow(Exception('Service error'));

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: 'task-1',
      );

      verify(
        () => mockDomainLogger.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'triggerAutomaticPrompts',
        ),
      ).called(1);
    });
  });

  // The task context and the consumption record's `taskId` share one
  // parameter, so a non-task subject must not be smuggled through it.
  group('task context is withheld from non-task subjects', () {
    test('a task subject passes its own id as the task context', () async {
      const subjectId = 'task-ctx';
      final result = await stubHandledTranscription(
        subjectId,
        entity: testTask,
      );

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockRunner.runTranscription(
          audioEntryId: entryId,
          automationResult: result,
          linkedTaskId: subjectId,
        ),
      ).called(1);
    });

    test('a relationship subject passes no task context', () async {
      const subjectId = 'relationship-ctx';
      final result = await stubHandledTranscription(
        subjectId,
        entity: testRelationship,
      );

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockRunner.runTranscription(
          audioEntryId: entryId,
          automationResult: result,
          // ignore: avoid_redundant_argument_values
          linkedTaskId: null,
        ),
      ).called(1);
    });

    test('a subject that no longer resolves passes no task context', () async {
      const subjectId = 'vanished';
      final result = await stubHandledTranscription(subjectId);

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockRunner.runTranscription(
          audioEntryId: entryId,
          automationResult: result,
          // ignore: avoid_redundant_argument_values
          linkedTaskId: null,
        ),
      ).called(1);
    });
  });

  group('agent nudge on transcription completion', () {
    test(
      'wakes the task agent with both the subject and entry tokens',
      () async {
        const subjectId = 'task-nudge';
        await stubHandledTranscription(subjectId, entity: testTask);
        when(
          () => mockSubjectAgentResolver(subjectId),
        ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-nudge'));

        await trigger().triggerAutomaticPrompts(
          entryId,
          stoppedState(),
          linkedSubjectId: subjectId,
        );

        verify(
          () => mockWakeOrchestrator.requestContentWake(
            agentId: 'agent-nudge',
            reason: 'transcriptionComplete',
            triggerTokens: {subjectId, entryId},
          ),
        ).called(1);
      },
    );

    // The whole point of phase 6: a spoken check-in refreshes the person's
    // briefing, which only happens if a non-task subject reaches the wake.
    test('wakes a relationship agent for a spoken check-in', () async {
      const subjectId = 'relationship-nudge';
      await stubHandledTranscription(subjectId, entity: testRelationship);
      when(
        () => mockSubjectAgentResolver(subjectId),
      ).thenAnswer(
        (_) async => makeTestIdentity(agentId: 'relationship-agent'),
      );

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockWakeOrchestrator.requestContentWake(
          agentId: 'relationship-agent',
          reason: 'transcriptionComplete',
          triggerTokens: {subjectId, entryId},
        ),
      ).called(1);
    });

    test(
      'logs the stale outcome when the orchestrator declines to wake',
      () async {
        const subjectId = 'task-stale';
        await stubHandledTranscription(subjectId, entity: testTask);
        when(
          () => mockSubjectAgentResolver(subjectId),
        ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-stale'));
        when(
          () => mockWakeOrchestrator.requestContentWake(
            agentId: 'agent-stale',
            reason: 'transcriptionComplete',
            triggerTokens: {subjectId, entryId},
          ),
        ).thenReturn(false);

        await trigger().triggerAutomaticPrompts(
          entryId,
          stoppedState(),
          linkedSubjectId: subjectId,
        );

        verify(
          () => mockDomainLogger.log(
            LogDomain.ai,
            any<String>(that: contains('Marked report stale')),
            subDomain: 'nudgeSubjectAgent',
          ),
        ).called(1);
      },
    );

    test('does not wake when the subject has no agent', () async {
      const subjectId = 'subject-orphan';
      await stubHandledTranscription(subjectId, entity: testTask);

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verifyNever(
        () => mockWakeOrchestrator.requestContentWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          triggerTokens: any(named: 'triggerTokens'),
        ),
      );
    });

    test('does not wake when automation never transcribed', () async {
      const subjectId = 'subject-skip';
      when(
        () => mockSubjectAgentResolver(subjectId),
      ).thenAnswer((_) async => makeTestIdentity(agentId: 'agent-skip'));

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verifyNever(
        () => mockWakeOrchestrator.requestContentWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          triggerTokens: any(named: 'triggerTokens'),
        ),
      );
    });

    // A missed nudge is recoverable through the subscription path; losing the
    // transcript because the lookup threw is not.
    test('a failing agent lookup is logged, not propagated', () async {
      const subjectId = 'subject-boom';
      await stubHandledTranscription(subjectId, entity: testTask);
      when(
        () => mockSubjectAgentResolver(subjectId),
      ).thenThrow(Exception('link read failed'));

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: subjectId,
      );

      verify(
        () => mockDomainLogger.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'nudgeSubjectAgent',
        ),
      ).called(1);
      verifyNever(
        () => mockDomainLogger.error(
          LogDomain.ai,
          any<Object>(),
          stackTrace: any<StackTrace?>(named: 'stackTrace'),
          subDomain: 'triggerAutomaticPrompts',
        ),
      );
    });
  });

  // A goal check-in is a `JournalAudio` linked to a goal's journal entry,
  // which belongs to no task and no category — so the category gate above
  // always declines it. The goal agent's own automatic-updates switch decides
  // instead, and it decides HERE, on the stop path, because a recording
  // stopped from the sidebar or the floating indicator never reports back to
  // the composer that opened the recorder.
  group('goal check-in fallback', () {
    const goalEntryId = 'goal-entry-1';

    void stubGoalAgent({AgentConfig config = const AgentConfig()}) {
      when(() => mockSubjectAgentResolver(goalEntryId)).thenAnswer(
        (_) async => makeTestIdentity(
          agentId: 'goal-agent',
          kind: AgentKinds.goalAgent,
          config: config,
        ),
      );
    }

    test(
      'a category-less check-in enters the shared skill pipeline',
      () async {
        stubGoalAgent(
          config: const AgentConfig(automaticUpdatesEnabled: true),
        );

        await trigger().triggerAutomaticPrompts(
          entryId,
          stoppedState(),
          linkedSubjectId: goalEntryId,
        );

        // The whole point: the recording enters the pipeline every other
        // recording uses, with no task context claimed — the runner would go
        // looking for a task that does not exist.
        expect(skillTriggers, hasLength(1));
        expect(skillTriggers.single.entityId, entryId);
        expect(skillTriggers.single.skillId, skillTranscribeContextId);
        expect(skillTriggers.single.linkedTaskId, isNull);
        // …and not through the profile runner, which had nothing to run.
        verifyNever(
          () => mockRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        );
      },
    );

    test(
      'a goal created before the switch existed still transcribes',
      () async {
        // Legacy goal agents carry no explicit value and shipped with automatic
        // updates ON — reading null as off (the task-agent default) would
        // silently stop transcribing every check-in on them.
        stubGoalAgent();

        await trigger().triggerAutomaticPrompts(
          entryId,
          stoppedState(),
          linkedSubjectId: goalEntryId,
        );

        expect(skillTriggers.map((p) => p.entityId), [entryId]);
      },
    );

    test('automatic updates switched off records a visible decline', () async {
      stubGoalAgent(
        config: const AgentConfig(automaticUpdatesEnabled: false),
      );

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: goalEntryId,
      );

      // Nothing is spent — that is what the switch is for…
      expect(skillTriggers, isEmpty);
      // …but the recording is marked as needing the user rather than left
      // claiming progress it will never make: the failed state is what makes
      // the check-ins rail offer Retry.
      expect(
        container.read(
          inferenceStatusControllerProvider((
            id: entryId,
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        InferenceStatus.error,
      );
      expect(
        container.read(
          inferenceErrorControllerProvider((
            id: entryId,
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        AppLocalizationsEn().goalCheckInTranscriptionOff,
      );
    });

    test('a declined task recording is not rescued by its agent', () async {
      // The category switch is the task's consent signal. When it says no,
      // the task agent's own switch must not override it.
      when(() => mockSubjectAgentResolver('task-1')).thenAnswer(
        (_) async => makeTestIdentity(
          agentId: 'task-agent',
          config: const AgentConfig(automaticUpdatesEnabled: true),
        ),
      );

      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: 'task-1',
      );

      expect(skillTriggers, isEmpty);
      expect(
        container.read(
          inferenceStatusControllerProvider((
            id: entryId,
            aiResponseType: AiResponseType.audioTranscription,
          )),
        ),
        InferenceStatus.idle,
      );
    });

    test('a subject with no agent is left to the category gate', () async {
      await trigger().triggerAutomaticPrompts(
        entryId,
        stoppedState(),
        linkedSubjectId: 'orphan-subject',
      );

      expect(skillTriggers, isEmpty);
    });
  });
}
