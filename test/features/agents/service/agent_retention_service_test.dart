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
      () => repository.agentsWithAgedObservations(
        any(),
        limit: any(named: 'limit'),
        afterAgentId: any(named: 'afterAgentId'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => repository.pruneAgentObservations(
        agentId: any(named: 'agentId'),
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
    void seedAgents(List<String> agents) {
      when(
        () => repository.agentsWithAgedObservations(
          any(),
          limit: any(named: 'limit'),
          afterAgentId: any(named: 'afterAgentId'),
        ),
      ).thenAnswer((_) async => agents);
    }

    test('sweeps each aged agent on the observation horizon', () async {
      seedAgents(['agent-1', 'agent-2']);
      when(
        () => repository.pruneAgentObservations(
          agentId: any(named: 'agentId'),
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
        () => repository.pruneAgentObservations(
          agentId: 'agent-1',
          cutoff: now.subtract(policy.observations),
          limit: policy.batchSize,
          maxMessages: policy.maxAgentMessages,
        ),
      ).called(1);
    });

    test('the observation horizon is not the status-event one', () async {
      seedAgents([]);

      await withClock(Clock.fixed(now), service.sweep);

      const policy = AgentRetentionPolicy();
      verify(
        () => repository.agentsWithAgedObservations(
          now.subtract(policy.observations),
          limit: policy.agentsPerSweep,
          afterAgentId: any(named: 'afterAgentId'),
        ),
      ).called(1);
    });

    test('the next sweep resumes after the last agent seen', () async {
      const policy = AgentRetentionPolicy();
      seedAgents([
        for (var i = 0; i < policy.agentsPerSweep; i++) 'agent-$i',
      ]);

      await withClock(Clock.fixed(now), service.sweep);
      await withClock(Clock.fixed(now), service.sweep);

      // A full page means there is more behind it; without the cursor the
      // second sweep re-reads the same prefix and anything further back is
      // never reached.
      verify(
        () => repository.agentsWithAgedObservations(
          any(),
          limit: policy.agentsPerSweep,
          afterAgentId: 'agent-${policy.agentsPerSweep - 1}',
        ),
      ).called(1);
    });

    test('a short page wraps the cursor back to the front', () async {
      seedAgents(['only-one']);

      await withClock(Clock.fixed(now), service.sweep);
      await withClock(Clock.fixed(now), service.sweep);

      // Otherwise the sweep walks off the end and never returns to agents
      // whose observations aged after it passed them.
      verify(
        () => repository.agentsWithAgedObservations(
          any(),
          limit: any(named: 'limit'),
          // ignore: avoid_redundant_argument_values
          afterAgentId: null,
        ),
      ).called(2);
    });

    test('one failing agent does not stop the others', () async {
      seedAgents(['boom', 'fine']);
      when(
        () => repository.pruneAgentObservations(
          agentId: 'boom',
          cutoff: any(named: 'cutoff'),
          limit: any(named: 'limit'),
          maxMessages: any(named: 'maxMessages'),
        ),
      ).thenThrow(Exception('malformed log'));
      when(
        () => repository.pruneAgentObservations(
          agentId: 'fine',
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
      seedAgents(['agent-1']);
      when(
        () => repository.pruneAgentObservations(
          agentId: any(named: 'agentId'),
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
      ).thenAnswer((_) async => 1);
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
