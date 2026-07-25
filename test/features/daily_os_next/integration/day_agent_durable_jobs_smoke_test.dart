import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/agents/tools/day_agent_tool_names.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/ai_config_factories.dart';
import '../services/day_processing_test_db.dart';
import 'day_agent_pipeline_harness.dart';
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
/// test. (The `eval/day_planning_eval_live_test.dart` matrix runs the
/// same chain against a real model.)
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

  late ScriptedConversationRepository conversationRepository;
  late DayAgentPipelineHarness harness;

  setUp(() {
    conversationRepository = ScriptedConversationRepository();
    harness = DayAgentPipelineHarness.create(
      now: now,
      conversationRepository: conversationRepository,
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
