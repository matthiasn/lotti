import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_repo_observation_retention.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';
import 'package:lotti/features/agents/service/agent_retention_service.dart';
import 'package:lotti/features/daily_os_next/agents/domain/day_agent_identity.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';

void main() {
  late MockAgentRepository repository;
  late MockDomainLogger domainLogger;
  late AgentRetentionService service;

  final now = DateTime(2026, 8, 1, 9);

  setUp(() {
    repository = MockAgentRepository();
    domainLogger = MockDomainLogger();
    when(
      () => domainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => domainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        stackTrace: any(named: 'stackTrace'),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => repository.getMessagesByKind(
        dailyOsPlannerAgentId,
        AgentMessageKind.system,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        makeTestMessage(
          kind: AgentMessageKind.system,
          createdAt: now,
          metadata: const AgentMessageMetadata(
            milestone: AgentMilestone.dailyWakeCompleted,
          ),
        ),
      ],
    );
    when(
      () => repository.pruneDayStatusEventsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => <String>[]);
    when(
      () => repository.threadsWithAgedObservations(
        any(),
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repository.pruneThreadObservations(
        agentId: any(named: 'agentId'),
        threadId: any(named: 'threadId'),
        cutoff: any(named: 'cutoff'),
        limit: any(named: 'limit'),
        maxMessages: any(named: 'maxMessages'),
      ),
    ).thenAnswer((_) async => const ObservationSweepResult.empty());
    service = AgentRetentionService(
      repository: repository,
      domainLogger: domainLogger,
    );
  });

  test('sweeps each source with the cutoff its own policy implies', () async {
    await withClock(Clock.fixed(now), service.sweep);

    const policy = AgentRetentionPolicy();
    verify(
      () => repository.pruneDayStatusEventsBefore(
        now.subtract(policy.dayStatusEvents),
        batchSize: policy.batchSize,
        maxBatches: policy.maxBatchesPerSweep,
      ),
    ).called(1);
  });

  group('observations', () {
    void seedThreads(List<({String agentId, String threadId})> threads) {
      when(
        () => repository.threadsWithAgedObservations(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => threads);
    }

    test('sweeps each aged thread on the observation horizon', () async {
      seedThreads([
        (agentId: 'agent-1', threadId: 'thread-1'),
        (agentId: 'agent-2', threadId: 'thread-2'),
      ]);
      when(
        () => repository.pruneThreadObservations(
          agentId: any(named: 'agentId'),
          threadId: any(named: 'threadId'),
          cutoff: any(named: 'cutoff'),
          limit: any(named: 'limit'),
          maxMessages: any(named: 'maxMessages'),
        ),
      ).thenAnswer(
        (_) async => const ObservationSweepResult(
          messageIds: ['m1', 'm2'],
          linkIds: ['l1'],
        ),
      );

      final result = await withClock(Clock.fixed(now), service.sweep);

      const policy = AgentRetentionPolicy();
      expect(result.observations, 4);
      verify(
        () => repository.pruneThreadObservations(
          agentId: 'agent-1',
          threadId: 'thread-1',
          cutoff: now.subtract(policy.observations),
          limit: policy.batchSize,
          maxMessages: policy.maxThreadMessages,
        ),
      ).called(1);
    });

    test('the observation horizon is not the status-event one', () async {
      seedThreads([]);

      await withClock(Clock.fixed(now), service.sweep);

      const policy = AgentRetentionPolicy();
      verify(
        () => repository.threadsWithAgedObservations(
          now.subtract(policy.observations),
          limit: policy.threadsPerSweep,
        ),
      ).called(1);
    });

    test('one failing thread does not stop the others', () async {
      seedThreads([
        (agentId: 'agent-1', threadId: 'boom'),
        (agentId: 'agent-2', threadId: 'fine'),
      ]);
      when(
        () => repository.pruneThreadObservations(
          agentId: any(named: 'agentId'),
          threadId: 'boom',
          cutoff: any(named: 'cutoff'),
          limit: any(named: 'limit'),
          maxMessages: any(named: 'maxMessages'),
        ),
      ).thenThrow(Exception('malformed log'));
      when(
        () => repository.pruneThreadObservations(
          agentId: any(named: 'agentId'),
          threadId: 'fine',
          cutoff: any(named: 'cutoff'),
          limit: any(named: 'limit'),
          maxMessages: any(named: 'maxMessages'),
        ),
      ).thenAnswer(
        (_) async => const ObservationSweepResult(
          messageIds: ['m1'],
          linkIds: [],
        ),
      );

      final result = await withClock(Clock.fixed(now), service.sweep);

      expect(
        result.observations,
        1,
        reason:
            'One malformed log must not stop every other agent from being '
            'collected.',
      );
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    });

    test('reclaims the sidecars of pruned messages and links', () async {
      seedThreads([(agentId: 'agent-1', threadId: 'thread-1')]);
      when(
        () => repository.pruneThreadObservations(
          agentId: any(named: 'agentId'),
          threadId: any(named: 'threadId'),
          cutoff: any(named: 'cutoff'),
          limit: any(named: 'limit'),
          maxMessages: any(named: 'maxMessages'),
        ),
      ).thenAnswer(
        (_) async => const ObservationSweepResult(
          messageIds: ['m1'],
          linkIds: ['l1'],
        ),
      );
      final reclaimer = MockAgentSidecarReclaimer();
      when(
        () => reclaimer.reclaim(
          entityIds: any(named: 'entityIds'),
          linkIds: any(named: 'linkIds'),
        ),
      ).thenReturn(1);
      service = AgentRetentionService(
        repository: repository,
        domainLogger: domainLogger,
        sidecarReclaimer: reclaimer,
      );

      await withClock(Clock.fixed(now), service.sweep);

      verify(
        () => reclaimer.reclaim(entityIds: ['m1'], linkIds: ['l1']),
      ).called(1);
    });

  test('takes the newest marker regardless of the order returned', () async {
    // Nothing in getMessagesByKind promises newest-first, and depending on it
    // would make the watermark quietly wrong rather than loudly broken.
    final older = now.subtract(const Duration(days: 200));
    final newer = now.subtract(const Duration(days: 100));
    when(
      () => repository.getMessagesByKind(
        dailyOsPlannerAgentId,
        AgentMessageKind.system,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        for (final at in [older, newer, older])
          makeTestMessage(
            kind: AgentMessageKind.system,
            createdAt: at,
            metadata: const AgentMessageMetadata(
              milestone: AgentMilestone.dailyWakeCompleted,
            ),
          ),
      ],
    );

    await withClock(Clock.fixed(now), service.sweep);

    const policy = AgentRetentionPolicy();
    verify(
      () => repository.pruneDayStatusEventsBefore(
        newer.subtract(const Duration(hours: 12)),
        batchSize: policy.batchSize,
        maxBatches: policy.maxBatchesPerSweep,
      ),
    ).called(1);
  });

  test('reads the whole system log, not a fixed page', () async {
    // The coordinator writes other system messages between digests, so a
    // capped page can push the real milestone out of view while scheduling is
    // stalled — and a missing marker floors the cutoff at the epoch, which
    // stops retention silently.
    await withClock(Clock.fixed(now), service.sweep);

    verify(
      () => repository.getMessagesByKind(
        dailyOsPlannerAgentId,
        AgentMessageKind.system,
      ),
    ).called(1);
  });

  test('never prunes past what the digest has consumed', () async {
    // A digest that failed or stayed pending for longer than the retention
    // window would otherwise find its backlog already deleted — silently, and
    // exactly in the came-back-after-a-break case the catch-up exists for.
    final staleWatermark = now.subtract(const Duration(days: 200));
    when(
      () => repository.getMessagesByKind(
        dailyOsPlannerAgentId,
        AgentMessageKind.system,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer(
      (_) async => [
        makeTestMessage(
          kind: AgentMessageKind.system,
          createdAt: staleWatermark,
          metadata: const AgentMessageMetadata(
            milestone: AgentMilestone.dailyWakeCompleted,
          ),
        ),
      ],
    );

    await withClock(Clock.fixed(now), service.sweep);

    verify(
      () => repository.pruneDayStatusEventsBefore(
        staleWatermark.subtract(const Duration(hours: 12)),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).called(1);
  });

  test('prunes nothing when no digest has ever completed', () async {
    when(
      () => repository.getMessagesByKind(
        dailyOsPlannerAgentId,
        AgentMessageKind.system,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);

    await withClock(Clock.fixed(now), service.sweep);

    verify(
      () => repository.pruneDayStatusEventsBefore(
        DateTime.fromMillisecondsSinceEpoch(0),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).called(1);
  });

  test("the pruned rows' sidecars are reclaimed with them", () async {
    final reclaimer = MockAgentSidecarReclaimer();
    when(
      () => reclaimer.reclaim(
        entityIds: any(named: 'entityIds'),
        linkIds: any(named: 'linkIds'),
      ),
    ).thenAnswer((_) async => 2);
    when(
      () => repository.pruneDayStatusEventsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => ['evt-1', 'evt-2']);

    await withClock(
      Clock.fixed(now),
      AgentRetentionService(
        repository: repository,
        domainLogger: domainLogger,
        sidecarReclaimer: reclaimer,
      ).sweep,
    );

    verify(() => reclaimer.reclaim(entityIds: ['evt-1', 'evt-2'])).called(1);
  });

  test('reports what each source removed', () async {
    when(
      () => repository.pruneDayStatusEventsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => ['e0', 'e1', 'e2']);

    final result = await withClock(Clock.fixed(now), service.sweep);

    expect(result.dayStatusEvents, 3);
    expect(result.total, 3);
  });

  test(
    'a failing source keeps what the earlier ones already removed',
    () async {
      when(
        () => repository.pruneDayStatusEventsBefore(
          any(),
          batchSize: any(named: 'batchSize'),
          maxBatches: any(named: 'maxBatches'),
        ),
      ).thenThrow(StateError('database locked'));

      final result = await withClock(Clock.fixed(now), service.sweep);

      expect(result.dayStatusEvents, 0);
      verify(
        () => domainLogger.error(
          any(),
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);
    },
  );

  test('an empty sweep logs nothing', () async {
    await withClock(Clock.fixed(now), service.sweep);

    verifyNever(
      () => domainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    );
  });
}
