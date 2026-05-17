// ignore_for_file: unnecessary_lambdas, avoid_redundant_argument_values

import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/entry_link.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/ai/model/ai_config.dart';
import 'package:lotti/features/ai/model/resolved_profile.dart';
import 'package:lotti/features/ai/model/skill_assignment.dart';
import 'package:lotti/features/ai/services/profile_automation_service.dart';
import 'package:lotti/features/ai/state/consts.dart';
import 'package:lotti/features/sync/services/synced_audio_inference_dispatcher.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

const _kLocalHost = 'local-host';
const _kRemoteHost = 'remote-host';
const _kAudioId = 'audio-1';
const _kTaskId = 'task-1';
const _kProfileId = 'profile-1';
const _kAgentId = 'agent-1';
const _kSkillId = 'skill-1';
final _kCreatedAt = DateTime.utc(2026, 3, 15, 12);

class _Bench {
  _Bench({this.domainLogger});

  final journalDb = MockJournalDb();
  final vectorClockService = MockVectorClockService();
  final profileAutomationResolver = MockProfileAutomationResolver();
  final profileResolver = MockProfileResolver();
  final aiConfigRepository = MockAiConfigRepository();
  final skillInferenceRunner = MockSkillInferenceRunner();
  final taskAgentService = MockTaskAgentService();
  final wakeOrchestrator = MockWakeOrchestrator();
  final DomainLogger? domainLogger;

  late final dispatcher = SyncedAudioInferenceDispatcher(
    journalDb: journalDb,
    vectorClockService: vectorClockService,
    profileAutomationResolver: profileAutomationResolver,
    profileResolver: profileResolver,
    aiConfigRepository: aiConfigRepository,
    skillInferenceRunner: skillInferenceRunner,
    taskAgentService: taskAgentService,
    wakeOrchestrator: wakeOrchestrator,
    domainLogger: domainLogger,
  );

