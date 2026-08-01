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
  }) async {
    final entity = makeTestChangeSet(
      id: id,
      agentId: agentId,
      taskId: taskId,
      status: status,
      items: items,
      createdAt: testDate,
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
  }) async {
    final entity = makeTestChangeDecision(
      id: id,
      agentId: agentId,
      changeSetId: changeSetId,
      itemIndex: itemIndex,
      verdict: verdict,
      taskId: taskId,
      createdAt: testDate,
      vectorClock: VectorClock({'node-1': clock}),
    );
    await db
        .into(db.agentEntities)
        .insert(AgentDbConversions.toEntityCompanion(entity));
  }

  group('getProposalLedgerRowsForAgentAndTask (single round trip)', () {
    // The ledger used to issue three concurrent task-scoped queries. They are
    // now one UNION ALL with a per-row `bucket` marker, so these tests pin the
    // properties that collapsing could silently break: correct bucketing, and
    // independent per-arm limits.

    test('returns all three buckets from one query', () async {
      await insertChangeSet(
        id: 'cs-open',
        agentId: 'agent-1',
        taskId: 'task-1',
      );
      await insertChangeSet(
        id: 'cs-done',
        agentId: 'agent-1',
        taskId: 'task-1',
        status: ChangeSetStatus.resolved,
      );
      await insertDecision(
        id: 'cd-1',
        agentId: 'agent-1',
        taskId: 'task-1',
        changeSetId: 'cs-done',
      );

      final rows = await db
          .getProposalLedgerRowsForAgentAndTask(
            agentId: 'agent-1',
            taskId: 'task-1',
            changeSetLimit: 200,
            decisionLimit: 50,
          )
          .get();

      final idsByBucket = <String, Set<String>>{};
      for (final row in rows) {
        idsByBucket
            .putIfAbsent(
              row.read<String>(AgentDatabase.ledgerBucketColumn),
              () => <String>{},
            )
            .add(row.read<String>('id'));
      }

      expect(
        idsByBucket[AgentDatabase.ledgerBucketPending],
        {'cs-open'},
        reason:
            'the pending arm filters on subtype, so the resolved set is out',
      );
      expect(
        idsByBucket[AgentDatabase.ledgerBucketRecent],
        {'cs-open', 'cs-done'},
        reason: 'the recent arm is unfiltered change-set history',
      );
      expect(idsByBucket[AgentDatabase.ledgerBucketDecision], {'cd-1'});
    });

    test('every bucket comes back newest-first', () async {
      // The consumers are first-wins (decisionByKey.putIfAbsent, and the
      // duplicate-proposal collapse), so a compound result in some other legal
      // order would let an older retry/audit decision override the newest one.
      for (var i = 0; i < 3; i++) {
        await insertChangeSet(
          id: 'cs-$i',
          agentId: 'agent-1',
          taskId: 'task-1',
          clock: i + 1,
        );
        await insertDecision(
          id: 'cd-$i',
          agentId: 'agent-1',
          taskId: 'task-1',
          changeSetId: 'cs-0',
          clock: 100 + i,
        );
      }

      final rows = await db
          .getProposalLedgerRowsForAgentAndTask(
            agentId: 'agent-1',
            taskId: 'task-1',
            changeSetLimit: 200,
            decisionLimit: 50,
          )
          .get();

      final byBucket = <String, List<DateTime>>{};
      for (final row in rows) {
        byBucket
            .putIfAbsent(
              row.read<String>(AgentDatabase.ledgerBucketColumn),
              () => <DateTime>[],
            )
            .add(row.read<DateTime>('created_at'));
      }

      expect(byBucket.keys, isNotEmpty);
      for (final entry in byBucket.entries) {
        final sortedDesc = [...entry.value]..sort((a, b) => b.compareTo(a));
        expect(
          entry.value,
          sortedDesc,
          reason: 'bucket "${entry.key}" must be newest-first',
        );
      }
    });

    test('scopes to the requested agent and task', () async {
      await insertChangeSet(id: 'mine', agentId: 'agent-1', taskId: 'task-1');
      await insertChangeSet(
        id: 'other-task',
        agentId: 'agent-1',
        taskId: 't-2',
      );
      await insertChangeSet(
        id: 'other-agent',
        agentId: 'agent-2',
        taskId: 'task-1',
      );

      final rows = await db
          .getProposalLedgerRowsForAgentAndTask(
            agentId: 'agent-1',
            taskId: 'task-1',
            changeSetLimit: 200,
            decisionLimit: 50,
          )
          .get();

      expect(rows.map((r) => r.read<String>('id')).toSet(), {'mine'});
    });

    test('applies the change-set and decision limits independently', () async {
      for (var i = 0; i < 4; i++) {
        await insertChangeSet(
          id: 'cs-$i',
          agentId: 'agent-1',
          taskId: 'task-1',
          status: ChangeSetStatus.resolved,
        );
        await insertDecision(
          id: 'cd-$i',
          agentId: 'agent-1',
          taskId: 'task-1',
          changeSetId: 'cs-$i',
        );
      }

      final rows = await db
          .getProposalLedgerRowsForAgentAndTask(
            agentId: 'agent-1',
            taskId: 'task-1',
            changeSetLimit: 3,
            decisionLimit: 1,
          )
          .get();

      final counts = <String, int>{};
      for (final row in rows) {
        final bucket = row.read<String>(AgentDatabase.ledgerBucketColumn);
        counts[bucket] = (counts[bucket] ?? 0) + 1;
      }

      expect(
        counts[AgentDatabase.ledgerBucketRecent],
        3,
        reason: 'the change-set arm honours changeSetLimit',
      );
      expect(
        counts[AgentDatabase.ledgerBucketDecision],
        1,
        reason:
            'the decision arm honours its own, smaller decisionLimit — a '
            'single shared LIMIT across the union would break this',
      );
    });

    test(
      'a long-lived open set survives a recent-history cap that would bury it',
      () async {
        // The reason the pending arm exists at all: the recent arm is
        // newest-first and capped, so an old-but-still-open set must still
        // reach the ledger through its own arm.
        await insertChangeSet(
          id: 'cs-old-open',
          agentId: 'agent-1',
          taskId: 'task-1',
        );
        for (var i = 0; i < 3; i++) {
          await insertChangeSet(
            id: 'cs-newer-$i',
            agentId: 'agent-1',
            taskId: 'task-1',
            status: ChangeSetStatus.resolved,
            clock: 10 + i,
          );
        }

        final rows = await db
            .getProposalLedgerRowsForAgentAndTask(
              agentId: 'agent-1',
              taskId: 'task-1',
              changeSetLimit: 2,
              decisionLimit: 50,
            )
            .get();

        final pendingIds = rows
            .where(
              (r) =>
                  r.read<String>(AgentDatabase.ledgerBucketColumn) ==
                  AgentDatabase.ledgerBucketPending,
            )
            .map((r) => r.read<String>('id'))
            .toSet();

        expect(
          pendingIds,
          contains('cs-old-open'),
          reason:
              'the dedicated pending arm is what keeps the open set visible',
        );
      },
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
