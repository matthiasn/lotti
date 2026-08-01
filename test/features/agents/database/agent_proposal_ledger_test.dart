import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_db_conversions.dart';
import 'package:lotti/features/agents/database/agent_proposal_ledger.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/sync/vector_clock.dart';

import '../test_data/change_set_factories.dart';

/// Mirror tests for [AgentProposalLedger]. The collaborator owns no
/// cross-deps — it reads the change-set / decision tables directly — so the
/// tests seed rows straight through `AgentDbConversions` and assert the
/// open/resolved partitioning the ledger produces.
void main() {
  late AgentDatabase db;
  late AgentProposalLedger ledger;

  final testDate = DateTime(2026, 3, 15);

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    ledger = AgentProposalLedger(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> insertChangeSet({
    required String id,
    required String agentId,
    required String taskId,
    ChangeSetStatus status = ChangeSetStatus.pending,
    List<ChangeItem>? items,
    int clock = 1,
    DateTime? createdAt,
  }) async {
    final entity = makeTestChangeSet(
      id: id,
      agentId: agentId,
      taskId: taskId,
      status: status,
      items: items,
      createdAt: createdAt ?? testDate,
      vectorClock: VectorClock({'node-1': clock}),
    );
    await db
        .into(db.agentEntities)
        .insert(AgentDbConversions.toEntityCompanion(entity));
  }

  Future<void> insertDecision({
    required String id,
    required String agentId,
    required String taskId,
    required String changeSetId,
    int itemIndex = 0,
    ChangeDecisionVerdict verdict = ChangeDecisionVerdict.confirmed,
    int clock = 100,
    DateTime? createdAt,
  }) async {
    final entity = makeTestChangeDecision(
      id: id,
      agentId: agentId,
      changeSetId: changeSetId,
      itemIndex: itemIndex,
      verdict: verdict,
      taskId: taskId,
      createdAt: createdAt ?? testDate,
      vectorClock: VectorClock({'node-1': clock}),
    );
    await db
        .into(db.agentEntities)
        .insert(AgentDbConversions.toEntityCompanion(entity));
  }

  test('the newest decision for an item wins in the ledger', () async {
    // This is the invariant the compound ORDER BY protects: getProposalLedger
    // keeps the FIRST decision it sees per item (decisionByKey.putIfAbsent), so
    // the decision rows must arrive newest-first. Asserting it here, at the
    // consumer, rather than on raw row order — the row-order assertion cannot
    // distinguish the two implementations, because SQLite 3.45 happens to emit
    // each UNION ALL arm in its inner order even without the explicit ORDER BY.
    await insertChangeSet(
      id: 'cs-1',
      agentId: 'agent-1',
      taskId: 'task-1',
      status: ChangeSetStatus.resolved,
      items: const [
        ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 30},
          humanSummary: 'Estimate 30m',
        ),
      ],
      createdAt: DateTime(2026, 3, 2),
    );
    // An older audit/retry row, then the decision that actually stands.
    await insertDecision(
      id: 'cd-old',
      agentId: 'agent-1',
      taskId: 'task-1',
      changeSetId: 'cs-1',
      createdAt: DateTime(2026, 3, 5),
    );
    await insertDecision(
      id: 'cd-new',
      agentId: 'agent-1',
      taskId: 'task-1',
      changeSetId: 'cs-1',
      verdict: ChangeDecisionVerdict.rejected,
      createdAt: DateTime(2026, 3, 9),
    );

    final result = await ledger.getProposalLedger('agent-1', taskId: 'task-1');

    expect(result.resolved, hasLength(1));
    expect(
      result.resolved.single.verdict,
      ChangeDecisionVerdict.rejected,
      reason: 'the later rejection must not be overridden by the older confirm',
    );
  });

  test('empty ledger when the agent has no change sets', () async {
    final result = await ledger.getProposalLedger('agent-1', taskId: 'task-1');
    expect(result.open, isEmpty);
    expect(result.resolved, isEmpty);
    expect(result.pendingSets, isEmpty);
  });

  test('a pending change set yields one open entry', () async {
    await insertChangeSet(
      id: 'cs-1',
      agentId: 'agent-1',
      taskId: 'task-1',
      items: const [
        ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 30},
          humanSummary: 'Estimate 30m',
        ),
      ],
    );

    final result = await ledger.getProposalLedger('agent-1', taskId: 'task-1');
    expect(result.open, hasLength(1));
    expect(result.open.single.changeSetId, 'cs-1');
    expect(result.resolved, isEmpty);
    expect(result.pendingSets, hasLength(1));
  });

  test('a rejected decision moves the item from open to resolved', () async {
    // A `confirmed` verdict on an active set deliberately keeps the item open
    // (it is written before dispatch and reverts on failure); rejection has no
    // retry path, so it closes the item into resolved.
    await insertChangeSet(
      id: 'cs-2',
      agentId: 'agent-1',
      taskId: 'task-1',
      items: const [
        ChangeItem(
          toolName: 'update_task_estimate',
          args: {'minutes': 45},
          humanSummary: 'Estimate 45m',
        ),
      ],
    );
    await insertDecision(
      id: 'cd-2',
      agentId: 'agent-1',
      taskId: 'task-1',
      changeSetId: 'cs-2',
      verdict: ChangeDecisionVerdict.rejected,
    );

    final result = await ledger.getProposalLedger('agent-1', taskId: 'task-1');
    expect(result.open, isEmpty);
    expect(result.resolved, hasLength(1));
    expect(result.resolved.single.verdict, ChangeDecisionVerdict.rejected);
  });

  test('only the requested task is included in the ledger', () async {
    await insertChangeSet(
      id: 'cs-task-a',
      agentId: 'agent-1',
      taskId: 'task-a',
    );
    await insertChangeSet(
      id: 'cs-task-b',
      agentId: 'agent-1',
      taskId: 'task-b',
      clock: 2,
    );

    final result = await ledger.getProposalLedger('agent-1', taskId: 'task-a');
    expect(
      result.open.map((e) => e.changeSetId).toSet(),
      {'cs-task-a'},
    );
  });
}
