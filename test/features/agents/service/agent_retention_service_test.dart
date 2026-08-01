import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
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
    ).thenAnswer((_) async => 0);
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

  test('reports what each source removed', () async {
    when(
      () => repository.pruneDayStatusEventsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => 3);

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
