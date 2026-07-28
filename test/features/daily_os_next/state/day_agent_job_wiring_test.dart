import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_trigger_tokens.dart';
import 'package:lotti/features/daily_os_next/services/day_agent_job_executor.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/state/day_agent_job_wiring.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  group('dateFromDayAgentId', () {
    test('parses the ISO date out of a dayplan-prefixed id', () {
      expect(
        dateFromDayAgentId('dayplan-2026-07-22'),
        DateTime.parse('2026-07-22'),
      );
    });

    test('parses a bare ISO date without the prefix', () {
      expect(dateFromDayAgentId('2026-07-22'), DateTime.parse('2026-07-22'));
    });
  });

  group('buildDayAgentJobExecutor', () {
    late MockDayAgentService dayAgentService;
    late MockDayAgentPlanService planService;
    late MockDayAgentCaptureService captureService;
    late MockWakeOrchestrator orchestrator;
    late MockDayProcessingOutboxRepository outbox;
    late DayAgentJobExecutor executor;

    setUp(() {
      dayAgentService = MockDayAgentService();
      planService = MockDayAgentPlanService();
      captureService = MockDayAgentCaptureService();
      orchestrator = MockWakeOrchestrator();
      outbox = MockDayProcessingOutboxRepository();
      when(
        () => orchestrator.runCompletions,
      ).thenAnswer((_) => const Stream.empty());
      when(() => outbox.getById(any())).thenAnswer((_) async => null);
      executor = buildDayAgentJobExecutor(
        dayAgentService: dayAgentService,
        planService: planService,
        captureService: captureService,
        orchestrator: orchestrator,
        outbox: outbox,
      );
    });

    DayProcessingJob buildJob(DayProcessingPayload payload) => DayProcessingJob(
      id: 'job-1',
      status: DayProcessingJobStatus.queued,
      dayId: 'dayplan-2026-07-22',
      payload: payload,
      createdAt: DateTime.utc(2026, 7, 22),
      updatedAt: DateTime.utc(2026, 7, 22),
      requestedAt: DateTime.utc(2026, 7, 22),
      nextAttemptAt: DateTime.utc(2026, 7, 22),
      attempts: 0,
      generation: 0,
    );

    test(
      'resolveAgentId parses the day and delegates to getOrCreateDayAgentForDate',
      () async {
        when(
          () => dayAgentService.getOrCreateDayAgentForDate(
            DateTime.parse('2026-07-22'),
          ),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            id: 'day_agent:dayplan-2026-07-22',
            agentId: 'day_agent:dayplan-2026-07-22',
            kind: AgentKinds.dayAgent,
          ),
        );

        final agentId = await executor.resolveAgentId('dayplan-2026-07-22');

        expect(agentId, 'day_agent:dayplan-2026-07-22');
      },
    );

    test(
      'enqueueWake for a parseCapture job carries the capture-submitted '
      'reason and token',
      () {
        when(
          () => orchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
            workspaceKey: any(named: 'workspaceKey'),
            supersede: any(named: 'supersede'),
          ),
        ).thenReturn('run-key-1');

        final runKey = executor.enqueueWake((
          agentId: 'agent-1',
          dayId: 'dayplan-2026-07-22',
          job: buildJob(const ParseCapturePayload(captureId: 'cap-1')),
        ));

        expect(runKey, 'run-key-1');
        final captured = verify(
          () => orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: captureAny(named: 'reason'),
            triggerTokens: captureAny(named: 'triggerTokens'),
            workspaceKey: 'day:dayplan-2026-07-22',
            supersede: false,
          ),
        ).captured;
        expect(captured[0], dayAgentCaptureSubmittedReason);
        expect(captured[1], {
          dayAgentCaptureSubmittedToken('cap-1'),
          dayAgentProcessingJobToken('job-1'),
        });
      },
    );

    test(
      'enqueueWake for a draftPlan job carries the drafting reason plus '
      'day/capture/decided-task/decided-item tokens',
      () {
        when(
          () => orchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
            workspaceKey: any(named: 'workspaceKey'),
            supersede: any(named: 'supersede'),
          ),
        ).thenReturn('run-key-2');

        executor.enqueueWake((
          agentId: 'agent-1',
          dayId: 'dayplan-2026-07-22',
          job: buildJob(
            const DraftPlanPayload(
              captureId: 'cap-1',
              decidedTaskIds: ['task-1', ' '],
              decidedCaptureItemIds: ['item-1', ''],
            ),
          ),
        ));

        final captured = verify(
          () => orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: captureAny(named: 'reason'),
            triggerTokens: captureAny(named: 'triggerTokens'),
            workspaceKey: 'day:dayplan-2026-07-22',
            supersede: false,
          ),
        ).captured;
        expect(captured[0], dayAgentDraftingReason);
        expect(captured[1], {
          dayAgentPlanningDayToken('dayplan-2026-07-22'),
          dayAgentDraftingToken('dayplan-2026-07-22'),
          dayAgentCaptureSubmittedToken('cap-1'),
          dayAgentDecidedTaskToken('task-1'),
          dayAgentDecidedCaptureItemToken('item-1'),
          dayAgentProcessingJobToken('job-1'),
        });
      },
    );

    test(
      'enqueueWake for a draftPlan job with no captureId/decided ids '
      'carries only the day/drafting tokens',
      () {
        when(
          () => orchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
            workspaceKey: any(named: 'workspaceKey'),
            supersede: any(named: 'supersede'),
          ),
        ).thenReturn('run-key-3');

        executor.enqueueWake((
          agentId: 'agent-1',
          dayId: 'dayplan-2026-07-22',
          job: buildJob(const DraftPlanPayload()),
        ));

        final captured = verify(
          () => orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: captureAny(named: 'reason'),
            triggerTokens: captureAny(named: 'triggerTokens'),
            workspaceKey: 'day:dayplan-2026-07-22',
            supersede: false,
          ),
        ).captured;
        expect(captured[1], {
          dayAgentPlanningDayToken('dayplan-2026-07-22'),
          dayAgentDraftingToken('dayplan-2026-07-22'),
          dayAgentProcessingJobToken('job-1'),
        });
      },
    );

    test(
      'enqueueWake for a refinePlan job carries the refine reason plus '
      'day/capture tokens',
      () {
        when(
          () => orchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
            workspaceKey: any(named: 'workspaceKey'),
            supersede: any(named: 'supersede'),
          ),
        ).thenReturn('run-key-4');

        executor.enqueueWake((
          agentId: 'agent-1',
          dayId: 'dayplan-2026-07-22',
          job: buildJob(
            const RefinePlanPayload(transcriptCaptureId: 'cap-refine'),
          ),
        ));

        final captured = verify(
          () => orchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: captureAny(named: 'reason'),
            triggerTokens: captureAny(named: 'triggerTokens'),
            workspaceKey: 'day:dayplan-2026-07-22',
            supersede: false,
          ),
        ).captured;
        expect(captured[0], dayAgentRefineReason);
        expect(captured[1], {
          dayAgentPlanningDayToken('dayplan-2026-07-22'),
          dayAgentRefineToken('dayplan-2026-07-22'),
          dayAgentCaptureSubmittedToken('cap-refine'),
          dayAgentProcessingJobToken('job-1'),
        });
      },
    );

    test(
      'enqueueWake throws for a transcribeAudio job — this executor never '
      'claims transcription work',
      () {
        expect(
          () => executor.enqueueWake((
            agentId: 'agent-1',
            dayId: 'dayplan-2026-07-22',
            job: buildJob(
              const TranscribeAudioPayload(
                activityEntryId: 'entry-1',
                recordingSessionId: 'session-1',
                audioId: 'audio-1',
                audioPath: '/tmp/a.m4a',
              ),
            ),
          )),
          throwsA(isA<StateError>()),
        );
      },
    );

    test(
      'hasCompletedCaptureParse delegates to the capture service',
      () async {
        when(
          () => captureService.hasCompletedCaptureParse('cap-empty'),
        ).thenAnswer((_) async => true);

        expect(await executor.hasCompletedCaptureParse('cap-empty'), isTrue);
        verify(
          () => captureService.hasCompletedCaptureParse('cap-empty'),
        ).called(1);
      },
    );

    test(
      'draftPlanUpdatedAt returns null when the day has no plan yet',
      () async {
        when(
          () => planService.draftPlanForDay(
            agentId: 'agent-1',
            dayId: 'dayplan-2026-07-22',
          ),
        ).thenAnswer((_) async => null);

        expect(
          await executor.draftPlanUpdatedAt('agent-1', 'dayplan-2026-07-22'),
          isNull,
        );
      },
    );

    test(
      'draftPlanUpdatedAt carries the plan run key, not just its timestamp',
      () async {
        // The executor decides on provenance, so the wiring must surface the
        // run key — handing back a bare timestamp would silently downgrade
        // the artifact check to the time window it replaced.
        final updatedAt = DateTime.utc(2026, 7, 22, 10);
        when(
          () => planService.draftPlanForDay(
            agentId: 'agent-1',
            dayId: 'dayplan-2026-07-22',
          ),
        ).thenAnswer(
          (_) async => makeTestDayPlan(
            id: 'day_agent_plan:dayplan-2026-07-22',
            agentId: 'agent-1',
            dayId: 'dayplan-2026-07-22',
            planDate: DateTime.utc(2026, 7, 22),
            updatedAt: updatedAt,
          ).copyWith(runKey: 'run-77'),
        );

        final provenance = await executor.draftPlanUpdatedAt(
          'agent-1',
          'dayplan-2026-07-22',
        );

        expect(provenance!.updatedAt, updatedAt);
        expect(provenance.runKey, 'run-77');
      },
    );

    test(
      'pendingDiffCreatedSince returns the id of the first diff created at '
      'or after the given instant',
      () async {
        final since = DateTime.utc(2026, 7, 22, 9);
        when(
          () => planService.pendingPlanDiffsForDay(
            agentId: 'agent-1',
            dayId: 'dayplan-2026-07-22',
          ),
        ).thenAnswer((_) async => const []);

        expect(
          await executor.pendingDiffCreatedSince(
            'agent-1',
            'dayplan-2026-07-22',
            since,
          ),
          isNull,
        );
      },
    );

    test(
      'pendingDiffForRuns matches only diffs whose runKey belongs to the '
      'job, newest-first via pendingPlanDiffsForDay',
      () async {
        ChangeSetEntity diff(String id, String runKey) =>
            AgentDomainEntity.changeSet(
                  id: id,
                  agentId: 'agent-1',
                  taskId: 'day_agent_plan:dayplan-2026-07-22',
                  threadId: 'thread-1',
                  runKey: runKey,
                  status: ChangeSetStatus.pending,
                  items: const [],
                  createdAt: DateTime.utc(2026, 7, 22),
                  vectorClock: null,
                )
                as ChangeSetEntity;
        when(
          () => planService.pendingPlanDiffsForDay(
            agentId: 'agent-1',
            dayId: 'dayplan-2026-07-22',
          ),
        ).thenAnswer(
          (_) async => [diff('diff-a', 'sibling-key'), diff('diff-b', 'mine')],
        );

        expect(
          await executor.pendingDiffForRuns(
            'agent-1',
            'dayplan-2026-07-22',
            {'mine'},
          ),
          'diff-b',
        );
        expect(
          await executor.pendingDiffForRuns(
            'agent-1',
            'dayplan-2026-07-22',
            {'unknown'},
          ),
          isNull,
        );
      },
    );

    test('recordRunKey delegates to the outbox repository', () async {
      when(
        () => outbox.recordRunKey(
          jobId: any(named: 'jobId'),
          runKey: any(named: 'runKey'),
        ),
      ).thenAnswer((_) async => null);

      await executor.recordRunKey('job-1', 'run-key-9');

      verify(
        () => outbox.recordRunKey(jobId: 'job-1', runKey: 'run-key-9'),
      ).called(1);
    });

    test(
      'hasPendingDraftWork reads the deterministic draft job and reports '
      'true only for statuses that can still produce a plan',
      () async {
        DayProcessingJob draftJobWith(DayProcessingJobStatus status) =>
            buildJob(const DraftPlanPayload()).copyWith(status: status);

        Future<bool> withStatus(DayProcessingJobStatus? status) {
          when(
            () => outbox.getById('draft_dayplan-2026-07-22'),
          ).thenAnswer(
            (_) async => status == null ? null : draftJobWith(status),
          );
          return executor.hasPendingDraftWork('dayplan-2026-07-22');
        }

        expect(await withStatus(null), isFalse);
        expect(await withStatus(DayProcessingJobStatus.queued), isTrue);
        expect(await withStatus(DayProcessingJobStatus.running), isTrue);
        expect(
          await withStatus(DayProcessingJobStatus.waitingForNetwork),
          isTrue,
        );
        expect(
          await withStatus(DayProcessingJobStatus.waitingForUser),
          isFalse,
        );
        expect(await withStatus(DayProcessingJobStatus.failed), isFalse);
        expect(await withStatus(DayProcessingJobStatus.succeeded), isFalse);
        expect(await withStatus(DayProcessingJobStatus.cancelled), isFalse);
      },
    );
  });
}
