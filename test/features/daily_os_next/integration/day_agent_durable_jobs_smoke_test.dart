import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/day_agent_identity.dart';
import 'package:lotti/classes/day_agent_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_config.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:openai_dart/openai_dart.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../eval/framework/eval_scenario.dart';
import '../services/day_processing_test_db.dart';
import 'day_agent_journey_support.dart';
import 'day_agent_pipeline_harness.dart';
import 'realistic_day_planning_scenarios.dart';
import 'scripted_conversation_repository.dart';

/// End-to-end smoke test for the ADR 0032 durable draft/refine pipeline.
///
/// Unlike the unit tests elsewhere in this branch (which fake or mock the
/// outbox, the executor, or the workflow individually), this drives a draft
/// then a refine through the real production chain assembled by
/// [DayAgentPipelineHarness]. Only the LLM response is scripted (no network
/// call), matching the pattern already used by `day_agent_workflow_test.dart`.
///
/// This is the closest thing to a live manual smoke test that runs in the
/// normal unit-test lane: it proves the new outbox → runtime → executor →
/// orchestrator → workflow → plan-service → outbox-completion round trip
/// genuinely works, not just that each link passes its own mocked unit
/// test. The full-journey live eval runs these same realistic fixtures against
/// Melious, including the coordinator and both user-facing wakes.
void main() {
  setUpAll(registerAllFallbackValues);

  // Fixed well into the future (rather than tied to whatever "today" is at
  // test-run time) so drafted blocks never trip the real
  // `DayAgentPlanWriter.persistDraftPlan` "must not start before current
  // time" guard, which compares against the real `clock.now()` whenever the
  // plan's day is today's local day.
  final now = DateTime(2030, 1, 15, 9);
  final dayDate = DateTime(2030, 1, 15);
  final dayId = dayAgentIdForDate(dayDate);

  DayAgentPipelineHarness createHarness({
    required DateTime at,
    required ScriptedConversationRepository conversations,
  }) => DayAgentPipelineHarness.create(
    now: at,
    conversationRepository: conversations,
    cloudInferenceRepository: MockCloudInferenceRepository(),
    profile: testInferenceProfile(
      id: 'profile-day',
      thinkingModelId: 'models/day',
    ),
    model: testAiModel(
      id: 'model-day',
      providerModelId: 'models/day',
      inferenceProviderId: 'provider-day',
    ),
    provider: testInferenceProvider(
      id: 'provider-day',
      apiKey: 'provider-key',
    ),
    dependencyResolver: EvalFixtureDependencyResolver(const {}),
    config: const DayAgentConfig(
      capacityMinutes: 300,
      workingHoursEnd: '18:00',
    ),
  );

  late ScriptedConversationRepository conversationRepository;
  late DayAgentPipelineHarness harness;

  setUp(() {
    conversationRepository = ScriptedConversationRepository();
    harness = createHarness(
      at: now,
      conversations: conversationRepository,
    );
    addTearDown(() => harness.dispose());
  });

  test(
    'draft then refine round-trip through the real outbox/executor/ '
    'orchestrator/workflow chain, with only the LLM response scripted',
    () async {
      // ── Draft ────────────────────────────────────────────────────────────
      conversationRepository.script([
        scriptedToolCall(
          id: 'draft-call',
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'blocks': [
              {
                'title': 'Deep work',
                'categoryId': 'work',
                'start': dayDate
                    .add(const Duration(hours: 9))
                    .toIso8601String(),
                'end': dayDate.add(const Duration(hours: 10)).toIso8601String(),
                'reason': 'Morning focus window.',
              },
            ],
          },
        ),
      ]);

      final draft = await harness.realDayAgent.draftDayPlan(
        captureId: const CaptureId(''),
        decidedTaskIds: const [],
        dayDate: dayDate,
      );

      expect(draft.blocks, hasLength(1));
      expect(draft.blocks.single.title, 'Deep work');
      expect(draft.state, DayState.drafted);

      // The per-day agent identity was created for real, and the durable job
      // it ran through is on disk, terminal, and succeeded — proving the
      // whole round trip, not just the in-memory return value.
      final dayAgentId = perDayAgentId(dayId);
      final draftJob = await harness.outbox.getById(
        DayProcessingOutboxRepository.draftJobId(dayId),
      );
      expect(draftJob, isNotNull);
      expect(draftJob!.isTerminal, isTrue);
      expect(draftJob.status.name, 'succeeded');
      final identity = await harness.agentRepository.getEntity(dayAgentId);
      expect(identity, isA<AgentIdentityEntity>());

      // ── Refine ───────────────────────────────────────────────────────────
      conversationRepository.script([
        scriptedToolCall(
          id: 'refine-call',
          name: DayAgentToolNames.proposePlanDiff,
          args: {
            'dayId': dayId,
            'changes': [
              {
                'action': 'added',
                'reason': 'Add a stretch break.',
                'to': {
                  'start': dayDate
                      .add(const Duration(hours: 11))
                      .toIso8601String(),
                  'end': dayDate
                      .add(const Duration(hours: 11, minutes: 15))
                      .toIso8601String(),
                  'title': 'Stretch',
                  'categoryId': 'health',
                },
              },
            ],
          },
        ),
      ]);

      final diff = await harness.realDayAgent.proposePlanDiff(
        currentPlan: draft,
        voiceTranscript: 'add a stretch break around 11',
      );

      expect(diff.changes, hasLength(1));
      expect(diff.changes.single.kind, PlanDiffChangeKind.added);

      final refineJobs = (await allDayProcessingJobs(
        harness.outbox.db,
      )).where((job) => job.kind.name == 'refinePlan').toList();
      expect(refineJobs, hasLength(1));
      expect(refineJobs.single.isTerminal, isTrue);
      expect(refineJobs.single.status.name, 'succeeded');
      expect(refineJobs.single.resultEntityId, isNotNull);
    },
  );

  test(
    'planner directive and dense multi-category capture retain every selected '
    'instruction without leaking unrelated corpus work',
    () async {
      seedScenarioCorpus(
        journalDb: harness.journalDb,
        scenario: denseRestOfDayScenario,
        planDate: dayDate,
        journalRepository: harness.journalRepository,
      );

      final coordinator = await harness.dayAgentService
          .getOrCreatePlannerAgent();
      conversationRepository.script([
        scriptedToolCall(
          id: 'directive-dentist',
          name: DayAgentToolNames.issueDayDirective,
          args: {
            'dayId': dayId,
            'commitments': [
              {
                'id': 'fixed-dentist',
                'source': 'userCommitment',
                'title': 'Dentist appointment at 16:30',
                'minutes': 60,
              },
            ],
            'capacityBudget': {'availableMinutes': 300},
            'attentionNotes': [
              'The dentist is fixed; preserve the time anchor.',
            ],
          },
        ),
      ]);
      await runPlannerDigest(
        harness: harness,
        coordinator: coordinator,
        dayId: dayId,
      );

      conversationRepository.scriptFromMessage(
        (message) => _matchedParseCalls(
          message: message,
          scenario: denseRestOfDayScenario,
          selectedTaskIds: denseRestOfDayScenario.decidedTaskIds,
        ),
      );
      final captureId = await harness.realDayAgent.submitCapture(
        transcript: denseRestOfDayScenario.captureTranscript!,
        capturedAt: dayDate.add(const Duration(hours: 8)),
        dayDate: dayDate,
      );
      final parseJob = await waitForTerminalDayProcessingJob(
        harness.outbox,
        DayProcessingOutboxRepository.parseJobId(captureId.value),
      );
      expect(parseJob.status, DayProcessingJobStatus.succeeded);

      final parsed = await harness.realDayAgent.parseCaptureToItems(captureId);
      expect(parsed, hasLength(denseRestOfDayScenario.decidedTaskIds.length));
      expect(
        parsed.map((item) => item.matchedTaskId),
        unorderedEquals(denseRestOfDayScenario.decidedTaskIds),
      );
      expect(
        parsed.map((item) => item.spokenPhrase),
        everyElement(isNotEmpty),
      );

      conversationRepository.script([
        scriptedToolCall(
          id: 'dense-draft',
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'captureId': captureId.value,
            'decidedTaskIds': denseRestOfDayScenario.decidedTaskIds,
            'blocks': [
              _block(
                dayDate,
                taskId: 'task-migration',
                title: 'Finish the database migration',
                categoryId: 'cat-project',
                startHour: 9,
                endHour: 10,
                endMinute: 15,
                reason: 'Finish the in-progress migration first.',
              ),
              _block(
                dayDate,
                taskId: 'task-invoice',
                title: 'Send the overdue client invoice',
                categoryId: 'cat-admin',
                startHour: 10,
                startMinute: 15,
                endHour: 10,
                endMinute: 35,
                reason: 'Complete before the requested 15:00 deadline.',
              ),
              _block(
                dayDate,
                taskId: 'task-client-call',
                title: 'Client planning call',
                categoryId: 'cat-client',
                startHour: 13,
                endHour: 13,
                endMinute: 45,
                reason: 'Keep the user-stated 13:00 call.',
              ),
              _block(
                dayDate,
                taskId: 'task-reset',
                title: 'Reset after the client call',
                categoryId: 'cat-wellbeing',
                startHour: 13,
                startMinute: 45,
                endHour: 14,
                reason: 'Preserve the requested 15-minute break relationship.',
              ),
              _block(
                dayDate,
                taskId: 'task-walk',
                title: 'Take a 30-minute walk',
                categoryId: 'cat-health',
                startHour: 14,
                endHour: 14,
                endMinute: 30,
                reason: 'Place the requested walk after lunch.',
              ),
              _block(
                dayDate,
                taskId: 'task-dentist',
                title: 'Dentist appointment',
                categoryId: 'cat-personal',
                startHour: 16,
                startMinute: 30,
                endHour: 17,
                endMinute: 30,
                reason: 'Binding fixed-dentist commitment at 16:30.',
              ),
            ],
          },
        ),
      ]);
      final draft = await harness.realDayAgent.draftDayPlan(
        captureId: captureId,
        decidedTaskIds: denseRestOfDayScenario.decidedTaskIds,
        dayDate: dayDate,
      );

      expect(
        draft.blocks.map((block) => block.taskId),
        orderedEquals(denseRestOfDayScenario.decidedTaskIds),
      );
      for (final unrelatedId in [
        'task-security-review',
        'task-release-notes',
        'task-expenses',
        'task-groceries',
        'task-training',
        'task-team-replies',
      ]) {
        expect(
          draft.blocks.map((block) => block.taskId),
          isNot(contains(unrelatedId)),
          reason: '$unrelatedId was visible but never selected',
        );
      }
      expect(draft.blocks[3].duration, const Duration(minutes: 15));
      expect(draft.blocks[5].start.hour, 16);
      expect(draft.blocks[5].start.minute, 30);

      final parsePrompt = conversationRepository.userMessages[1];
      expect(parsePrompt, contains(denseRestOfDayScenario.captureTranscript));
      expect(parsePrompt, contains('task-security-review'));
      expect(parsePrompt, contains('task-release-notes'));
      expect(parsePrompt, contains('cat-health'));
      expect(parsePrompt, contains('cat-finance'));
      final draftPrompt = conversationRepository.userMessages[2];
      for (final id in denseRestOfDayScenario.decidedTaskIds) {
        expect(draftPrompt, contains(id), reason: '$id must reach drafting');
      }
      expect(draftPrompt, contains('fixed-dentist'));
      expect(
        conversationRepository.toolNamesBySend[1],
        {DayAgentToolNames.parseCaptureToItems},
      );
      expect(
        conversationRepository.toolNamesBySend[2],
        {
          DayAgentToolNames.createTaskFromPhrase,
          DayAgentToolNames.raiseDayStatus,
          DayAgentToolNames.draftDayPlan,
        },
        reason:
            'Drafting should expose only tools that can produce its artifact '
            'or make an unavoidable conflict explicit.',
      );
      expect(
        conversationRepository.sendCount,
        3,
        reason:
            'One planner digest, one capture parse, and one draft should be '
            'enough; successful terminal tools must not trigger extra sends.',
      );

      final dayAgent = await harness.agentRepository.getEntity(
        perDayAgentId(dayId),
      );
      expect(dayAgent, isA<AgentIdentityEntity>());
      expect(
        (dayAgent! as AgentIdentityEntity).agentId,
        isNot(coordinator.agentId),
      );
    },
  );

  test(
    'overcommitted day agent names omitted selected work and the planner '
    'receives the escalation on its next digest',
    () async {
      seedScenarioCorpus(
        journalDb: harness.journalDb,
        scenario: overcommittedRestOfDayScenario,
        planDate: dayDate,
        journalRepository: harness.journalRepository,
      );
      final coordinator = await harness.dayAgentService
          .getOrCreatePlannerAgent();
      conversationRepository.script([
        scriptedToolCall(
          id: 'initial-board-directive',
          name: DayAgentToolNames.issueDayDirective,
          args: {
            'dayId': dayId,
            'commitments': [
              {
                'id': 'must-board-deck',
                'source': 'userCommitment',
                'title': 'Prepare the board deck',
                'minutes': 90,
              },
            ],
            'capacityBudget': {'availableMinutes': 180},
            'attentionNotes': ['The board deck cannot slip.'],
          },
        ),
      ]);
      await runPlannerDigest(
        harness: harness,
        coordinator: coordinator,
        dayId: dayId,
      );

      conversationRepository.scriptFromMessage(
        (message) => _matchedParseCalls(
          message: message,
          scenario: overcommittedRestOfDayScenario,
          selectedTaskIds: overcommittedRestOfDayScenario.decidedTaskIds,
        ),
      );
      final captureId = await harness.realDayAgent.submitCapture(
        transcript: overcommittedRestOfDayScenario.captureTranscript!,
        capturedAt: dayDate.add(const Duration(hours: 12)),
        dayDate: dayDate,
      );
      final parseJob = await waitForTerminalDayProcessingJob(
        harness.outbox,
        DayProcessingOutboxRepository.parseJobId(captureId.value),
      );
      expect(parseJob.status, DayProcessingJobStatus.succeeded);

      // Reproduce the live Qwen failure: the blocks total less than the
      // configured 300-minute capacity because there is a clock gap, yet the
      // final block runs past the configured 18:00 working-hours boundary.
      // The production guard must reject this turn so the workflow gives the
      // model its one forced correction attempt.
      conversationRepository.script([
        scriptedToolCall(
          id: 'overcommitted-out-of-hours',
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'captureId': captureId.value,
            'decidedTaskIds': overcommittedRestOfDayScenario.decidedTaskIds,
            'blocks': [
              _block(
                dayDate,
                taskId: 'task-board-deck',
                title: 'Prepare the board deck',
                categoryId: 'cat-leadership',
                startHour: 13,
                endHour: 14,
                endMinute: 30,
                reason: 'Honour the binding board-deck commitment.',
              ),
              _block(
                dayDate,
                taskId: 'task-release',
                title: 'Write the release notes',
                categoryId: 'cat-product',
                startHour: 14,
                startMinute: 30,
                endHour: 15,
                endMinute: 15,
                reason: 'Due today.',
              ),
              _block(
                dayDate,
                taskId: 'task-inbox',
                title: 'Clear the support inbox',
                categoryId: 'cat-support',
                startHour: 15,
                startMinute: 15,
                endHour: 15,
                endMinute: 45,
                reason: 'Selected short task.',
              ),
              _block(
                dayDate,
                taskId: 'task-interviews',
                title: 'Interview two candidates',
                categoryId: 'cat-people',
                startHour: 17,
                endHour: 19,
                reason:
                    'Uses the remaining capacity but silently overruns the '
                    'working day.',
              ),
            ],
          },
        ),
      ]);
      // Separate scripted turns are the subject: the first is rejected and
      // the workflow's forced retry consumes the second.
      // ignore: cascade_invocations
      conversationRepository.script([
        scriptedToolCall(
          id: 'surface-omissions',
          name: DayAgentToolNames.raiseDayStatus,
          args: {
            'dayId': dayId,
            'status': 'attentionNeeded',
            'reasons': ['overCommitted'],
            'note':
                'Interview two candidates and Take an afternoon walk do not '
                'fit after the board deck, release notes, and support inbox.',
          },
        ),
        scriptedToolCall(
          id: 'overcommitted-draft',
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'captureId': captureId.value,
            'decidedTaskIds': overcommittedRestOfDayScenario.decidedTaskIds,
            'blocks': [
              _block(
                dayDate,
                taskId: 'task-board-deck',
                title: 'Prepare the board deck',
                categoryId: 'cat-leadership',
                startHour: 13,
                endHour: 14,
                endMinute: 30,
                reason:
                    'Honour must-board-deck; interviews and the walk are '
                    'omitted because only 180 minutes remain.',
              ),
              _block(
                dayDate,
                taskId: 'task-release',
                title: 'Write the release notes',
                categoryId: 'cat-product',
                startHour: 14,
                startMinute: 30,
                endHour: 15,
                endMinute: 15,
                reason: 'Due today and fits after the binding commitment.',
              ),
              _block(
                dayDate,
                taskId: 'task-inbox',
                title: 'Clear the support inbox',
                categoryId: 'cat-support',
                startHour: 15,
                startMinute: 15,
                endHour: 15,
                endMinute: 45,
                reason:
                    'Short selected task; interviews and walk remain omitted.',
              ),
            ],
          },
        ),
      ]);
      final draft = await harness.realDayAgent.draftDayPlan(
        captureId: captureId,
        decidedTaskIds: overcommittedRestOfDayScenario.decidedTaskIds,
        dayDate: dayDate,
      );
      expect(
        draft.blocks.map((block) => block.taskId),
        orderedEquals(['task-board-deck', 'task-release', 'task-inbox']),
      );
      expect(
        draft.blocks.every(
          (block) => !block.end.isAfter(
            dayDate.add(
              const Duration(hours: 18),
            ),
          ),
        ),
        isTrue,
      );
      expect(conversationRepository.pendingTurns, 0);

      final events = await harness.agentRepository.getDayStatusEventsSince(
        DateTime(2020),
      );
      expect(events, hasLength(1));
      expect(events.single.status.name, 'attentionNeeded');
      expect(
        events.single.reasons.map((reason) => reason.name),
        contains('overCommitted'),
      );
      expect(events.single.note, contains('Interview two candidates'));
      expect(events.single.note, contains('Take an afternoon walk'));

      conversationRepository.script([
        scriptedToolCall(
          id: 'revised-after-escalation',
          name: DayAgentToolNames.issueDayDirective,
          args: {
            'dayId': dayId,
            'commitments': [
              {
                'id': 'must-board-deck',
                'source': 'userCommitment',
                'title': 'Prepare the board deck',
                'minutes': 90,
              },
            ],
            'capacityBudget': {
              'availableMinutes': 180,
              'alreadyScheduledMinutes': 165,
            },
            'carryOver': [
              {
                'title': 'Interview two candidates',
                'reason':
                    'Did not fit after the selected higher-priority work.',
                'taskId': 'task-interviews',
              },
              {
                'title': 'Take an afternoon walk',
                'reason': 'Did not fit in the remaining planning window.',
                'taskId': 'task-afternoon-walk',
              },
            ],
            'attentionNotes': [
              'The day agent escalated both omitted selected items.',
            ],
          },
        ),
      ]);
      await runPlannerDigest(
        harness: harness,
        coordinator: coordinator,
        dayId: dayId,
      );

      final plannerPrompt = conversationRepository.userMessages.last;
      expect(plannerPrompt, contains('<digest>'));
      expect(plannerPrompt, contains('overCommitted'));
      expect(plannerPrompt, contains('Interview two candidates'));
      expect(plannerPrompt, contains('Take an afternoon walk'));
      expect(
        conversationRepository.sendCount,
        5,
        reason:
            'Two planner digests, one parse, one rejected draft, and one '
            'corrected draft should cover the full bidirectional protocol.',
      );
    },
  );

  test(
    'closed-window draft persists an empty artifact and escalates every '
    'selected task through the real planner/day-agent protocol',
    () async {
      final lateNow = dayDate.add(const Duration(hours: 19));
      await withClock(Clock.fixed(lateNow), () async {
        final lateConversations = ScriptedConversationRepository();
        final lateHarness = createHarness(
          at: lateNow,
          conversations: lateConversations,
        );
        addTearDown(lateHarness.dispose);
        seedScenarioCorpus(
          journalDb: lateHarness.journalDb,
          scenario: overcommittedRestOfDayScenario,
          planDate: dayDate,
          journalRepository: lateHarness.journalRepository,
        );

        final coordinator = await lateHarness.dayAgentService
            .getOrCreatePlannerAgent();
        lateConversations.script([
          scriptedToolCall(
            id: 'closed-window-directive',
            name: DayAgentToolNames.issueDayDirective,
            args: {
              'dayId': dayId,
              'commitments': [
                {
                  'id': 'must-board-deck',
                  'source': 'userCommitment',
                  'title': 'Prepare the board deck',
                  'minutes': 90,
                },
              ],
              'capacityBudget': {'availableMinutes': 0},
              'attentionNotes': [
                'The configured working day is over; carry work explicitly.',
              ],
            },
          ),
        ]);
        await runPlannerDigest(
          harness: lateHarness,
          coordinator: coordinator,
          dayId: dayId,
        );

        lateConversations.script([
          scriptedToolCall(
            id: 'closed-window-status',
            name: DayAgentToolNames.raiseDayStatus,
            args: {
              'dayId': dayId,
              'status': 'attentionNeeded',
              'reasons': ['overCommitted'],
              'note':
                  'Prepare the board deck, Write the release notes, Clear the '
                  'support inbox, Interview two candidates, and Take an '
                  'afternoon walk cannot be scheduled because the working day '
                  'has ended.',
            },
          ),
          scriptedToolCall(
            id: 'closed-window-draft',
            name: DayAgentToolNames.draftDayPlan,
            args: {
              'dayId': dayId,
              'decidedTaskIds': overcommittedRestOfDayScenario.decidedTaskIds,
              'blocks': <Object?>[],
            },
          ),
        ]);
        final draft = await lateHarness.realDayAgent.draftDayPlan(
          captureId: const CaptureId(''),
          decidedTaskIds: overcommittedRestOfDayScenario.decidedTaskIds,
          dayDate: dayDate,
        );

        expect(draft.blocks, isEmpty);
        expect(draft.scheduledMinutes, 0);
        final draftJob = await lateHarness.outbox.getById(
          DayProcessingOutboxRepository.draftJobId(dayId),
        );
        expect(draftJob?.status, DayProcessingJobStatus.succeeded);
        expect(lateConversations.pendingTurns, 0);
        expect(
          lateConversations.userMessages.last,
          allOf(
            contains('"closed": true'),
            contains('must-board-deck'),
            contains('task-interviews'),
            contains('task-afternoon-walk'),
          ),
        );

        final events = await lateHarness.agentRepository
            .getDayStatusEventsSince(DateTime(2020));
        expect(events, hasLength(1));
        expect(events.single.status.name, 'attentionNeeded');
        expect(
          events.single.reasons.map((reason) => reason.name),
          contains('overCommitted'),
        );
        for (final title in [
          'Prepare the board deck',
          'Write the release notes',
          'Clear the support inbox',
          'Interview two candidates',
          'Take an afternoon walk',
        ]) {
          expect(events.single.note, contains(title));
        }
        expect(
          lateConversations.sendCount,
          2,
          reason:
              'One planner digest and one day-agent draft should complete the '
              'closed-window protocol without a forced retry.',
        );
      });
    },
  );

  test(
    'digest -> directive -> draft -> status round-trip through the real '
    'protocol chain (ADR 0032 phase 3)',
    () async {
      // ── Digest wake issues tomorrow's... today's directive ───────────────
      // The coordinator identity must exist for a digest to run under it.
      final coordinator = await harness.dayAgentService
          .getOrCreatePlannerAgent();
      conversationRepository.script([
        scriptedToolCall(
          id: 'issue-call',
          name: DayAgentToolNames.issueDayDirective,
          args: {
            'dayId': dayId,
            'commitments': [
              {
                'id': 'user-gym',
                'source': 'userCommitment',
                'title': 'Gym session',
                'minutes': 60,
              },
            ],
            'capacityBudget': {'availableMinutes': 420},
            'attentionNotes': ['Light day after two heavy ones.'],
          },
        ),
      ]);
      final digestRunKey = harness.orchestrator.enqueueManualWake(
        agentId: coordinator.agentId,
        reason: dayAgentDigestReason,
        triggerTokens: {dayAgentDigestToken(dayId)},
        workspaceKey: coordinatorDigestWorkspaceKey,
      );
      await harness.orchestrator.runCompletions.firstWhere(
        (completion) => completion.runKey == digestRunKey,
      );

      // The directive is durably persisted under its deterministic id...
      final directive =
          await harness.agentRepository.getEntity(
                dayDirectiveEntityId(dayId),
              )
              as DayDirectiveEntity?;
      expect(directive, isNotNull);
      expect(directive!.commitments.single.title, 'Gym session');
      // ...and the digest completion re-armed the next digest record.
      final nextDigest =
          await harness.agentRepository.getEntity(
                scheduledWakeRecordId(
                  coordinator.agentId,
                  workspaceKey: coordinatorDigestWorkspaceKey,
                ),
              )
              as ScheduledWakeEntity?;
      expect(nextDigest, isNotNull);
      expect(nextDigest!.status, ScheduledWakeStatus.pending);

      // ── A draft wake for the same day sees the directive ─────────────────
      conversationRepository.script([
        scriptedToolCall(
          id: 'draft-call',
          name: DayAgentToolNames.draftDayPlan,
          args: {
            'dayId': dayId,
            'blocks': [
              {
                'title': 'Gym session',
                'categoryId': 'health',
                'start': dayDate
                    .add(const Duration(hours: 17))
                    .toIso8601String(),
                'end': dayDate.add(const Duration(hours: 18)).toIso8601String(),
                'reason': 'Directive commitment user-gym.',
              },
            ],
          },
        ),
      ]);
      final draft = await harness.realDayAgent.draftDayPlan(
        captureId: const CaptureId(''),
        decidedTaskIds: const [],
        dayDate: dayDate,
      );
      expect(draft.blocks.single.title, 'Gym session');
      expect(
        conversationRepository.lastUserMessage,
        contains('<day_directive>'),
        reason:
            "The per-day draft wake must see the coordinator's directive "
            'in its prompt.',
      );
      expect(conversationRepository.lastUserMessage, contains('user-gym'));

      // ── The day agent raises status; the coordinator scan finds it ───────
      final dayAgent = await harness.agentRepository.getEntity(
        perDayAgentId(dayId),
      );
      conversationRepository.script([
        scriptedToolCall(
          id: 'status-call',
          name: DayAgentToolNames.raiseDayStatus,
          args: {
            'dayId': dayId,
            'status': 'attentionNeeded',
            'reasons': ['overCommitted'],
            'note': 'The afternoon filled up.',
          },
        ),
      ]);
      final statusRunKey = harness.orchestrator.enqueueManualWake(
        agentId: (dayAgent! as AgentIdentityEntity).agentId,
        reason: dayAgentDraftingReason,
        triggerTokens: {
          dayAgentPlanningDayToken(dayId),
          dayAgentDraftingToken(dayId),
        },
        workspaceKey: dayAgentWorkspaceKey(dayId),
      );
      await harness.orchestrator.runCompletions.firstWhere(
        (completion) => completion.runKey == statusRunKey,
      );

      // The event's createdAt is the real clock (only entity fixtures use
      // the pinned 2030 date), so scan from a past watermark.
      final events = await harness.agentRepository.getDayStatusEventsSince(
        DateTime(2020),
      );
      expect(events, hasLength(1));
      expect(events.single.dayId, dayId);
      expect(events.single.status.name, 'attentionNeeded');
      expect(events.single.agentId, perDayAgentId(dayId));
    },
  );
}