  /// Wires the happy path: an audio entry, linked task, resolved profile id,
  /// raw profile pinned to the local host and fully local, automated
  /// transcription skill, transcript grows after runTranscription. Returns
  /// the dispatcher; tests adjust the bench for each negative branch.
  void stubHappyPath({
    VectorClock? audioVectorClock,
    int priorTranscriptCount = 0,
    int postTranscriptCount = 1,
    String? pinnedHostId = _kLocalHost,
    bool profileIsLocal = true,
    bool transcriptionSlotPopulated = true,
    bool hasAutomatedTranscriptionSkill = true,
    bool taskAgentPresent = true,
  }) {
    when(
      () => vectorClockService.getHost(),
    ).thenAnswer((_) async => _kLocalHost);

    // 1st & 2nd journalEntityById call: prior and post snapshots of the audio.
    final priorAudio = _makeAudio(
      vectorClock:
          audioVectorClock ??
          const VectorClock({_kRemoteHost: 1, _kLocalHost: 0}),
      transcriptCount: priorTranscriptCount,
    );
    final postAudio = _makeAudio(
      vectorClock:
          audioVectorClock ??
          const VectorClock({_kRemoteHost: 1, _kLocalHost: 0}),
      transcriptCount: postTranscriptCount,
    );
    var audioReads = 0;
    when(() => journalDb.journalEntityById(_kAudioId)).thenAnswer((_) async {
      audioReads++;
      return audioReads == 1 ? priorAudio : postAudio;
    });

    // linksForEntryIds: one link from task → audio.
    final link = EntryLink.basic(
      id: 'link-1',
      fromId: _kTaskId,
      toId: _kAudioId,
      createdAt: _kCreatedAt,
      updatedAt: _kCreatedAt,
      vectorClock: null,
    );
    when(
      () => journalDb.linksForEntryIds({_kAudioId}),
    ).thenAnswer((_) async => [link]);
    when(() => journalDb.journalEntityById(_kTaskId)).thenAnswer(
      (_) async => _makeTask(),
    );

    // Profile id resolution.
    when(
      () => profileAutomationResolver.resolveProfileIdForTask(_kTaskId),
    ).thenAnswer((_) async => _kProfileId);

    // Raw profile load.
    const referencedThinkingModelId = 'm-thinking';
    final referencedTranscriptionModelId = transcriptionSlotPopulated
        ? 'm-transcribe'
        : null;
    final assignments = hasAutomatedTranscriptionSkill
        ? [const SkillAssignment(skillId: _kSkillId, automate: true)]
        : <SkillAssignment>[];
    final rawProfile =
        AiConfig.inferenceProfile(
              id: _kProfileId,
              name: 'Local Mac',
              createdAt: _kCreatedAt,
              thinkingModelId: referencedThinkingModelId,
              transcriptionModelId: referencedTranscriptionModelId,
              pinnedHostId: pinnedHostId,
              skillAssignments: assignments,
            )
            as AiConfigInferenceProfile;
    when(
      () => aiConfigRepository.getConfigById(_kProfileId),
    ).thenAnswer((_) async => rawProfile);

    // Locality: stub the dependencies that `profileIsLocal` walks.
    final thinkingProviderType = profileIsLocal
        ? InferenceProviderType.mlxAudio
        : InferenceProviderType.gemini;
    _stubModelAndProvider(
      modelId: referencedThinkingModelId,
      providerType: thinkingProviderType,
      providerId: 'p-thinking',
    );
    if (referencedTranscriptionModelId != null) {
      _stubModelAndProvider(
        modelId: referencedTranscriptionModelId,
        providerType: InferenceProviderType.mlxAudio,
        providerId: 'p-transcribe',
      );
    }

    // Skill lookup.
    final skill = AiConfig.skill(
      id: _kSkillId,
      name: 'Transcribe',
      createdAt: _kCreatedAt,
      skillType: SkillType.transcription,
      requiredInputModalities: const [Modality.audio],
      systemInstructions: 'sys',
      userInstructions: 'usr',
    );
    when(
      () => aiConfigRepository.getConfigById(_kSkillId),
    ).thenAnswer((_) async => skill);

    // resolveByProfileId for the runner.
    final resolvedProvider =
        AiConfig.inferenceProvider(
              id: 'p-transcribe',
              baseUrl: '',
              apiKey: '',
              name: 'mlxAudio',
              inferenceProviderType: InferenceProviderType.mlxAudio,
              createdAt: _kCreatedAt,
            )
            as AiConfigInferenceProvider;
    final resolvedProfile = ResolvedProfile(
      thinkingModelId: referencedThinkingModelId,
      thinkingProvider: resolvedProvider,
      transcriptionModelId: referencedTranscriptionModelId,
      transcriptionProvider: transcriptionSlotPopulated
          ? resolvedProvider
          : null,
    );
    when(
      () => profileResolver.resolveByProfileId(_kProfileId),
    ).thenAnswer((_) async => resolvedProfile);

    // runTranscription is a no-op stub (the prior/post reads control the
    // observable effect).
    when(
      () => skillInferenceRunner.runTranscription(
        audioEntryId: any(named: 'audioEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    ).thenAnswer((_) async {});

    // Task agent for the wake nudge.
    if (taskAgentPresent) {
      when(() => taskAgentService.getTaskAgentForTask(_kTaskId)).thenAnswer(
        (_) async =>
            AgentDomainEntity.agent(
                  id: _kAgentId,
                  agentId: _kAgentId,
                  kind: 'task_agent',
                  displayName: 'Test Agent',
                  lifecycle: AgentLifecycle.active,
                  mode: AgentInteractionMode.autonomous,
                  allowedCategoryIds: const {},
                  currentStateId: 'state-1',
                  config: const AgentConfig(),
                  createdAt: _kCreatedAt,
                  updatedAt: _kCreatedAt,
                  vectorClock: null,
                )
                as AgentIdentityEntity,
      );
    } else {
      when(
        () => taskAgentService.getTaskAgentForTask(_kTaskId),
      ).thenAnswer((_) async => null);
    }

    when(
      () => wakeOrchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn(null);
  }

  void _stubModelAndProvider({
    required String modelId,
    required InferenceProviderType providerType,
    required String providerId,
  }) {
    when(() => aiConfigRepository.getConfigById(modelId)).thenAnswer(
      (_) async => AiConfig.model(
        id: modelId,
        name: modelId,
        providerModelId: modelId,
        inferenceProviderId: providerId,
        createdAt: _kCreatedAt,
        inputModalities: const [Modality.text],
        outputModalities: const [Modality.text],
        isReasoningModel: false,
      ),
    );
    when(() => aiConfigRepository.getConfigById(providerId)).thenAnswer(
      (_) async => AiConfig.inferenceProvider(
        id: providerId,
        baseUrl: '',
        apiKey: '',
        name: providerType.name,
        inferenceProviderType: providerType,
        createdAt: _kCreatedAt,
      ),
    );
  }

  JournalAudio _makeAudio({
    required VectorClock vectorClock,
    required int transcriptCount,
  }) {
    final transcripts = transcriptCount == 0
        ? <AudioTranscript>[]
        : [
            for (var i = 0; i < transcriptCount; i++)
              AudioTranscript(
                created: _kCreatedAt,
                library: 'mlx',
                model: 'm',
                detectedLanguage: '-',
                transcript: 'hello $i',
              ),
          ];
    return JournalAudio(
      meta: Metadata(
        id: _kAudioId,
        createdAt: _kCreatedAt,
        updatedAt: _kCreatedAt,
        dateFrom: _kCreatedAt,
        dateTo: _kCreatedAt,
        vectorClock: vectorClock,
      ),
      data: AudioData(
        dateFrom: _kCreatedAt,
        dateTo: _kCreatedAt,
        duration: const Duration(seconds: 1),
        audioFile: 'a.aac',
        audioDirectory: '/audio/',
        autoTranscribeWasActive: false,
        transcripts: transcripts,
      ),
    );
  }

  Task _makeTask() {
    return Task(
      meta: Metadata(
        id: _kTaskId,
        createdAt: _kCreatedAt,
        updatedAt: _kCreatedAt,
        dateFrom: _kCreatedAt,
        dateTo: _kCreatedAt,
      ),
      data: TaskData(
        status: TaskStatus.open(
          id: 'st-1',
          createdAt: _kCreatedAt,
          utcOffset: 0,
        ),
        dateFrom: _kCreatedAt,
        dateTo: _kCreatedAt,
        statusHistory: const [],
        title: 'A task',
      ),
    );
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(AutomationResult.notHandled);
    registerFallbackValue(<String>{});
  });

  late _Bench bench;

  setUp(() {
    bench = _Bench();
  });

  void expectRunNotCalled() {
    verifyNever(
      () => bench.skillInferenceRunner.runTranscription(
        audioEntryId: any(named: 'audioEntryId'),
        automationResult: any(named: 'automationResult'),
        linkedTaskId: any(named: 'linkedTaskId'),
      ),
    );
    verifyNever(
      () => bench.wakeOrchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    );
  }

  group('happy path', () {
    test(
      'calls runTranscription, reloads entity, then enqueues a wake',
      () async {
        bench.stubHappyPath();

        await bench.dispatcher.maybeDispatch(_kAudioId);

        verify(
          () => bench.skillInferenceRunner.runTranscription(
            audioEntryId: _kAudioId,
            automationResult: any(named: 'automationResult'),
            linkedTaskId: _kTaskId,
          ),
        ).called(1);
        verify(
          () => bench.wakeOrchestrator.enqueueManualWake(
            agentId: _kAgentId,
            reason: WakeReason.transcriptionComplete.name,
            triggerTokens: {_kTaskId, _kAudioId},
          ),
        ).called(1);
      },
    );
  });

  group('sentinels and id shape', () {
    test('skips category sentinel tokens', () async {
      bench.stubHappyPath();
      await bench.dispatcher.maybeDispatch('CATEGORIES_CHANGED');
      expectRunNotCalled();
    });

    test('skips empty id', () async {
      bench.stubHappyPath();
      await bench.dispatcher.maybeDispatch('');
      expectRunNotCalled();
    });
  });

  group('entity & content guards', () {
    test('skips when the id is not a JournalAudio', () async {
      bench.stubHappyPath();
      when(
        () => bench.journalDb.journalEntityById(_kAudioId),
      ).thenAnswer((_) async => bench._makeTask());
      await bench.dispatcher.maybeDispatch(_kAudioId);
      expectRunNotCalled();
    });

    test('skips when transcripts are already non-empty', () async {
      bench.stubHappyPath(priorTranscriptCount: 1);
      await bench.dispatcher.maybeDispatch(_kAudioId);
      expectRunNotCalled();
    });
  });

  group('self-echo guard', () {
    test(
      'skips when VC has only the local host as its sole entry',
      () async {
        bench.stubHappyPath(
          audioVectorClock: const VectorClock({_kLocalHost: 3}),
        );

        await bench.dispatcher.maybeDispatch(_kAudioId);

        expectRunNotCalled();
      },
    );

    test(
      'proceeds when VC includes the local host alongside other hosts',
      () async {
        bench.stubHappyPath(
          audioVectorClock: const VectorClock({
            _kRemoteHost: 7,
            _kLocalHost: 3,
          }),
        );

        await bench.dispatcher.maybeDispatch(_kAudioId);

        verify(
          () => bench.skillInferenceRunner.runTranscription(
            audioEntryId: _kAudioId,
            automationResult: any(named: 'automationResult'),
            linkedTaskId: _kTaskId,
          ),
        ).called(1);
      },
    );

    test(
      'skips when local host id cannot be determined',
      () async {
        bench.stubHappyPath();
        when(
          () => bench.vectorClockService.getHost(),
        ).thenAnswer((_) async => null);

        await bench.dispatcher.maybeDispatch(_kAudioId);

        expectRunNotCalled();
      },
    );
  });

  group('linked-task guard', () {
    test('skips when the audio has no linked task', () async {
      bench.stubHappyPath();
      when(
        () => bench.journalDb.linksForEntryIds({_kAudioId}),
      ).thenAnswer((_) async => <EntryLink>[]);
      await bench.dispatcher.maybeDispatch(_kAudioId);
      expectRunNotCalled();
    });

    test('skips when the linked parent is not a Task', () async {
      bench.stubHappyPath();
      when(() => bench.journalDb.journalEntityById(_kTaskId)).thenAnswer(
        (_) async => bench._makeAudio(
          vectorClock: const VectorClock({_kRemoteHost: 1}),
          transcriptCount: 0,
        ),
      );
      await bench.dispatcher.maybeDispatch(_kAudioId);
      expectRunNotCalled();
    });
  });

  group('profile-id resolution', () {
    test(
      'skips when resolveProfileIdForTask returns null',
      () async {
        bench.stubHappyPath();
        when(
          () => bench.profileAutomationResolver.resolveProfileIdForTask(
            _kTaskId,
          ),
        ).thenAnswer((_) async => null);

        await bench.dispatcher.maybeDispatch(_kAudioId);

        expectRunNotCalled();
      },
    );

    test('skips when the profile config is missing', () async {
      bench.stubHappyPath();
      when(
        () => bench.aiConfigRepository.getConfigById(_kProfileId),
      ).thenAnswer((_) async => null);

      await bench.dispatcher.maybeDispatch(_kAudioId);

      expectRunNotCalled();
    });
  });

  group('pin guards', () {
    test('skips when pinnedHostId is null', () async {
      bench.stubHappyPath(pinnedHostId: null);
      await bench.dispatcher.maybeDispatch(_kAudioId);
      expectRunNotCalled();
    });

    test('skips when pinnedHostId does not match the local host', () async {
      bench.stubHappyPath(pinnedHostId: 'some-other-host');
      await bench.dispatcher.maybeDispatch(_kAudioId);
      expectRunNotCalled();
    });
  });

  group('locality guard', () {
    test('skips when the profile references a cloud provider', () async {
      bench.stubHappyPath(profileIsLocal: false);
      await bench.dispatcher.maybeDispatch(_kAudioId);
      expectRunNotCalled();
    });
  });

  group('transcription slot & skill', () {
    test(
      'skips when transcriptionModelId is null on the raw profile',
      () async {
        bench.stubHappyPath(transcriptionSlotPopulated: false);
        await bench.dispatcher.maybeDispatch(_kAudioId);
        expectRunNotCalled();
      },
    );

    test(
      'skips when the profile has no automated transcription skill — no '
      'fallback',
      () async {
        bench.stubHappyPath(hasAutomatedTranscriptionSkill: false);
        await bench.dispatcher.maybeDispatch(_kAudioId);
        expectRunNotCalled();
      },
    );
  });

  group('post-transcription verification', () {
    test(
      'does NOT enqueue a wake when the transcript count did not grow',
      () async {
        // runTranscription is stubbed; we force the "post" read to still
        // show zero transcripts (silent failure).
        bench.stubHappyPath(postTranscriptCount: 0);

        await bench.dispatcher.maybeDispatch(_kAudioId);

        verify(
          () => bench.skillInferenceRunner.runTranscription(
            audioEntryId: _kAudioId,
            automationResult: any(named: 'automationResult'),
            linkedTaskId: _kTaskId,
          ),
        ).called(1);
        verifyNever(
          () => bench.wakeOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        );
      },
    );

    test(
      'does NOT enqueue a wake when runTranscription throws',
      () async {
        bench.stubHappyPath(postTranscriptCount: 0);
        when(
          () => bench.skillInferenceRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        ).thenThrow(StateError('boom'));

        await bench.dispatcher.maybeDispatch(_kAudioId);

        // The dispatcher catches the throw inside the try/catch and then
        // sees no new transcript — no wake fires.
        verifyNever(
          () => bench.wakeOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        );
      },
    );

    test(
      'does NOT enqueue a wake when the task agent disappears',
      () async {
        bench.stubHappyPath(taskAgentPresent: false);
        await bench.dispatcher.maybeDispatch(_kAudioId);
        verifyNever(
          () => bench.wakeOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        );
      },
    );
  });

  group('error handling and rare guards', () {
    test(
      'maybeDispatch swallows an outer throw and logs it — the listener '
      'loop must keep draining even when the dispatcher hits an unexpected '
      'error path',
      () async {
        final logger = MockDomainLogger();
        final bench2 = _Bench(domainLogger: logger);
        // Force the very first DB read to throw — this lands outside any of
        // the dispatcher's per-step catches and exercises the outer try in
        // maybeDispatch.
        when(
          () => bench2.journalDb.journalEntityById(any()),
        ).thenThrow(StateError('db unavailable'));
        when(
          () => logger.error(
            any(),
            any(),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        await expectLater(
          bench2.dispatcher.maybeDispatch(_kAudioId),
          completes,
        );

        verify(
          () => logger.error(
            LogDomains.sync,
            any(that: contains('threw on id=$_kAudioId')),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
      },
    );

    test(
      'skips with no fallback when the profile has multiple automated '
      'transcription skills — ambiguous policies must not silently pick one',
      () async {
        bench.stubHappyPath();
        // Override the profile config to carry two automated transcription
        // skills. Both resolve to skills of type transcription — the
        // dispatcher must refuse rather than guess.
        const skillIdA = 'skill-A';
        const skillIdB = 'skill-B';
        final profile =
            AiConfig.inferenceProfile(
                  id: _kProfileId,
                  name: 'Ambiguous',
                  createdAt: _kCreatedAt,
                  thinkingModelId: 'm-thinking',
                  transcriptionModelId: 'm-transcribe',
                  pinnedHostId: _kLocalHost,
                  skillAssignments: const [
                    SkillAssignment(skillId: skillIdA, automate: true),
                    SkillAssignment(skillId: skillIdB, automate: true),
                  ],
                )
                as AiConfigInferenceProfile;
        when(
          () => bench.aiConfigRepository.getConfigById(_kProfileId),
        ).thenAnswer((_) async => profile);

        AiConfigSkill mkSkill(String id) =>
            AiConfig.skill(
                  id: id,
                  name: id,
                  createdAt: _kCreatedAt,
                  skillType: SkillType.transcription,
                  requiredInputModalities: const [Modality.audio],
                  systemInstructions: 'sys',
                  userInstructions: 'usr',
                )
                as AiConfigSkill;
        when(
          () => bench.aiConfigRepository.getConfigById(skillIdA),
        ).thenAnswer((_) async => mkSkill(skillIdA));
        when(
          () => bench.aiConfigRepository.getConfigById(skillIdB),
        ).thenAnswer((_) async => mkSkill(skillIdB));

        await bench.dispatcher.maybeDispatch(_kAudioId);

        verifyNever(
          () => bench.skillInferenceRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        );
      },
    );

    test(
      'skips when ProfileResolver.resolveByProfileId yields a profile with no '
      'transcription provider — guards against the runner being called with '
      'an unusable resolved profile',
      () async {
        bench.stubHappyPath();
        when(
          () => bench.profileResolver.resolveByProfileId(_kProfileId),
        ).thenAnswer((_) async => null);

        await bench.dispatcher.maybeDispatch(_kAudioId);

        verifyNever(
          () => bench.skillInferenceRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        );
      },
    );

    test(
      'when a DomainLogger is wired, runner throws emit a structured error '
      'and the dispatcher still completes without rethrowing',
      () async {
        final logger = MockDomainLogger();
        final bench2 = _Bench(domainLogger: logger)
          ..stubHappyPath(postTranscriptCount: 0);
        when(
          () => bench2.skillInferenceRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        ).thenThrow(StateError('runner exploded'));
        when(
          () => logger.log(any(), any(), subDomain: any(named: 'subDomain')),
        ).thenAnswer((_) {});
        when(
          () => logger.error(
            any(),
            any(),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).thenAnswer((_) {});

        await bench2.dispatcher.maybeDispatch(_kAudioId);

        verify(
          () => logger.error(
            LogDomains.sync,
            any(that: contains('runTranscription threw for $_kAudioId')),
            error: any(named: 'error'),
            stackTrace: any(named: 'stackTrace'),
            subDomain: any(named: 'subDomain'),
          ),
        ).called(1);
        verifyNever(
          () => bench2.wakeOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        );
      },
    );
  });

  group('glados: dispatcher eligibility state space', () {
    glados.Glados(
      glados.any.dispatcherScenario,
      glados.ExploreConfig(numRuns: 120),
    ).test('runTranscription iff every guard passes; wake iff runTranscription '
        'reached AND transcripts grew AND task agent present', (
      scenario,
    ) async {
      // Glados reuses a single test binding across runs — rebuild the bench
      // every iteration so verify counts aren't contaminated by prior runs.
      final localBench = _Bench()
        ..stubHappyPath(
          audioVectorClock: scenario.vectorClock,
          priorTranscriptCount: scenario.priorTranscriptCount,
          postTranscriptCount: scenario.postTranscriptCount,
          pinnedHostId: scenario.pinnedHostId,
          profileIsLocal: scenario.profileIsLocal,
          transcriptionSlotPopulated: scenario.transcriptionSlotPopulated,
          hasAutomatedTranscriptionSkill:
              scenario.hasAutomatedTranscriptionSkill,
          taskAgentPresent: scenario.taskAgentPresent,
        );

      await localBench.dispatcher.maybeDispatch(_kAudioId);

      // Property 1: runTranscription called iff every gating predicate passes.
      final shouldRun = scenario.expectsRunTranscription;
      if (shouldRun) {
        verify(
          () => localBench.skillInferenceRunner.runTranscription(
            audioEntryId: _kAudioId,
            automationResult: any(named: 'automationResult'),
            linkedTaskId: _kTaskId,
          ),
        ).called(1);
      } else {
        verifyNever(
          () => localBench.skillInferenceRunner.runTranscription(
            audioEntryId: any(named: 'audioEntryId'),
            automationResult: any(named: 'automationResult'),
            linkedTaskId: any(named: 'linkedTaskId'),
          ),
        );
      }

      // Property 2: wake called iff runTranscription ran AND transcripts grew
      // AND the task agent exists.
      final shouldWake =
          shouldRun &&
          scenario.postTranscriptCount > scenario.priorTranscriptCount &&
          scenario.taskAgentPresent;
      if (shouldWake) {
        verify(
          () => localBench.wakeOrchestrator.enqueueManualWake(
            agentId: _kAgentId,
            reason: WakeReason.transcriptionComplete.name,
            triggerTokens: {_kTaskId, _kAudioId},
          ),
        ).called(1);
      } else {
        verifyNever(
          () => localBench.wakeOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        );
      }
    }, tags: 'glados');
  });
}

/// One sampled combination of the dispatcher's input dimensions plus the
/// computed expectation. Glados generates these so a single property pass
/// covers the cartesian product of guard states; the explicit table-driven
/// tests above still document each named guard.
class _GeneratedDispatcherScenario {
  const _GeneratedDispatcherScenario({
    required this.vectorClock,
    required this.priorTranscriptCount,
    required this.postTranscriptCount,
    required this.pinnedHostId,
    required this.profileIsLocal,
    required this.transcriptionSlotPopulated,
    required this.hasAutomatedTranscriptionSkill,
    required this.taskAgentPresent,
  });

  final VectorClock vectorClock;
  final int priorTranscriptCount;
  final int postTranscriptCount;
  final String? pinnedHostId;
  final bool profileIsLocal;
  final bool transcriptionSlotPopulated;
  final bool hasAutomatedTranscriptionSkill;
  final bool taskAgentPresent;

  /// Whether the dispatcher should reach `runTranscription`. Encodes the
  /// dispatcher's documented eligibility logic: every guard must pass.
  bool get expectsRunTranscription {
    // priorTranscriptCount == 0 (no skip)
    if (priorTranscriptCount > 0) return false;
    // Self-echo guard: skip iff VC has only the local host.
    final vclock = vectorClock.vclock;
    if (vclock.length == 1 && vclock.containsKey(_kLocalHost)) return false;
    // pinnedHostId must be non-null and match the local host.
    if (pinnedHostId == null) return false;
    if (pinnedHostId != _kLocalHost) return false;
    if (!profileIsLocal) return false;
    if (!transcriptionSlotPopulated) return false;
    if (!hasAutomatedTranscriptionSkill) return false;
    return true;
  }

  @override
  String toString() =>
      '_GeneratedDispatcherScenario(vc=$vectorClock, '
      'priorTranscripts=$priorTranscriptCount, '
      'postTranscripts=$postTranscriptCount, '
      'pinnedHostId=$pinnedHostId, profileIsLocal=$profileIsLocal, '
      'transcriptionSlot=$transcriptionSlotPopulated, '
      'automatedSkill=$hasAutomatedTranscriptionSkill, '
      'taskAgent=$taskAgentPresent)';
}

enum _VectorClockShape { onlyLocal, onlyRemote, merged, empty }

enum _PinnedHostShape { unset, matches, mismatches }

extension _AnyDispatcherScenario on glados.Any {
  glados.Generator<_VectorClockShape> get vectorClockShape =>
      glados.AnyUtils(this).choose(_VectorClockShape.values);

  glados.Generator<_PinnedHostShape> get pinnedHostShape =>
      glados.AnyUtils(this).choose(_PinnedHostShape.values);

  glados.Generator<_GeneratedDispatcherScenario> get dispatcherScenario =>
      glados.CombinableAny(this).combine8(
        vectorClockShape,
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 3),
        pinnedHostShape,
        glados.any.bool,
        glados.any.bool,
        glados.any.bool,
        glados.any.bool,
        (
          _VectorClockShape vc,
          int prior,
          int post,
          _PinnedHostShape pin,
          bool isLocal,
          bool slot,
          bool skill,
          bool agent,
        ) {
          final vectorClock = switch (vc) {
            _VectorClockShape.empty => const VectorClock({}),
            _VectorClockShape.onlyLocal => const VectorClock({_kLocalHost: 3}),
            _VectorClockShape.onlyRemote => const VectorClock({
              _kRemoteHost: 7,
            }),
            _VectorClockShape.merged => const VectorClock({
              _kRemoteHost: 7,
              _kLocalHost: 3,
            }),
          };
          final pinned = switch (pin) {
            _PinnedHostShape.unset => null,
            _PinnedHostShape.matches => _kLocalHost,
            _PinnedHostShape.mismatches => 'some-other-host',
          };
          return _GeneratedDispatcherScenario(
            vectorClock: vectorClock,
            priorTranscriptCount: prior,
            // Ensure post >= prior so the "grew" check is well-defined; the
            // bench's stubHappyPath produces a JournalAudio with exactly the
            // requested transcript count on the second read.
            postTranscriptCount: post < prior ? prior : post,
            pinnedHostId: pinned,
            profileIsLocal: isLocal,
            transcriptionSlotPopulated: slot,
            hasAutomatedTranscriptionSkill: skill,
            taskAgentPresent: agent,
          );
        },
      );
}
