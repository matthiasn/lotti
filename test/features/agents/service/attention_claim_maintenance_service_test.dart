import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/task.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/attention_negotiation.dart';
import 'package:lotti/features/agents/service/attention_claim_maintenance_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'task-agent-001';
  const taskId = 'task-001';
  final now = DateTime(2026, 5, 29, 10);

  late MockAgentRepository agentRepository;
  late MockAgentSyncService syncService;
  late AttentionClaimMaintenanceService service;

  setUp(() {
    agentRepository = MockAgentRepository();
    syncService = MockAgentSyncService();
    service = AttentionClaimMaintenanceService(
      agentRepository: agentRepository,
      syncService: syncService,
    );

    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
  });

  test('does not query claims for non-terminal tasks', () async {
    final result = await service.settleTerminalTaskClaims(
      agentId: agentId,
      task: _task(status: _openStatus()),
    );

    expect(result.inspectedClaims, 0);
    expect(result.settledClaims, 0);
    expect(result.status, isNull);
    verifyNever(
      () => agentRepository.getAttentionClaimsForTarget(
        targetKind: any(named: 'targetKind'),
        targetId: any(named: 'targetId'),
        limit: any(named: 'limit'),
      ),
    );
    verifyNever(() => syncService.upsertEntity(any()));
  });

  test('marks own active claims satisfied when the task is done', () async {
    when(
      () => agentRepository.getAttentionClaimsForTarget(
        targetKind: 'task',
        targetId: taskId,
      ),
    ).thenAnswer(
      (_) async => [
        _claim(id: 'claim-own', agentId: agentId),
        _claim(id: 'claim-other', agentId: 'project-agent-001'),
      ],
    );

    final result = await withClock(Clock.fixed(now), () {
      return service.settleTerminalTaskClaims(
        agentId: agentId,
        task: _task(status: _doneStatus()),
      );
    });

    expect(result.inspectedClaims, 2);
    expect(result.settledClaims, 1);
    expect(result.status, AttentionClaimStatus.satisfied);

    final disposition =
        verify(() => syncService.upsertEntity(captureAny())).captured.single
            as AttentionClaimDispositionEntity;
    expect(disposition.agentId, agentId);
    expect(disposition.requestId, 'claim-own');
    expect(disposition.status, AttentionClaimStatus.satisfied);
    expect(disposition.reason, contains('Task is done'));
    expect(disposition.createdAt, now);
  });

  test('withdraws own active claims when the task is rejected', () async {
    when(
      () => agentRepository.getAttentionClaimsForTarget(
        targetKind: 'task',
        targetId: taskId,
      ),
    ).thenAnswer((_) async => [_claim(id: 'claim-own', agentId: agentId)]);

    final result = await withClock(Clock.fixed(now), () {
      return service.settleTerminalTaskClaims(
        agentId: agentId,
        task: _task(status: _rejectedStatus()),
      );
    });

    expect(result.settledClaims, 1);
    expect(result.status, AttentionClaimStatus.withdrawn);

    final disposition =
        verify(() => syncService.upsertEntity(captureAny())).captured.single
            as AttentionClaimDispositionEntity;
    expect(disposition.requestId, 'claim-own');
    expect(disposition.status, AttentionClaimStatus.withdrawn);
    expect(disposition.reason, contains('rejected'));
  });

  test('leaves other agents claims untouched', () async {
    when(
      () => agentRepository.getAttentionClaimsForTarget(
        targetKind: 'task',
        targetId: taskId,
      ),
    ).thenAnswer(
      (_) async => [_claim(id: 'claim-other', agentId: 'project-agent-001')],
    );

    final result = await service.settleTerminalTaskClaims(
      agentId: agentId,
      task: _task(status: _doneStatus()),
    );

    expect(result.inspectedClaims, 1);
    expect(result.settledClaims, 0);
    // Terminal task with no owned claims still reports the projected
    // disposition so callers can distinguish it from a non-terminal task.
    expect(result.status, AttentionClaimStatus.satisfied);
    verifyNever(() => syncService.upsertEntity(any()));
  });
}

Task _task({required TaskStatus status}) {
  final createdAt = DateTime(2026, 5, 29, 8);
  return JournalEntity.task(
        meta: Metadata(
          id: 'task-001',
          createdAt: createdAt,
          updatedAt: createdAt,
          dateFrom: createdAt,
          dateTo: createdAt,
          categoryId: 'work',
        ),
        data: TaskData(
          status: status,
          dateFrom: createdAt,
          dateTo: createdAt,
          statusHistory: [status],
          title: 'Finish taxes',
          due: DateTime(2026, 5, 30),
        ),
      )
      as Task;
}

TaskStatus _openStatus() {
  return TaskStatus.open(
    id: 'status-open',
    createdAt: DateTime(2026, 5, 29, 8),
    utcOffset: 0,
  );
}

TaskStatus _doneStatus() {
  return TaskStatus.done(
    id: 'status-done',
    createdAt: DateTime(2026, 5, 29, 8),
    utcOffset: 0,
  );
}

TaskStatus _rejectedStatus() {
  return TaskStatus.rejected(
    id: 'status-rejected',
    createdAt: DateTime(2026, 5, 29, 8),
    utcOffset: 0,
  );
}

AttentionRequestEntity _claim({
  required String id,
  required String agentId,
}) {
  return AgentDomainEntity.attentionRequest(
        id: id,
        agentId: agentId,
        kind: AttentionRequestKind.task,
        title: 'Schedule taxes',
        categoryId: 'work',
        requestedMinutes: 90,
        impact: 5,
        urgency: 4,
        energyFit: AttentionEnergyFit.high,
        evidenceRefs: const [
          AttentionEvidenceRef(
            kind: AttentionEvidenceKind.task,
            id: 'task-001',
            label: 'Finish taxes',
          ),
        ],
        targetId: 'task-001',
        targetKind: 'task',
        rationale: 'Deadline is close.',
        createdAt: DateTime(2026, 5, 29, 8),
        vectorClock: null,
      )
      as AttentionRequestEntity;
}