List<ChatCompletionMessageToolCall> _matchedParseCalls({
  required String message,
  required EvalScenario scenario,
  required List<String> selectedTaskIds,
}) {
  final captureId = RegExp(
    r'"captureId"\s*:\s*"([^"]+)"',
  ).firstMatch(message)?.group(1);
  if (captureId == null) {
    throw StateError('Rendered capture prompt did not contain a captureId.');
  }
  final tasks = {for (final task in scenario.tasks) task.id: task};
  return [
    scriptedToolCall(
      id: 'parse-$captureId',
      name: DayAgentToolNames.parseCaptureToItems,
      args: {
        'captureId': captureId,
        'items': [
          for (final taskId in selectedTaskIds)
            {
              'kind': 'matched',
              'title': tasks[taskId]!.title,
              'categoryId': tasks[taskId]!.categoryId,
              'confidenceScore': 0.99,
              'spokenPhrase': tasks[taskId]!.title,
              'matchedTaskId': taskId,
              'estimateMinutes': tasks[taskId]!.estimateMinutes,
            },
        ],
      },
    ),
  ];
}

Map<String, Object?> _block(
  DateTime day, {
  required String taskId,
  required String title,
  required String categoryId,
  required int startHour,
  required int endHour,
  required String reason,
  int startMinute = 0,
  int endMinute = 0,
}) => {
  'taskId': taskId,
  'title': title,
  'categoryId': categoryId,
  'start': DateTime(
    day.year,
    day.month,
    day.day,
    startHour,
    startMinute,
  ).toIso8601String(),
  'end': DateTime(
    day.year,
    day.month,
    day.day,
    endHour,
    endMinute,
  ).toIso8601String(),
  'reason': reason,
};
