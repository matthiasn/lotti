// ignore_for_file: avoid_redundant_argument_values

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/classes/day_plan.dart';
import 'package:lotti/classes/entity_definitions.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_plan_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_reconcile_models.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_slots.dart';
import 'package:lotti/features/daily_os_next/logic/day_agent_models.dart';
import 'package:lotti/features/daily_os_next/logic/mock_day_agent.dart';
import 'package:lotti/features/daily_os_next/logic/real_day_agent.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_job.dart';
import 'package:lotti/features/daily_os_next/services/day_processing_outbox_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../test_data/test_data.dart';
import '../../agents/test_data/entity_factories.dart';
import '../../categories/test_utils.dart';

final _asOf = DateTime(2026, 5, 25, 9);

DayPlanEntity buildDayPlan({
  required String agentId,
  required String dayId,
  DateTime? updatedAt,
  List<PlannedBlock> blocks = const <PlannedBlock>[],
  int capacityMinutes = 480,
  int scheduledMinutes = 0,
}) {
  final timestamp = updatedAt ?? _asOf;
  return AgentDomainEntity.dayPlan(
        id: 'day_agent_plan:$dayId',
        agentId: agentId,
        dayId: dayId,
        planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
        data: DayPlanData(
          planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
          status: const DayPlanStatus.draft(),
          plannedBlocks: blocks,
        ),
        capacityMinutes: capacityMinutes,
        scheduledMinutes: scheduledMinutes,
        createdAt: timestamp,
        updatedAt: timestamp,
        vectorClock: null,
      )
      as DayPlanEntity;
}

ChangeSetEntity buildChangeSet({
  required String agentId,
  String id = 'diff-001',
  List<ChangeItem> items = const <ChangeItem>[],
}) {
  return AgentDomainEntity.changeSet(
        id: id,
        agentId: agentId,
        taskId: 'day_agent_plan:${dayAgentIdForDate(_asOf)}',
        threadId: 'thread-001',
        runKey: 'run-001',
        status: ChangeSetStatus.pending,
        items: items,
        createdAt: _asOf,
        vectorClock: null,
      )
      as ChangeSetEntity;
}

PlanDiff buildDiff({String id = 'diff-001'}) => PlanDiff(
  id: id,
  transcript: 'move the gym',
  changes: const <PlanDiffChange>[],
  updatedPlan: DraftPlan(
    dayDate: _asOf,
    blocks: const <TimeBlock>[],
    bands: const <EnergyBand>[],
    capacityMinutes: 480,
    scheduledMinutes: 0,
  ),
);

