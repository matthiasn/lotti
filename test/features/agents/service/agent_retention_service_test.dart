import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/service/agent_retention_policy.dart';
import 'package:lotti/features/agents/service/agent_retention_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks/mocks.dart';

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
      () => repository.pruneObservationsBeyond(
        keepPerAgent: any(named: 'keepPerAgent'),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => repository.pruneDayStatusEventsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => repository.pruneWakeRunsBefore(
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
      () => repository.pruneObservationsBeyond(
        keepPerAgent: policy.observationsPerAgent,
        batchSize: policy.batchSize,
        maxBatches: policy.maxBatchesPerSweep,
      ),
    ).called(1);
    verify(
      () => repository.pruneDayStatusEventsBefore(
        now.subtract(policy.dayStatusEvents),
        batchSize: policy.batchSize,
        maxBatches: policy.maxBatchesPerSweep,
      ),
    ).called(1);
    verify(
      () => repository.pruneWakeRunsBefore(
        now.subtract(policy.wakeRunLog),
        batchSize: policy.batchSize,
        maxBatches: policy.maxBatchesPerSweep,
      ),
    ).called(1);
  });

  test('reports what each source removed', () async {
    when(
      () => repository.pruneObservationsBeyond(
        keepPerAgent: any(named: 'keepPerAgent'),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => 7);
    when(
      () => repository.pruneDayStatusEventsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => 3);
    when(
      () => repository.pruneWakeRunsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => 2);

    final result = await withClock(Clock.fixed(now), service.sweep);

    expect(result.observations, 7);
    expect(result.dayStatusEvents, 3);
    expect(result.wakeRuns, 2);
    expect(result.total, 12);
  });

  test('a failing source keeps what the earlier ones already removed', () async {
    when(
      () => repository.pruneObservationsBeyond(
        keepPerAgent: any(named: 'keepPerAgent'),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenAnswer((_) async => 5);
    when(
      () => repository.pruneDayStatusEventsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    ).thenThrow(StateError('database locked'));

    final result = await withClock(Clock.fixed(now), service.sweep);

    expect(
      result.observations,
      5,
      reason:
          'Those rows are gone whatever happens next — the result must say so '
          'rather than reporting a clean zero.',
    );
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
    verifyNever(
      () => repository.pruneWakeRunsBefore(
        any(),
        batchSize: any(named: 'batchSize'),
        maxBatches: any(named: 'maxBatches'),
      ),
    );
  });

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