/// Minimal in-memory fake behind a [MockDayProcessingOutboxRepository]:
/// real enqueue/coalesce/claim semantics are already covered end-to-end in
/// `day_processing_outbox_repository_test.dart`, and the real,
/// file-backed repository's I/O does not resolve under `fakeAsync` (which
/// only fakes Timers and the microtask queue, not real dart:io callbacks —
/// see the fake_async package docs). A mock resolving via plain `Future`s
/// keeps the cancellation/soft-cap tests exercising [RealDayAgent] itself
/// fakeAsync-compatible while still exercising the real
/// [DayProcessingOutboxRepository] enqueue methods' *call shape* via
/// mocktail verification.
class _FakeOutboxState {
  _FakeOutboxState(this.mock) {
    when(() => mock.changes).thenAnswer((_) => _changes.stream);
    when(() => mock.getById(any())).thenAnswer(
      (inv) async => _jobs[inv.positionalArguments[0] as String],
    );
    // ignore: unnecessary_lambdas
    when(() => mock.getAll()).thenAnswer((_) async => all);
    when(
      () => mock.enqueueDraftPlan(
        dayId: any(named: 'dayId'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((inv) async {
      final dayId = inv.namedArguments[#dayId] as String;
      final payload = inv.namedArguments[#payload] as DraftPlanPayload;
      final id = DayProcessingOutboxRepository.draftJobId(dayId);
      final job = DayProcessingJob(
        id: id,
        status: DayProcessingJobStatus.queued,
        dayId: dayId,
        payload: payload,
        createdAt: now,
        updatedAt: now,
        requestedAt: now,
        nextAttemptAt: now,
        attempts: 0,
        generation: (_jobs[id]?.generation ?? -1) + 1,
      );
      _jobs[id] = job;
      _changes.add(null);
      return job;
    });
    when(
      () => mock.enqueueRefinePlan(
        dayId: any(named: 'dayId'),
        transcriptCaptureId: any(named: 'transcriptCaptureId'),
      ),
    ).thenAnswer((inv) async {
      final dayId = inv.namedArguments[#dayId] as String;
      final transcriptCaptureId =
          inv.namedArguments[#transcriptCaptureId] as String?;
      final id = 'refine_${dayId}_${_jobs.length}';
      final job = DayProcessingJob(
        id: id,
        status: DayProcessingJobStatus.queued,
        dayId: dayId,
        payload: RefinePlanPayload(transcriptCaptureId: transcriptCaptureId),
        createdAt: now,
        updatedAt: now,
        requestedAt: now,
        nextAttemptAt: now,
        attempts: 0,
        generation: 0,
      );
      _jobs[id] = job;
      _changes.add(null);
      return job;
    });
  }

  final MockDayProcessingOutboxRepository mock;
  final Map<String, DayProcessingJob> _jobs = {};
  final _changes = StreamController<void>.broadcast();
  DateTime now = _asOf;

  void completeJob(String jobId, {String? resultEntityId}) {
    final job = _jobs[jobId]!;
    _jobs[jobId] = job.copyWith(
      status: DayProcessingJobStatus.succeeded,
      resultEntityId: resultEntityId,
      completedAt: now,
    );
    _changes.add(null);
  }

  void failJob(
    String jobId, {
    required DayProcessingFailureClass failureClass,
    String error = 'wake failed',
  }) {
    final job = _jobs[jobId]!;
    final status = failureClass == DayProcessingFailureClass.setupRequired
        ? DayProcessingJobStatus.waitingForUser
        : DayProcessingJobStatus.failed;
    _jobs[jobId] = job.copyWith(
      status: status,
      lastFailureClass: failureClass,
      lastError: error,
    );
    _changes.add(null);
  }

  List<DayProcessingJob> get all => _jobs.values.toList(growable: false);
}

/// Shared five-mock + adapter scaffolding used by every group in this file.
class _TestBench {
  _TestBench._({required this.fallback})
    : captureService = MockDayAgentCaptureService(),
      planService = MockDayAgentPlanService(),
      dayAgentService = MockDayAgentService(),
      journalDb = MockJournalDb(),
      outbox = MockDayProcessingOutboxRepository() {
    fakeOutbox = _FakeOutboxState(outbox);
  }

  factory _TestBench.create({MockDayAgent? fallback}) =>
      _TestBench._(fallback: fallback ?? MockDayAgent());

  final MockDayAgentCaptureService captureService;
  final MockDayAgentPlanService planService;
  final MockDayAgentService dayAgentService;
  final MockJournalDb journalDb;
  final MockDayAgent fallback;
  final MockDayProcessingOutboxRepository outbox;
  late final _FakeOutboxState fakeOutbox;
  int nudgeCalls = 0;

  late final RealDayAgent adapter = RealDayAgent(
    captureService: captureService,
    planService: planService,
    dayAgentService: dayAgentService,
    journalDb: journalDb,
    mockFallback: fallback,
    outbox: outbox,
    nudgeProcessing: () => nudgeCalls++,
  );

  /// Simulates the processor completing a `draftPlan`/`refinePlan` job.
  /// Fires the fake outbox's `changes` stream, which is what wakes
  /// [RealDayAgent]'s awaiter.
  Future<void> completeJob(String jobId, {String? resultEntityId}) async {
    fakeOutbox.completeJob(jobId, resultEntityId: resultEntityId);
  }

  /// Simulates a terminal processor failure for [jobId].
  Future<void> failJob(
    String jobId, {
    required DayProcessingFailureClass failureClass,
    String error = 'wake failed',
  }) async {
    fakeOutbox.failJob(jobId, failureClass: failureClass, error: error);
  }
}

/// Records the arguments handed to the two void mocked tools so the
/// delegation tests can prove the adapter forwards them verbatim to the
/// fallback (the mock's own implementations are silent no-ops, so there is
/// no return value to assert on).
class _RecordingFallbackAgent extends MockDayAgent {
  _RecordingFallbackAgent()
    : super(
        triageLatency: Duration.zero,
        summarizeLatency: Duration.zero,
        pendingLatency: Duration.zero,
      );

  ({DateTime forDate, String text, ReflectionSource source})? reflection;
  ({String taskId, CarryoverAction action, DateTime? when})? carryover;

  @override
  Future<void> recordReflection({
    required DateTime forDate,
    required String text,
    required ReflectionSource source,
  }) async {
    reflection = (forDate: forDate, text: text, source: source);
    await super.recordReflection(forDate: forDate, text: text, source: source);
  }

  @override
  Future<void> recordCarryoverDecision({
    required String taskId,
    required CarryoverAction action,
    DateTime? when,
  }) async {
    carryover = (taskId: taskId, action: action, when: when);
    await super.recordCarryoverDecision(
      taskId: taskId,
      action: action,
      when: when,
    );
  }
}

void main() {
  setUpAll(registerAllFallbackValues);

  group('RealDayAgent.summarizeRecentPatterns', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'returns an empty list when no day-agent exists for the date',
      () async {
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => null,
        );

        final cards = await bench.adapter.summarizeRecentPatterns(asOf: _asOf);

        expect(cards, isEmpty);
        verifyNever(
          () => bench.planService.summarizeRecentPatterns(
            agentId: any(named: 'agentId'),
            asOf: any(named: 'asOf'),
            lookbackDays: any(named: 'lookbackDays'),
          ),
        );
      },
    );

    test('projects backend cards onto UI LearningCard shape', () async {
      const agentId = 'day-agent-001';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.summarizeRecentPatterns(
          agentId: agentId,
          asOf: _asOf,
          lookbackDays: 7,
        ),
      ).thenAnswer(
        (_) async => [
          DayAgentLearningCard(
            id: 'yesterday',
            overline: 'Yesterday',
            summary: 'You drafted four blocks.',
            bullets: const [
              DayAgentLearningBullet(
                text: 'Carry forward the demo prep block.',
                tone: DayAgentLearningBulletTone.positive,
              ),
            ],
          ),
          DayAgentLearningCard(
            id: 'gentle_nudge',
            overline: 'Gentle nudge',
            summary: 'Protect a transition before piling on more work.',
            kind: 'nudge',
            bullets: const [
              DayAgentLearningBullet(
                text: 'Leave at least one buffer unassigned.',
                tone: DayAgentLearningBulletTone.warning,
              ),
            ],
          ),
        ],
      );

      final cards = await bench.adapter.summarizeRecentPatterns(asOf: _asOf);

      expect(cards, hasLength(2));
      expect(cards[0].id, 'yesterday');
      expect(cards[0].overline, 'Yesterday');
      expect(cards[0].summary, 'You drafted four blocks.');
      expect(cards[0].kind, LearningCardKind.standard);
      expect(cards[0].bullets, hasLength(1));
      expect(
        cards[0].bullets.single.text,
        'Carry forward the demo prep block.',
      );
      expect(cards[0].bullets.single.tone, LearningBulletTone.positive);

      expect(cards[1].id, 'gentle_nudge');
      expect(cards[1].kind, LearningCardKind.nudge);
      expect(cards[1].bullets.single.tone, LearningBulletTone.warning);
    });

    test('forwards a custom lookbackDays argument', () async {
      const agentId = 'day-agent-002';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.summarizeRecentPatterns(
          agentId: any(named: 'agentId'),
          asOf: any(named: 'asOf'),
          lookbackDays: any(named: 'lookbackDays'),
        ),
      ).thenAnswer((_) async => const <DayAgentLearningCard>[]);

      await bench.adapter.summarizeRecentPatterns(
        asOf: _asOf,
        lookbackDays: 14,
      );

      verify(
        () => bench.planService.summarizeRecentPatterns(
          agentId: agentId,
          asOf: _asOf,
          lookbackDays: 14,
        ),
      ).called(1);
    });
  });

  group('RealDayAgent.draftDayPlan', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'enqueues a durable draft job, awaits its completion via the outbox, '
      'and projects the persisted plan onto DraftPlan',
      () async {
        const agentId = 'day-agent-001';
        final dayId = dayAgentIdForDate(_asOf);

        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer(
          (_) async => buildDayPlan(
            agentId: agentId,
            dayId: dayId,
            blocks: [
              PlannedBlock(
                id: 'block_1',
                categoryId: 'work',
                startTime: _asOf.add(const Duration(hours: 1)),
                endTime: _asOf.add(const Duration(hours: 2)),
                title: 'Demo prep',
                reason: 'High-energy window',
              ),
            ],
          ),
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final future = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const ['t_1'],
          decidedCaptureItemIds: const ['parsed_1'],
          dayDate: _asOf,
        );
        await pumpEventQueue();

        final jobId = DayProcessingOutboxRepository.draftJobId(dayId);
        final job = await bench.outbox.getById(jobId);
        expect(job, isNotNull);
        expect(
          (job!.payload as DraftPlanPayload).decidedTaskIds,
          ['t_1'],
        );
        expect(
          (job.payload as DraftPlanPayload).decidedCaptureItemIds,
          ['parsed_1'],
        );
        expect(bench.nudgeCalls, greaterThanOrEqualTo(1));

        await bench.completeJob(jobId);
        final result = await future;

        expect(result.blocks, hasLength(1));
        expect(result.blocks.single.title, 'Demo prep');
        expect(result.blocks.single.type, TimeBlockType.ai);
        expect(result.blocks.single.reason, 'High-energy window');
        expect(result.capacityMinutes, 480);
        expect(result.scheduledMinutes, 60);
        expect(result.state, DayState.drafted);

        // Standalone block (no taskId) still becomes one agenda item so
        // the Agenda surface mirrors the Day timeline.
        expect(result.agendaItems, hasLength(1));
        expect(result.agendaItems.single.title, 'Demo prep');
        expect(result.agendaItems.single.linkedBlockIds, ['block_1']);
        expect(result.agendaItems.single.taskId, isNull);
      },
    );

    test(
      'a repeated request for the same day coalesces onto the same durable '
      'job instead of enqueueing a second one',
      () async {
        const agentId = 'day-agent-coalesce';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer(
          (_) async => buildDayPlan(agentId: agentId, dayId: dayId),
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final firstFuture = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();
        final secondFuture = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_2'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();

        final jobId = DayProcessingOutboxRepository.draftJobId(dayId);
        expect((await bench.outbox.getAll()).map((j) => j.id), [jobId]);

        await bench.completeJob(jobId);
        final results = await Future.wait([firstFuture, secondFuture]);

        // Both callers observe the same completed plan.
        expect(results[0].state, DayState.drafted);
        expect(results[1].state, DayState.drafted);
      },
    );

    test(
      'two overlapping outbox change events for the same terminal job do '
      'not throw "Future already completed"',
      () async {
        const agentId = 'day-agent-race';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer(
          (_) async => buildDayPlan(agentId: agentId, dayId: dayId),
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final future = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();

        final jobId = DayProcessingOutboxRepository.draftJobId(dayId);
        // Two change events fired back to back — both listener callbacks
        // race to `await outbox.getById(jobId)` before either resolves, so
        // both can observe the job as terminal. Without the re-check
        // immediately before `completer.complete`, the second one throws.
        bench.fakeOutbox
          ..completeJob(jobId)
          ..completeJob(jobId);

        final result = await future;
        expect(result.state, DayState.drafted);
      },
    );

    test(
      'throws DayAgentInteractionException when the job reaches a terminal '
      'failure',
      () async {
        const agentId = 'day-agent-fail';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );

        final future = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();
        await bench.failJob(
          DayProcessingOutboxRepository.draftJobId(dayId),
          failureClass: DayProcessingFailureClass.deterministic,
          error: 'ambiguous day resolution',
        );

        await expectLater(
          future,
          throwsA(
            isA<DayAgentInteractionException>().having(
              (e) => e.message,
              'message',
              contains('ambiguous day resolution'),
            ),
          ),
        );
      },
    );

    test(
      'a setup-required failure surfaces a Settings-pointing message',
      () async {
        const agentId = 'day-agent-setup';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );

        final future = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();
        await bench.failJob(
          DayProcessingOutboxRepository.draftJobId(dayId),
          failureClass: DayProcessingFailureClass.setupRequired,
          error: 'no template configured',
        );

        await expectLater(
          future,
          throwsA(
            isA<DayAgentInteractionException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('Setup required'),
                contains('no template configured'),
              ),
            ),
          ),
        );
      },
    );

    test(
      'throws when the job succeeds but no day agent exists for the date '
      'afterwards',
      () async {
        final dayId = dayAgentIdForDate(_asOf);
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        final future = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();
        await bench.completeJob(
          DayProcessingOutboxRepository.draftJobId(dayId),
        );

        await expectLater(
          future,
          throwsA(
            isA<DayAgentInteractionException>().having(
              (e) => e.message,
              'message',
              contains('No day agent exists for $dayId'),
            ),
          ),
        );
      },
    );

    test(
      'throws when drafting completed but the day has no drafted plan',
      () async {
        const agentId = 'day-agent-no-plan';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => null);

        final future = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap_1'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();
        await bench.completeJob(
          DayProcessingOutboxRepository.draftJobId(dayId),
        );

        await expectLater(
          future,
          throwsA(
            isA<DayAgentInteractionException>().having(
              (e) => e.message,
              'message',
              contains('Drafting completed but $dayId has no drafted plan'),
            ),
          ),
        );
      },
    );

    test(
      'cancellation via isCancelled leaves the durable job running and '
      'throws without touching the outbox',
      () {
        const agentId = 'day-agent-cancel';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );

        Object? caught;
        fakeAsync((async) {
          withClock(async.getClock(_asOf), () {
            unawaited(() async {
              try {
                await bench.adapter.draftDayPlan(
                  captureId: const CaptureId('cap_1'),
                  decidedTaskIds: const [],
                  dayDate: _asOf,
                  isCancelled: () => true,
                );
              } catch (e) {
                caught = e;
              }
            }());
          });
          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();
        });

        expect(caught, isA<DayAgentInteractionException>());
        expect(
          (caught! as DayAgentInteractionException).message,
          contains('cancelled by caller'),
        );
      },
    );

    test(
      'a soft-cap timeout surfaces a background-progress message without '
      'cancelling the job',
      () {
        const agentId = 'day-agent-softcap';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );

        Object? caught;
        fakeAsync((async) {
          withClock(async.getClock(_asOf), () {
            unawaited(() async {
              try {
                await bench.adapter.draftDayPlan(
                  captureId: const CaptureId('cap_1'),
                  decidedTaskIds: const [],
                  dayDate: _asOf,
                );
              } catch (e) {
                caught = e;
              }
            }());
          });
          async
            ..flushMicrotasks()
            ..elapse(const Duration(minutes: 11))
            ..flushMicrotasks();
        });

        expect(caught, isA<DayAgentInteractionException>());
        expect(
          (caught! as DayAgentInteractionException).message,
          contains('Activity timeline'),
        );
      },
    );
  });

  group('RealDayAgent.resolveDiffItems', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('acceptDiff forwards selected item indices', () async {
      const agentId = 'day-agent-001';
      final dayId = dayAgentIdForDate(_asOf);
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.acceptPlanDiff(
          agentId: any(named: 'agentId'),
          changeSetId: any(named: 'changeSetId'),
          itemIndices: any(named: 'itemIndices'),
        ),
      ).thenAnswer((_) async => buildChangeSet(agentId: agentId));
      when(
        () => bench.planService.draftPlanForDay(
          agentId: agentId,
          dayId: dayId,
        ),
      ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));

      final result = await bench.adapter.acceptDiff(
        buildDiff(),
        itemIndices: [1],
      );

      final captured =
          verify(
                () => bench.planService.acceptPlanDiff(
                  agentId: agentId,
                  changeSetId: 'diff-001',
                  itemIndices: captureAny(named: 'itemIndices'),
                ),
              ).captured.single
              as List<int>;
      expect(captured, [1]);
      expect(result.dayDate, _asOf);
    });

    test(
      'revertDiff forwards selected item indices and refetches the plan',
      () async {
        const agentId = 'day-agent-001';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.revertPlanDiff(
            agentId: any(named: 'agentId'),
            changeSetId: any(named: 'changeSetId'),
            itemIndices: any(named: 'itemIndices'),
          ),
        ).thenAnswer((_) async => buildChangeSet(agentId: agentId));
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));

        final result = await bench.adapter.revertDiff(
          diff: buildDiff(),
          originalPlan: buildDiff().updatedPlan,
          itemIndices: [0],
        );

        final captured =
            verify(
                  () => bench.planService.revertPlanDiff(
                    agentId: agentId,
                    changeSetId: 'diff-001',
                    itemIndices: captureAny(named: 'itemIndices'),
                  ),
                ).captured.single
                as List<int>;
        expect(captured, [0]);
        expect(result.dayDate, _asOf);
        verify(
          () =>
              bench.planService.draftPlanForDay(agentId: agentId, dayId: dayId),
        ).called(1);
      },
    );
  });

  group('RealDayAgent.commitDay', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'calls commitDay on the plan service and projects the result',
      () async {
        const agentId = 'day-agent-001';
        final dayDate = DateTime(_asOf.year, _asOf.month, _asOf.day);
        final committedAt = dayDate.add(const Duration(hours: 9));
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.commitDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.dayPlan(
                    id: 'day_agent_plan:${dayAgentIdForDate(dayDate)}',
                    agentId: agentId,
                    dayId: dayAgentIdForDate(dayDate),
                    planDate: dayDate,
                    data: DayPlanData(
                      planDate: dayDate,
                      status: DayPlanStatus.committed(committedAt: committedAt),
                      plannedBlocks: [
                        PlannedBlock(
                          id: 'block_1',
                          categoryId: 'work',
                          startTime: dayDate.add(const Duration(hours: 9)),
                          endTime: dayDate.add(const Duration(hours: 10)),
                          title: 'Focus block',
                          state: PlannedBlockState.committed,
                        ),
                      ],
                    ),
                    scheduledMinutes: 60,
                    createdAt: dayDate,
                    updatedAt: committedAt,
                    vectorClock: null,
                  )
                  as DayPlanEntity,
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final plan = DraftPlan(
          dayDate: dayDate,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 60,
        );

        final result = await bench.adapter.commitDay(plan);

        expect(result.state, DayState.committed);
        expect(result.blocks, hasLength(1));
        expect(result.blocks.single.state, TimeBlockState.committed);
        verify(
          () => bench.planService.commitDay(
            agentId: agentId,
            dayId: dayAgentIdForDate(dayDate),
          ),
        ).called(1);
      },
    );

    test(
      'throws DayAgentInteractionException when no day-agent exists',
      () async {
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        final plan = DraftPlan(
          dayDate: _asOf,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 0,
        );

        await expectLater(
          bench.adapter.commitDay(plan),
          throwsA(isA<DayAgentInteractionException>()),
        );
        verifyNever(
          () => bench.planService.commitDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        );
      },
    );
  });

  group('RealDayAgent.renameBlock', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'calls renameBlock on the plan service and projects the result',
      () async {
        const agentId = 'day-agent-001';
        final dayDate = DateTime(_asOf.year, _asOf.month, _asOf.day);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.renameBlock(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
            blockId: any(named: 'blockId'),
            title: any(named: 'title'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.dayPlan(
                    id: 'day_agent_plan:${dayAgentIdForDate(dayDate)}',
                    agentId: agentId,
                    dayId: dayAgentIdForDate(dayDate),
                    planDate: dayDate,
                    data: DayPlanData(
                      planDate: dayDate,
                      status: const DayPlanStatus.draft(),
                      plannedBlocks: [
                        PlannedBlock(
                          id: 'block_1',
                          categoryId: 'life',
                          startTime: dayDate.add(const Duration(hours: 12)),
                          endTime: dayDate.add(const Duration(hours: 13)),
                          title: 'Lunch with Sarah',
                        ),
                      ],
                    ),
                    scheduledMinutes: 60,
                    createdAt: dayDate,
                    updatedAt: dayDate,
                    vectorClock: null,
                  )
                  as DayPlanEntity,
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final plan = DraftPlan(
          dayDate: dayDate,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 60,
        );

        final result = await bench.adapter.renameBlock(
          plan: plan,
          blockId: 'block_1',
          title: 'Lunch with Sarah',
        );

        expect(result.blocks.single.title, 'Lunch with Sarah');
        verify(
          () => bench.planService.renameBlock(
            agentId: agentId,
            dayId: dayAgentIdForDate(dayDate),
            blockId: 'block_1',
            title: 'Lunch with Sarah',
          ),
        ).called(1);
      },
    );

    test(
      'throws DayAgentInteractionException when no day-agent exists',
      () async {
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        final plan = DraftPlan(
          dayDate: _asOf,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 0,
        );

        await expectLater(
          bench.adapter.renameBlock(
            plan: plan,
            blockId: 'block_1',
            title: 'Renamed',
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
        verifyNever(
          () => bench.planService.renameBlock(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
            blockId: any(named: 'blockId'),
            title: any(named: 'title'),
          ),
        );
      },
    );
  });

  group('RealDayAgent.editBlock', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('calls the plan service and projects the updated range', () async {
      const agentId = 'day-agent-001';
      const category = DayAgentCategory(
        id: 'life',
        name: 'Life',
        colorHex: '5ED4B7',
      );
      final dayDate = DateTime(_asOf.year, _asOf.month, _asOf.day);
      final start = dayDate.add(const Duration(hours: 10, minutes: 15));
      final end = dayDate.add(const Duration(hours: 11, minutes: 45));
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.editBlock(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
          blockId: any(named: 'blockId'),
          start: any(named: 'start'),
          end: any(named: 'end'),
          title: any(named: 'title'),
          categoryId: any(named: 'categoryId'),
        ),
      ).thenAnswer(
        (_) async =>
            AgentDomainEntity.dayPlan(
                  id: 'day_agent_plan:${dayAgentIdForDate(dayDate)}',
                  agentId: agentId,
                  dayId: dayAgentIdForDate(dayDate),
                  planDate: dayDate,
                  data: DayPlanData(
                    planDate: dayDate,
                    status: const DayPlanStatus.draft(),
                    plannedBlocks: [
                      PlannedBlock(
                        id: 'block_1',
                        categoryId: 'life',
                        startTime: start,
                        endTime: end,
                        title: 'Lunch with Sarah',
                      ),
                    ],
                  ),
                  scheduledMinutes: 90,
                  createdAt: dayDate,
                  updatedAt: dayDate,
                  vectorClock: null,
                )
                as DayPlanEntity,
      );
      when(
        () => bench.journalDb.getCategoryById(any()),
      ).thenAnswer((_) async => null);
      final plan = DraftPlan(
        dayDate: dayDate,
        blocks: const [],
        bands: const [],
        capacityMinutes: 480,
        scheduledMinutes: 60,
      );

      final result = await bench.adapter.editBlock(
        plan: plan,
        blockId: 'block_1',
        start: start,
        end: end,
        title: 'Lunch with Sarah',
        category: category,
      );

      expect(result.blocks.single.start, start);
      expect(result.blocks.single.end, end);
      expect(result.scheduledMinutes, 90);
      verify(
        () => bench.planService.editBlock(
          agentId: agentId,
          dayId: dayAgentIdForDate(dayDate),
          blockId: 'block_1',
          start: start,
          end: end,
          title: 'Lunch with Sarah',
          categoryId: 'life',
        ),
      ).called(1);
    });

    test('throws when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);
      final plan = DraftPlan(
        dayDate: _asOf,
        blocks: const [],
        bands: const [],
        capacityMinutes: 480,
        scheduledMinutes: 0,
      );

      await expectLater(
        bench.adapter.editBlock(
          plan: plan,
          blockId: 'block_1',
          start: DateTime(2026, 5, 25, 10),
          end: DateTime(2026, 5, 25, 11),
        ),
        throwsA(isA<DayAgentInteractionException>()),
      );
      verifyNever(
        () => bench.planService.editBlock(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
          blockId: any(named: 'blockId'),
          start: any(named: 'start'),
          end: any(named: 'end'),
        ),
      );
    });
  });

  group('RealDayAgent.submitCapture', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    CaptureEntity buildCapture(String id, String agentId) {
      return AgentDomainEntity.capture(
            id: id,
            agentId: agentId,
            transcript: 'hello world',
            capturedAt: _asOf,
            createdAt: _asOf,
            vectorClock: null,
          )
          as CaptureEntity;
    }

    test(
      'resolves the day owner and forwards transcript + audioId',
      () async {
        // ADR 0032: submitCapture lazily resolves the day's owning agent via
        // getOrCreateDayAgentForDate (which creates the per-day identity on
        // first activity for a clean day) and forwards the capture to it.
        final agentId = perDayAgentId('dayplan-2026-05-28');
        final dayDate = DateTime(2026, 5, 28);
        when(
          () => bench.dayAgentService.getOrCreateDayAgentForDate(dayDate),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.submitCapture(
            agentId: any(named: 'agentId'),
            transcript: any(named: 'transcript'),
            capturedAt: any(named: 'capturedAt'),
            dayId: any(named: 'dayId'),
            audioRef: any(named: 'audioRef'),
          ),
        ).thenAnswer((_) async => buildCapture('cap-1', agentId));

        final captureId = await bench.adapter.submitCapture(
          transcript: 'hello world',
          capturedAt: _asOf,
          dayDate: dayDate,
          audioId: 'audio-1',
        );

        expect(captureId.value, 'cap-1');
        verify(
          () => bench.dayAgentService.getOrCreateDayAgentForDate(dayDate),
        ).called(1);
        verify(
          () => bench.captureService.submitCapture(
            agentId: agentId,
            transcript: 'hello world',
            capturedAt: _asOf,
            dayId: 'dayplan-2026-05-28',
            audioRef: 'audio-1',
          ),
        ).called(1);
      },
    );
  });

  group('RealDayAgent.currentPlanForDate / deletePlanForDate', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('currentPlanForDate returns null when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);

      final plan = await bench.adapter.currentPlanForDate(_asOf);
      expect(plan, isNull);
      verifyNever(
        () => bench.planService.draftPlanForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });

    test(
      'currentPlanForDate returns null when the plan service yields no plan',
      () async {
        const agentId = 'day-agent-C';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        final plan = await bench.adapter.currentPlanForDate(_asOf);
        expect(plan, isNull);
      },
    );

    test(
      'currentPlanForDate projects an existing plan onto DraftPlan',
      () async {
        const agentId = 'day-agent-D';
        final dayId = dayAgentIdForDate(_asOf);
        final dayDate = DateTime(_asOf.year, _asOf.month, _asOf.day);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.dayPlan(
                    id: 'day_agent_plan:$dayId',
                    agentId: agentId,
                    dayId: dayId,
                    planDate: dayDate,
                    data: DayPlanData(
                      planDate: dayDate,
                      status: const DayPlanStatus.draft(),
                    ),
                    createdAt: _asOf,
                    updatedAt: _asOf,
                    vectorClock: null,
                  )
                  as DayPlanEntity,
        );

        final plan = await bench.adapter.currentPlanForDate(_asOf);
        expect(plan, isNotNull);
        expect(plan!.dayDate, _asOf);
        expect(plan.state, DayState.drafted);
      },
    );

    test('deletePlanForDate returns false when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);

      final removed = await bench.adapter.deletePlanForDate(_asOf);
      expect(removed, isFalse);
      verifyNever(
        () => bench.planService.deletePlanForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });

    test('deletePlanForDate delegates to the plan service', () async {
      const agentId = 'day-agent-E';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.deletePlanForDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer((_) async => true);

      final removed = await bench.adapter.deletePlanForDate(_asOf);
      expect(removed, isTrue);
      verify(
        () => bench.planService.deletePlanForDay(
          agentId: agentId,
          dayId: dayAgentIdForDate(_asOf),
        ),
      ).called(1);
    });
  });

  group('RealDayAgent.parseCaptureToItems / projection helpers', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    ParsedItemEntity buildParsedItem({
      String id = 'parsed-1',
      String? categoryId,
      String? matchedTaskId,
    }) {
      return AgentDomainEntity.parsedItem(
            id: id,
            agentId: 'agent',
            captureId: 'cap',
            kind: ParsedItemKind.newTask,
            title: 'Item title',
            categoryId: categoryId ?? '',
            confidence: ParsedItemConfidence.high,
            confidenceScore: 0.9,
            spokenPhrase: 'spoken',
            matchedTaskId: matchedTaskId,
            estimateMinutes: 30,
            timeAnchor: 'before 11am',
            proposedUpdate: 'finish soon',
            createdAt: _asOf,
            vectorClock: null,
          )
          as ParsedItemEntity;
    }

    test(
      'projects parsed entities and looks up matched task titles + categories',
      () async {
        final category = CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          name: 'Work',
          color: '#FFAA00',
        );
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [
            buildParsedItem(
              id: 'parsed-a',
              categoryId: 'cat-1',
              matchedTaskId: testTask.meta.id,
            ),
          ],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-1'),
        ).thenAnswer((_) async => category);
        when(
          () => bench.journalDb.journalEntityById(testTask.meta.id),
        ).thenAnswer((_) async => testTask);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items, hasLength(1));
        final item = items.single;
        expect(item.id, 'parsed-a');
        expect(item.matchedTaskTitle, testTask.data.title);
        expect(item.category.id, 'cat-1');
        expect(item.category.colorHex, 'FFAA00');
        expect(item.estimateMinutes, 30);
        expect(item.timeAnchor, 'before 11am');
        expect(item.proposedUpdate, 'finish soon');
      },
    );

    test(
      'falls back to the uncategorised category when categoryId is empty',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer((_) async => [buildParsedItem()]);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items.single.category.id, 'unknown');
        verifyNever(() => bench.journalDb.getCategoryById(any()));
      },
    );

    test(
      'falls back to the uncategorised id when the category row is missing',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [buildParsedItem(categoryId: 'cat-missing')],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-missing'),
        ).thenAnswer((_) async => null);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        // This is the only exercise of the private `DayAgentCategory.copyWith`
        // extension (it has no public/test seam), so assert its full contract
        // here: `id` is overridden with the requested category id while the
        // fallback's `name` and `colorHex` are carried through unchanged.
        expect(items.single.category.id, 'cat-missing');
        expect(items.single.category.name, 'Uncategorised');
        expect(items.single.category.colorHex, '5ED4B7');
      },
    );

    test(
      'caches resolved categories so repeated parses hit the DB once per id',
      () async {
        final category = CategoryTestUtils.createTestCategory(
          id: 'cat-1',
          name: 'Work',
        );
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [
            buildParsedItem(id: 'p-1', categoryId: 'cat-1'),
            buildParsedItem(id: 'p-2', categoryId: 'cat-1'),
          ],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-1'),
        ).thenAnswer((_) async => category);

        await bench.adapter.parseCaptureToItems(const CaptureId('cap'));
        await bench.adapter.parseCaptureToItems(const CaptureId('cap'));

        verify(() => bench.journalDb.getCategoryById('cat-1')).called(1);
      },
    );

    test(
      'leaves matchedTaskTitle null when the linked entity is not a task',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [buildParsedItem(matchedTaskId: 'not-a-task')],
        );
        when(
          () => bench.journalDb.journalEntityById('not-a-task'),
        ).thenAnswer((_) async => null);

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items.single.matchedTaskTitle, isNull);
      },
    );

    test(
      'trims a too-long colour string to 6 chars and replaces blanks',
      () async {
        when(
          () => bench.captureService.parsedItemsForCapture(any()),
        ).thenAnswer(
          (_) async => [
            buildParsedItem(id: 'p-long', categoryId: 'cat-long'),
            buildParsedItem(id: 'p-empty', categoryId: 'cat-empty'),
          ],
        );
        when(
          () => bench.journalDb.getCategoryById('cat-long'),
        ).thenAnswer(
          (_) async => CategoryTestUtils.createTestCategory(
            id: 'cat-long',
            name: 'Long',
            color: '#ABCDEF1234',
          ),
        );
        when(
          () => bench.journalDb.getCategoryById('cat-empty'),
        ).thenAnswer(
          (_) async => CategoryTestUtils.createTestCategory(
            id: 'cat-empty',
            name: 'Empty',
            color: '',
          ),
        );

        final items = await bench.adapter.parseCaptureToItems(
          const CaptureId('cap'),
        );
        expect(items[0].category.colorHex, 'ABCDEF');
        expect(items[1].category.colorHex, '5ED4B7');
      },
    );
  });

  group('RealDayAgent.surfacePendingDecisions', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('returns empty when no day-agent exists for the date', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);

      final items = await bench.adapter.surfacePendingDecisions(forDate: _asOf);
      expect(items, isEmpty);
      verifyNever(
        () => bench.captureService.surfacePendingDecisions(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      );
    });

    test(
      'projects all pending-kind enums into PendingItemReason values',
      () async {
        const agentId = 'agent-pending';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.surfacePendingDecisions(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async => [
            DayAgentPendingItem(
              taskId: 't-overdue',
              title: 'Overdue',
              kind: DayAgentPendingKind.overdue,
              status: 'OPEN',
              categoryId: null,
              due: _asOf.subtract(const Duration(days: 3)),
            ),
            const DayAgentPendingItem(
              taskId: 't-inprogress',
              title: 'In progress',
              kind: DayAgentPendingKind.inProgress,
              status: 'IN_PROGRESS',
              categoryId: null,
            ),
            const DayAgentPendingItem(
              taskId: 't-recurring',
              title: 'Recurring',
              kind: DayAgentPendingKind.missedRecurring,
              status: 'OPEN',
              categoryId: null,
            ),
            const DayAgentPendingItem(
              taskId: 't-today',
              title: 'Due today',
              kind: DayAgentPendingKind.dueToday,
              status: 'OPEN',
              categoryId: null,
            ),
          ],
        );

        final items = await withClock(Clock.fixed(_asOf), () {
          return bench.adapter.surfacePendingDecisions(forDate: _asOf);
        });
        expect(items.map((i) => i.reason), [
          PendingItemReason.overdue,
          PendingItemReason.inProgress,
          PendingItemReason.missedRecurring,
          PendingItemReason.dueToday,
        ]);
        // overdueByDays is only populated for the overdue reason with a
        // non-null due date.
        expect(items[0].overdueByDays, 3);
        expect(items[0].referenceDate, isNull);
        expect(items[1].overdueByDays, isNull);
        expect(items[3].overdueByDays, isNull);
      },
    );

    test(
      'computes overdue age and label reference from the selected plan date',
      () async {
        const agentId = 'agent-future-pending';
        final selectedDate = DateTime(2026, 5, 30, 9);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.surfacePendingDecisions(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer(
          (_) async => [
            DayAgentPendingItem(
              taskId: 't-overdue',
              title: 'Overdue',
              kind: DayAgentPendingKind.overdue,
              status: 'OPEN',
              categoryId: null,
              due: DateTime(2026, 5, 25),
            ),
            const DayAgentPendingItem(
              taskId: 't-due',
              title: 'Due',
              kind: DayAgentPendingKind.dueToday,
              status: 'OPEN',
              categoryId: null,
            ),
          ],
        );

        final items = await withClock(Clock.fixed(_asOf), () {
          return bench.adapter.surfacePendingDecisions(forDate: selectedDate);
        });

        expect(items[0].overdueByDays, 5);
        expect(items[0].referenceDate, DateTime(2026, 5, 30));
        expect(items[1].referenceDate, DateTime(2026, 5, 30));
      },
    );

    test(
      'defaults forDate to clock.now and queries with that date',
      () async {
        const agentId = 'agent-default-date';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.captureService.surfacePendingDecisions(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => const <DayAgentPendingItem>[]);

        await bench.adapter.surfacePendingDecisions();

        verify(() => bench.dayAgentService.getDayAgentForDate(any())).called(1);
        verify(
          () => bench.captureService.surfacePendingDecisions(
            agentId: agentId,
            dayId: any(named: 'dayId'),
          ),
        ).called(1);
      },
    );
  });

  group(
    'RealDayAgent.applyTriage / linkCapturePhraseToTask / breakCaptureLink',
    () {
      late _TestBench bench;

      setUp(() => bench = _TestBench.create());

      test(
        'applyTriage resolves the planner identity, forwards the action name '
        'and only includes deferTo when deferring',
        () async {
          const agentId = dailyOsPlannerAgentId;
          when(
            () => bench.dayAgentService.getOrCreatePlannerAgent(),
          ).thenAnswer(
            (_) async => makeTestIdentity(
              id: agentId,
              agentId: agentId,
              kind: AgentKinds.dayAgent,
            ),
          );
          when(
            () => bench.captureService.applyTriage(
              agentId: any(named: 'agentId'),
              taskId: any(named: 'taskId'),
              action: any(named: 'action'),
              deferTo: any(named: 'deferTo'),
            ),
          ).thenAnswer((_) async => testTask);

          final immediate = await bench.adapter.applyTriage(
            taskId: 't-1',
            action: TriageAction.today,
          );
          expect(immediate.deferredTo, isNull);
          expect(immediate.action, TriageAction.today);
          verify(
            () => bench.captureService.applyTriage(
              agentId: agentId,
              taskId: 't-1',
              action: 'today',
            ),
          ).called(1);

          final deferred = await bench.adapter.applyTriage(
            taskId: 't-2',
            action: TriageAction.defer,
            deferTo: _asOf,
          );
          expect(deferred.deferredTo, _asOf);
          expect(deferred.action, TriageAction.defer);
          verify(
            () => bench.captureService.applyTriage(
              agentId: agentId,
              taskId: 't-2',
              action: 'defer',
              deferTo: _asOf,
            ),
          ).called(1);
        },
      );

      test(
        'linkCapturePhraseToTask projects the updated parsed item',
        () async {
          final updated =
              AgentDomainEntity.parsedItem(
                    id: 'parsed-z',
                    agentId: 'agent',
                    captureId: 'cap',
                    kind: ParsedItemKind.matched,
                    title: 'Title',
                    categoryId: 'cat-z',
                    confidence: ParsedItemConfidence.high,
                    confidenceScore: 0.9,
                    matchedTaskId: testTask.meta.id,
                    createdAt: _asOf,
                    vectorClock: null,
                  )
                  as ParsedItemEntity;
          when(
            () => bench.captureService.linkCapturePhraseToTask(
              captureItemId: any(named: 'captureItemId'),
              taskId: any(named: 'taskId'),
            ),
          ).thenAnswer((_) async => updated);
          when(
            () => bench.journalDb.getCategoryById('cat-z'),
          ).thenAnswer((_) async => null);
          when(
            () => bench.journalDb.journalEntityById(testTask.meta.id),
          ).thenAnswer((_) async => testTask);

          final item = await bench.adapter.linkCapturePhraseToTask(
            parsedItemId: 'parsed-z',
            taskId: testTask.meta.id,
          );
          expect(item.id, 'parsed-z');
          expect(item.kind, ParsedItemKind.matched);
          expect(item.matchedTaskTitle, testTask.data.title);
        },
      );

      test('breakCaptureLink projects the updated parsed item', () async {
        final updated =
            AgentDomainEntity.parsedItem(
                  id: 'parsed-broken',
                  agentId: 'agent',
                  captureId: 'cap',
                  kind: ParsedItemKind.newTask,
                  title: 'Title',
                  categoryId: '',
                  confidence: ParsedItemConfidence.low,
                  confidenceScore: 0,
                  createdAt: _asOf,
                  vectorClock: null,
                )
                as ParsedItemEntity;
        when(
          () => bench.captureService.breakCaptureLink(any()),
        ).thenAnswer((_) async => updated);

        final item = await bench.adapter.breakCaptureLink('parsed-broken');
        expect(item.kind, ParsedItemKind.newTask);
        expect(item.matchedTaskId, isNull);
      });
    },
  );

  group('RealDayAgent.proposePlanDiff', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    DraftPlan buildCurrentPlan() {
      return DraftPlan(
        dayDate: _asOf,
        blocks: [
          TimeBlock(
            id: 'block-existing',
            title: 'Existing',
            start: _asOf.add(const Duration(hours: 1)),
            end: _asOf.add(const Duration(hours: 2)),
            type: TimeBlockType.ai,
            state: TimeBlockState.drafted,
            category: const DayAgentCategory(
              id: 'cat-x',
              name: 'Cat',
              colorHex: 'ABCDEF',
            ),
          ),
        ],
        bands: const [],
        capacityMinutes: 480,
        scheduledMinutes: 60,
      );
    }

    test(
      'throws when no day-agent exists for the plan date',
      () async {
        when(
          () => bench.dayAgentService.getDayAgentForDate(any()),
        ).thenAnswer((_) async => null);

        await expectLater(
          bench.adapter.proposePlanDiff(
            currentPlan: buildCurrentPlan(),
            voiceTranscript: 'move it',
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
        expect(await bench.outbox.getAll(), isEmpty);
      },
    );

    test('throws when no plan exists yet for the day', () async {
      const agentId = 'agent-prop-1';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.draftPlanForDay(
          agentId: agentId,
          dayId: dayAgentIdForDate(_asOf),
        ),
      ).thenAnswer((_) async => null);

      await expectLater(
        bench.adapter.proposePlanDiff(
          currentPlan: buildCurrentPlan(),
          voiceTranscript: 'move it',
        ),
        throwsA(isA<DayAgentInteractionException>()),
      );
      expect(await bench.outbox.getAll(), isEmpty);
    });

    test(
      'persists the transcript capture, enqueues a durable refine job, and '
      'projects the resulting diff once it completes',
      () async {
        const agentId = 'agent-prop-2';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);
        when(
          () => bench.dayAgentService.persistRefineCapture(
            agentId: agentId,
            dayId: dayId,
            transcript: 'reshape the morning',
          ),
        ).thenAnswer((_) async => 'refine_capture:cap-x');

        final newDiff = buildChangeSet(
          agentId: agentId,
          items: [
            ChangeItem(
              toolName: 'move_block',
              args: {
                'blockId': 'block-existing',
                'toStart': _asOf
                    .add(const Duration(hours: 3))
                    .toIso8601String(),
                'toEnd': _asOf.add(const Duration(hours: 4)).toIso8601String(),
                'reason': 'Open up morning focus.',
                'title': 'Existing',
              },
              humanSummary: 'Move Existing to 3pm',
            ),
            const ChangeItem(
              toolName: 'add_block',
              args: <String, dynamic>{
                'categoryId': '',
                'reason': 'Add a stretch slot.',
                'title': 'Stretch',
              },
              humanSummary: 'Add Stretch block',
            ),
            const ChangeItem(
              toolName: 'drop_block',
              args: <String, dynamic>{'blockId': 'block-existing'},
              humanSummary: 'Drop existing block',
            ),
            const ChangeItem(
              toolName: 'unknown_tool',
              args: <String, dynamic>{},
              humanSummary: 'Should be skipped',
            ),
          ],
        );
        when(
          () => bench.planService.pendingPlanDiffsForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => [newDiff]);

        final future = bench.adapter.proposePlanDiff(
          currentPlan: buildCurrentPlan(),
          voiceTranscript: 'reshape the morning',
        );
        await pumpEventQueue();

        final jobs = await bench.outbox.getAll();
        expect(jobs, hasLength(1));
        expect(jobs.single.kind, DayProcessingJobKind.refinePlan);
        expect(
          (jobs.single.payload as RefinePlanPayload).transcriptCaptureId,
          'refine_capture:cap-x',
        );

        await bench.completeJob(jobs.single.id, resultEntityId: newDiff.id);
        final diff = await future;

        expect(diff.id, newDiff.id);
        expect(diff.transcript, 'reshape the morning');
        // unknown_tool was skipped; three valid changes survive.
        expect(diff.changes, hasLength(3));
        final move = diff.changes.firstWhere(
          (c) => c.kind == PlanDiffChangeKind.moved,
        );
        expect(move.toStart, isNotNull);
        expect(move.toEnd, isNotNull);
        expect(move.fromStart, isNotNull);
        final added = diff.changes.firstWhere(
          (c) => c.kind == PlanDiffChangeKind.added,
        );
        // Empty categoryId falls back to the uncategorised category.
        expect(added.category.id, 'unknown');
        final dropped = diff.changes.firstWhere(
          (c) => c.kind == PlanDiffChangeKind.dropped,
        );
        expect(dropped.affectedBlockId, 'block-existing');
      },
    );

    test(
      'throws when refining completed but no pending diff matches the '
      'job result',
      () async {
        const agentId = 'agent-prop-no-diff';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));
        when(
          () => bench.dayAgentService.persistRefineCapture(
            agentId: agentId,
            dayId: dayId,
            transcript: 'reshape the morning',
          ),
        ).thenAnswer((_) async => 'refine_capture:cap-y');
        when(
          () => bench.planService.pendingPlanDiffsForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => const []);

        final future = bench.adapter.proposePlanDiff(
          currentPlan: buildCurrentPlan(),
          voiceTranscript: 'reshape the morning',
        );
        await pumpEventQueue();

        final jobs = await bench.outbox.getAll();
        await bench.completeJob(jobs.single.id, resultEntityId: 'diff-missing');

        await expectLater(
          future,
          throwsA(
            isA<DayAgentInteractionException>().having(
              (e) => e.message,
              'message',
              contains('Refining completed but $dayId has no pending diff'),
            ),
          ),
        );
      },
    );

    test(
      'a blank transcript enqueues the refine job without a capture id',
      () async {
        const agentId = 'agent-prop-blank';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));
        when(
          () => bench.dayAgentService.persistRefineCapture(
            agentId: agentId,
            dayId: dayId,
            transcript: '',
          ),
        ).thenAnswer((_) async => null);

        final future = bench.adapter.proposePlanDiff(
          currentPlan: buildCurrentPlan(),
          voiceTranscript: '',
        );
        await pumpEventQueue();

        final jobs = await bench.outbox.getAll();
        expect(
          (jobs.single.payload as RefinePlanPayload).transcriptCaptureId,
          isNull,
        );

        // Settle the awaiter's Timer so it doesn't leak past the test.
        await bench.failJob(
          jobs.single.id,
          failureClass: DayProcessingFailureClass.deterministic,
        );
        await expectLater(
          future,
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
    );

    test(
      'throws DayAgentInteractionException when the job reaches a terminal '
      'failure',
      () async {
        const agentId = 'agent-prop-timeout';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer((_) async => buildDayPlan(agentId: agentId, dayId: dayId));
        when(
          () => bench.dayAgentService.persistRefineCapture(
            agentId: agentId,
            dayId: dayId,
            transcript: 'no change comes',
          ),
        ).thenAnswer((_) async => 'refine_capture:cap-y');

        final future = bench.adapter.proposePlanDiff(
          currentPlan: buildCurrentPlan(),
          voiceTranscript: 'no change comes',
        );
        await pumpEventQueue();
        final jobs = await bench.outbox.getAll();
        await bench.failJob(
          jobs.single.id,
          failureClass: DayProcessingFailureClass.timeout,
        );

        await expectLater(
          future,
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
    );
  });

  group('RealDayAgent.acceptDiff / revertDiff error branches', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test('acceptDiff throws when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);
      await expectLater(
        bench.adapter.acceptDiff(buildDiff()),
        throwsA(isA<DayAgentInteractionException>()),
      );
    });

    test(
      'acceptDiff throws when the plan disappears after the accept',
      () async {
        const agentId = 'agent-accept';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.acceptPlanDiff(
            agentId: any(named: 'agentId'),
            changeSetId: any(named: 'changeSetId'),
            itemIndices: any(named: 'itemIndices'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.changeSet(
                    id: 'diff',
                    agentId: agentId,
                    taskId: 'day_agent_plan:${dayAgentIdForDate(_asOf)}',
                    threadId: 'th',
                    runKey: 'rk',
                    status: ChangeSetStatus.resolved,
                    items: const [],
                    createdAt: _asOf,
                    vectorClock: null,
                  )
                  as ChangeSetEntity,
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          bench.adapter.acceptDiff(buildDiff()),
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
    );

    test('revertDiff throws when no day-agent exists', () async {
      when(
        () => bench.dayAgentService.getDayAgentForDate(any()),
      ).thenAnswer((_) async => null);
      await expectLater(
        bench.adapter.revertDiff(
          diff: buildDiff(),
          originalPlan: buildDiff().updatedPlan,
        ),
        throwsA(isA<DayAgentInteractionException>()),
      );
    });

    test(
      'revertDiff throws when the plan disappears after the revert',
      () async {
        const agentId = 'agent-revert';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.revertPlanDiff(
            agentId: any(named: 'agentId'),
            changeSetId: any(named: 'changeSetId'),
            itemIndices: any(named: 'itemIndices'),
          ),
        ).thenAnswer(
          (_) async =>
              AgentDomainEntity.changeSet(
                    id: 'diff',
                    agentId: agentId,
                    taskId: 'day_agent_plan:${dayAgentIdForDate(_asOf)}',
                    threadId: 'th',
                    runKey: 'rk',
                    status: ChangeSetStatus.resolved,
                    items: const [],
                    createdAt: _asOf,
                    vectorClock: null,
                  )
                  as ChangeSetEntity,
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => null);

        await expectLater(
          bench.adapter.revertDiff(
            diff: buildDiff(),
            originalPlan: buildDiff().updatedPlan,
          ),
          throwsA(isA<DayAgentInteractionException>()),
        );
      },
    );
  });

  group('RealDayAgent projection / agenda / state mapping', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    DayPlanEntity buildPlanEntity({
      required String agentId,
      required DayPlanStatus status,
      List<PlannedBlock> blocks = const [],
      List<DayAgentEnergyBand> bands = const [],
    }) {
      final dayId = dayAgentIdForDate(_asOf);
      return AgentDomainEntity.dayPlan(
            id: 'day_agent_plan:$dayId',
            agentId: agentId,
            dayId: dayId,
            planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
            data: DayPlanData(
              planDate: DateTime(_asOf.year, _asOf.month, _asOf.day),
              status: status,
              plannedBlocks: blocks,
            ),
            energyBands: bands,
            createdAt: _asOf,
            updatedAt: _asOf,
            vectorClock: null,
          )
          as DayPlanEntity;
    }

    test(
      'commitDay projects every block type/state + energy band and groups '
      'agenda items per taskId',
      () async {
        const agentId = 'agent-projection';
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        final blocks = [
          PlannedBlock(
            id: 'b-ai',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 1)),
            endTime: _asOf.add(const Duration(hours: 2)),
            title: 'AI block',
            taskId: 'task-1',
          ),
          PlannedBlock(
            id: 'b-cal',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 2)),
            endTime: _asOf.add(const Duration(hours: 3)),
            title: 'Cal block',
            type: PlannedBlockType.cal,
            state: PlannedBlockState.inProgress,
            taskId: 'task-1',
          ),
          PlannedBlock(
            id: 'b-buffer',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 3)),
            endTime: _asOf.add(const Duration(hours: 3, minutes: 15)),
            title: '',
            type: PlannedBlockType.buffer,
            state: PlannedBlockState.completed,
            taskId: 'task-1',
          ),
          PlannedBlock(
            id: 'b-manual',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 4)),
            endTime: _asOf.add(const Duration(hours: 5)),
            type: PlannedBlockType.manual,
            state: PlannedBlockState.committed,
          ),
          PlannedBlock(
            id: 'b-dropped',
            categoryId: 'c1',
            startTime: _asOf.add(const Duration(hours: 6)),
            endTime: _asOf.add(const Duration(hours: 7)),
            title: 'Dropped',
            state: PlannedBlockState.dropped,
            taskId: 'task-1',
          ),
        ];

        final entity = buildPlanEntity(
          agentId: agentId,
          status: DayPlanStatus.committed(committedAt: _asOf),
          blocks: blocks,
          bands: [
            DayAgentEnergyBand(
              start: _asOf,
              end: _asOf.add(const Duration(hours: 4)),
              level: DayAgentEnergyLevel.high,
              label: 'HIGH',
            ),
            DayAgentEnergyBand(
              start: _asOf.add(const Duration(hours: 4)),
              end: _asOf.add(const Duration(hours: 6)),
              level: DayAgentEnergyLevel.low,
              label: 'LOW',
            ),
            DayAgentEnergyBand(
              start: _asOf.add(const Duration(hours: 6)),
              end: _asOf.add(const Duration(hours: 9)),
              level: DayAgentEnergyLevel.secondWind,
              label: 'SECOND',
            ),
          ],
        );

        when(
          () => bench.planService.commitDay(
            agentId: any(named: 'agentId'),
            dayId: any(named: 'dayId'),
          ),
        ).thenAnswer((_) async => entity);

        final plan = DraftPlan(
          dayDate: _asOf,
          blocks: const [],
          bands: const [],
          capacityMinutes: 480,
          scheduledMinutes: 0,
        );

        final result = await bench.adapter.commitDay(plan);

        expect(result.state, DayState.committed);
        expect(result.bands.map((b) => b.level), [
          EnergyLevel.high,
          EnergyLevel.low,
          EnergyLevel.secondWind,
        ]);
        expect(result.blocks.map((b) => b.type), [
          TimeBlockType.ai,
          TimeBlockType.cal,
          TimeBlockType.buffer,
          TimeBlockType.manual,
          TimeBlockType.ai,
        ]);
        expect(result.blocks.map((b) => b.state), [
          TimeBlockState.drafted,
          TimeBlockState.inProgress,
          TimeBlockState.completed,
          TimeBlockState.committed,
          TimeBlockState.dropped,
        ]);
        // Untitled fallback applied to the buffer with empty title.
        expect(result.blocks[2].title, 'Untitled');
        // Buffers still reserve day capacity; dropped blocks do not.
        expect(result.scheduledMinutes, 60 + 60 + 15 + 60);

        // Agenda: task-1 groups its non-buffer non-dropped blocks; the
        // standalone manual block becomes its own agenda item. The
        // in-progress block forces the task agenda item to inProgress.
        final taskAgenda = result.agendaItems.firstWhere(
          (a) => a.taskId == 'task-1',
        );
        expect(taskAgenda.linkedBlockIds, ['b-ai', 'b-cal']);
        expect(taskAgenda.state, AgendaItemState.inProgress);
        expect(taskAgenda.totalEstimateMinutes, 60 + 60);

        final manualAgenda = result.agendaItems.firstWhere(
          (a) => a.id == 'agenda_b-manual',
        );
        expect(manualAgenda.taskId, isNull);
        expect(manualAgenda.linkedBlockIds, ['b-manual']);
        // A committed block does not collapse to "done" — only `completed`
        // blocks do. Manual block remains open.
        expect(manualAgenda.state, AgendaItemState.open);
      },
    );

    test('legacy "agreed" status collapses to DayState.committed', () async {
      const agentId = 'agent-agreed';
      when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
        (_) async => makeTestIdentity(
          id: agentId,
          agentId: agentId,
          kind: AgentKinds.dayAgent,
        ),
      );
      when(
        () => bench.planService.commitDay(
          agentId: any(named: 'agentId'),
          dayId: any(named: 'dayId'),
        ),
      ).thenAnswer(
        (_) async => buildPlanEntity(
          agentId: agentId,
          status: DayPlanStatus.agreed(agreedAt: _asOf),
        ),
      );

      final plan = DraftPlan(
        dayDate: _asOf,
        blocks: const [],
        bands: const [],
        capacityMinutes: 480,
        scheduledMinutes: 0,
      );
      final result = await bench.adapter.commitDay(plan);
      expect(result.state, DayState.committed);
    });
  });

  group('RealDayAgent helpers + mocked delegations', () {
    late _TestBench bench;

    setUp(
      () => bench = _TestBench.create(
        fallback: MockDayAgent(
          parseLatency: Duration.zero,
          pendingLatency: Duration.zero,
          triageLatency: Duration.zero,
          draftLatency: Duration.zero,
          summarizeLatency: Duration.zero,
          clock: () => _asOf,
        ),
      ),
    );

    // Each mocked tool gets its own focused delegation test. Asserting the
    // *exact scripted payload* of the real `MockDayAgent` (not just the
    // return type) is what proves the adapter forwarded to the genuine
    // fallback rather than swallowing the call or returning a stub.

    test(
      'surfaceShutdownData forwards to the fallback and returns its scripted '
      'completed/carryover/metrics verbatim',
      () async {
        final shutdown = await bench.adapter.surfaceShutdownData(
          forDate: _asOf,
        );

        expect(
          shutdown.completed.map((c) => c.taskId),
          ['t_deck_review', 't_morning_run'],
        );
        expect(shutdown.completed.first.durationMinutes, 95);
        expect(
          shutdown.carryover.map((c) => c.taskId),
          ['t_onboarding_doc', 't_invoices'],
        );
        expect(
          shutdown.carryover.first.suggestedTarget,
          '→ tomorrow morning',
        );
        expect(shutdown.metrics.focusMinutes, 215);
        expect(shutdown.metrics.flowSessions, 3);
        expect(shutdown.metrics.energyScore, 7.4);
      },
    );

    test(
      'generateTomorrowNote forwards to the fallback and returns its scripted '
      'note verbatim',
      () async {
        final note = await bench.adapter.generateTomorrowNote(forDate: _asOf);

        expect(note.maturity, 1);
        expect(note.body, contains('Onboarding doc'));
        expect(note.body, startsWith('You started the Onboarding doc'));
      },
    );

    test(
      'surfaceTaskCorpus forwards the state filter to the fallback so only '
      'matching scripted rows come back',
      () async {
        // Unfiltered call returns the full scripted corpus.
        final all = await bench.adapter.surfaceTaskCorpus();
        expect(all, hasLength(7));

        // The filter argument must reach the fallback: an overdue filter
        // narrows to the single scripted overdue row (the dentist task).
        final overdue = await bench.adapter.surfaceTaskCorpus(
          stateFilter: TaskCorpusState.overdue,
        );
        expect(overdue.map((i) => i.id), ['t_dentist']);
        expect(
          overdue.every((i) => i.state == TaskCorpusState.overdue),
          isTrue,
        );
      },
    );

    test(
      'recordReflection forwards forDate/text/source verbatim to the fallback',
      () async {
        final recording = _RecordingFallbackAgent();
        final adapter = _TestBench.create(fallback: recording).adapter;

        await adapter.recordReflection(
          forDate: _asOf,
          text: 'looked back on a sharp morning',
          source: ReflectionSource.voice,
        );

        expect(recording.reflection?.forDate, _asOf);
        expect(recording.reflection?.text, 'looked back on a sharp morning');
        expect(recording.reflection?.source, ReflectionSource.voice);
        // The carryover sibling tool was not invoked by this call.
        expect(recording.carryover, isNull);
      },
    );

    test(
      'recordCarryoverDecision forwards taskId/action/when verbatim to the '
      'fallback',
      () async {
        final recording = _RecordingFallbackAgent();
        final adapter = _TestBench.create(fallback: recording).adapter;
        final when = DateTime(2026, 5, 27, 9);

        await adapter.recordCarryoverDecision(
          taskId: 'task-x',
          action: CarryoverAction.pickDate,
          when: when,
        );

        expect(recording.carryover?.taskId, 'task-x');
        expect(recording.carryover?.action, CarryoverAction.pickDate);
        expect(recording.carryover?.when, when);
        // The reflection sibling tool was not invoked by this call.
        expect(recording.reflection, isNull);
      },
    );

    test('DayAgentInteractionException stringifies with its message', () {
      const ex = DayAgentInteractionException('oops');
      expect(ex.toString(), contains('oops'));
      expect(ex.message, 'oops');
    });
  });

  group('RealDayAgent.draftDayPlan re-attach after cancellation', () {
    late _TestBench bench;

    setUp(() => bench = _TestBench.create());

    test(
      'a caller that gave up leaves the durable job running; a fresh '
      'request for the same day attaches to and observes its completion',
      () async {
        const agentId = 'agent-reattach';
        final dayId = dayAgentIdForDate(_asOf);
        when(() => bench.dayAgentService.getDayAgentForDate(any())).thenAnswer(
          (_) async => makeTestIdentity(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.dayAgent,
          ),
        );
        when(
          () => bench.planService.draftPlanForDay(
            agentId: agentId,
            dayId: dayId,
          ),
        ).thenAnswer(
          (_) async => buildDayPlan(agentId: agentId, dayId: dayId),
        );
        when(
          () => bench.journalDb.getCategoryById(any()),
        ).thenAnswer((_) async => null);

        Object? firstError;
        var cancelled = false;
        fakeAsync((async) {
          withClock(async.getClock(_asOf), () {
            unawaited(
              bench.adapter
                  .draftDayPlan(
                    captureId: const CaptureId('cap'),
                    decidedTaskIds: const [],
                    dayDate: _asOf,
                    isCancelled: () => cancelled,
                  )
                  .catchError((Object e) {
                    firstError = e;
                    return DraftPlan.emptyForDay(_asOf);
                  }),
            );
          });
          async.flushMicrotasks();
          cancelled = true;
          async
            ..elapse(const Duration(seconds: 1))
            ..flushMicrotasks();
        });

        expect(firstError, isA<DayAgentInteractionException>());
        final jobId = DayProcessingOutboxRepository.draftJobId(dayId);
        final job = await bench.outbox.getById(jobId);
        expect(job!.isTerminal, isFalse);

        final secondFuture = bench.adapter.draftDayPlan(
          captureId: const CaptureId('cap'),
          decidedTaskIds: const [],
          dayDate: _asOf,
        );
        await pumpEventQueue();
        await bench.completeJob(jobId);
        final result = await secondFuture;

        expect(result.state, DayState.drafted);
      },
    );
  });

  group('debugAgendaFor — agenda state fold', () {
    const cat = DayAgentCategory(id: 'c1', name: 'Deep', colorHex: '3B82F6');

    TimeBlock block(
      String id,
      TimeBlockState state, {
      String? taskId,
      int hour = 9,
    }) => TimeBlock(
      id: id,
      title: id,
      start: _asOf.add(Duration(hours: hour)),
      end: _asOf.add(Duration(hours: hour + 1)),
      type: TimeBlockType.ai,
      state: state,
      category: cat,
      taskId: taskId,
    );

    test(
      'a partially worked group (inProgress + completed + drafted) folds to '
      'inProgress, and a fully completed group folds to done',
      () {
        final bench = _TestBench.create();
        final agenda = bench.adapter.debugAgendaFor([
          // task-1: one of each — inProgress must win even though a block
          // is already completed and another is still drafted.
          block('p-done', TimeBlockState.completed, taskId: 'task-1'),
          block(
            'p-active',
            TimeBlockState.inProgress,
            taskId: 'task-1',
            hour: 10,
          ),
          block(
            'p-drafted',
            TimeBlockState.drafted,
            taskId: 'task-1',
            hour: 11,
          ),
          // task-2: every block completed → done.
          block('d-1', TimeBlockState.completed, taskId: 'task-2', hour: 12),
          block('d-2', TimeBlockState.completed, taskId: 'task-2', hour: 13),
        ]);

        final partial = agenda.firstWhere((a) => a.taskId == 'task-1');
        expect(partial.state, AgendaItemState.inProgress);
        expect(partial.linkedBlockIds, ['p-done', 'p-active', 'p-drafted']);
        expect(partial.totalEstimateMinutes, 180);

        final completed = agenda.firstWhere((a) => a.taskId == 'task-2');
        expect(completed.state, AgendaItemState.done);
      },
    );
  });

  group('projection pure helpers — properties', () {
    late _TestBench bench;

    setUp(() {
      bench = _TestBench.create();
    });

    glados.Glados<String>(
      glados.AnyUtils(glados.any).choose(const [
        '#3B82F6',
        '3B82F6',
        '#3B82F6FF',
        '#FFF',
        'FFF',
        '',
        '#',
        '#0F172A',
      ]),
      glados.ExploreConfig(numRuns: 120),
    ).test(
      'debugProjectCategory normalises hex per the documented contract',
      (color) {
        final def = CategoryDefinition(
          id: 'cat-1',
          name: 'Cat',
          color: color,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
          vectorClock: null,
          private: false,
          active: true,
        );

        final projected = bench.adapter.debugProjectCategory(def);

        // Oracle mirroring the impl contract: strip '#', take the first six
        // chars when long enough, fall back for empty, pass short raw
        // through unchanged (documented quirk — NOT padded to 6).
        final raw = color.replaceFirst('#', '');
        final expected = raw.length >= 6
            ? raw.substring(0, 6)
            : (raw.isEmpty ? projected.colorHex : raw);
        expect(projected.colorHex, expected, reason: 'color="$color"');
        expect(projected.id, 'cat-1');
        expect(projected.name, 'Cat');
        if (raw.length >= 6) {
          expect(projected.colorHex.length, 6);
        }
      },
      tags: 'glados',
    );
  });
}
