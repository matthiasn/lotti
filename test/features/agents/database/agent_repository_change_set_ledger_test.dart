import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/database/agent_database.dart';
import 'package:lotti/features/agents/database/agent_repository.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';

import '../test_utils.dart';

void main() {
  late AgentDatabase db;
  late AgentRepository repo;

  setUp(() {
    db = AgentDatabase(inMemoryDatabase: true, background: false);
    repo = AgentRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── ChangeSet entity roundtrips ──────────────────────────────────────────

  group('getProposalLedger', () {
    test('splits items into open and resolved groups, newest-first', () async {
      final oldSet = makeTestChangeSet(
        id: 'cs-old',
        taskId: 'task-ledger',
        createdAt: kAgentTestDate,
        status: ChangeSetStatus.resolved,
        resolvedAt: kAgentTestDate.add(const Duration(hours: 1)),
        items: const [
          ChangeItem(
            toolName: 'set_task_title',
            args: {'title': 'Old title'},
            humanSummary: 'Rename task to "Old title"',
            status: ChangeItemStatus.confirmed,
          ),
        ],
      );
      final newerSet = makeTestChangeSet(
        id: 'cs-new',
        taskId: 'task-ledger',
        createdAt: kAgentTestDate.add(const Duration(hours: 2)),
        items: const [
          ChangeItem(
            toolName: 'update_task_priority',
            args: {'priority': 'P1'},
            humanSummary: 'Set priority to P1',
          ),
          ChangeItem(
            toolName: 'add_checklist_item',
            args: {'title': 'Write migration'},
            humanSummary: 'Add checklist item: "Write migration"',
          ),
        ],
      );
      final confirmedDecision = makeTestChangeDecision(
        id: 'cd-confirm-old',
        changeSetId: 'cs-old',
        toolName: 'set_task_title',
        taskId: 'task-ledger',
        args: const {'title': 'Old title'},
        humanSummary: 'Rename task to "Old title"',
        createdAt: kAgentTestDate.add(const Duration(hours: 1)),
      );

      await repo.upsertEntity(oldSet);
      await repo.upsertEntity(newerSet);
      await repo.upsertEntity(confirmedDecision);

      final ledger = await repo.getProposalLedger(
        kTestAgentId,
        taskId: 'task-ledger',
      );

      expect(ledger.open, hasLength(2));
      // Open items are newest-first by parent change set createdAt.
      expect(ledger.open.first.toolName, 'update_task_priority');
      expect(ledger.open.first.status, ChangeItemStatus.pending);
      expect(
        ledger.open.first.fingerprint,
        ChangeItem.fingerprintFromParts(
          'update_task_priority',
          const {'priority': 'P1'},
        ),
      );

      expect(ledger.resolved, hasLength(1));
      final resolvedEntry = ledger.resolved.single;
      expect(resolvedEntry.toolName, 'set_task_title');
      expect(resolvedEntry.status, ChangeItemStatus.confirmed);
      expect(resolvedEntry.verdict, ChangeDecisionVerdict.confirmed);
      expect(resolvedEntry.resolvedBy, DecisionActor.user);
    });

    test(
      'attaches agent retraction metadata (actor, verdict, retractionReason)',
      () async {
        final retractedSet = makeTestChangeSet(
          id: 'cs-retracted',
          taskId: 'task-retract',
          status: ChangeSetStatus.resolved,
          createdAt: kAgentTestDate,
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
              status: ChangeItemStatus.retracted,
            ),
          ],
        );
        final retractionDecision = makeTestChangeDecision(
          id: 'cd-retract',
          changeSetId: 'cs-retracted',
          toolName: 'update_task_priority',
          verdict: ChangeDecisionVerdict.retracted,
          actor: DecisionActor.agent,
          taskId: 'task-retract',
          args: const {'priority': 'P1'},
          retractionReason: 'Already P1 on the task',
          humanSummary: 'Set priority to P1',
          createdAt: kAgentTestDate.add(const Duration(minutes: 5)),
        );

        await repo.upsertEntity(retractedSet);
        await repo.upsertEntity(retractionDecision);

        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: 'task-retract',
        );

        expect(ledger.open, isEmpty);
        expect(ledger.resolved, hasLength(1));
        final entry = ledger.resolved.single;
        expect(entry.status, ChangeItemStatus.retracted);
        expect(entry.verdict, ChangeDecisionVerdict.retracted);
        expect(entry.resolvedBy, DecisionActor.agent);
        expect(entry.reason, 'Already P1 on the task');
      },
    );

    test(
      'filters retired resolved-set pending items out of open proposals',
      () async {
        final retiredSet = makeTestChangeSet(
          id: 'cs-retired',
          taskId: 'task-retired',
          status: ChangeSetStatus.resolved,
          resolvedAt: kAgentTestDate.add(const Duration(minutes: 10)),
          createdAt: kAgentTestDate,
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
            ),
          ],
        );

        await repo.upsertEntity(retiredSet);

        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: 'task-retired',
        );

        expect(ledger.open, isEmpty);
        expect(ledger.resolved, isEmpty);
        expect(ledger.pendingSets, isEmpty);
        expect(ledger.isEmpty, isTrue);
      },
    );

    test(
      'uses retraction decisions to close stale pending item snapshots',
      () async {
        final stalePendingSet = makeTestChangeSet(
          id: 'cs-stale-pending',
          taskId: 'task-stale-pending',
          createdAt: kAgentTestDate,
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
            ),
          ],
        );
        final retractionDecision = makeTestChangeDecision(
          id: 'cd-stale-retract',
          changeSetId: 'cs-stale-pending',
          toolName: 'update_task_priority',
          verdict: ChangeDecisionVerdict.retracted,
          actor: DecisionActor.agent,
          taskId: 'task-stale-pending',
          args: const {'priority': 'P1'},
          retractionReason: 'Priority is already P1',
          humanSummary: 'Set priority to P1',
          createdAt: kAgentTestDate.add(const Duration(minutes: 5)),
        );

        await repo.upsertEntity(stalePendingSet);
        await repo.upsertEntity(retractionDecision);

        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: 'task-stale-pending',
        );

        expect(ledger.open, isEmpty);
        expect(ledger.pendingSets, isEmpty);
        expect(ledger.resolved, hasLength(1));
        final entry = ledger.resolved.single;
        expect(entry.status, ChangeItemStatus.retracted);
        expect(entry.verdict, ChangeDecisionVerdict.retracted);
        expect(entry.resolvedBy, DecisionActor.agent);
        expect(entry.reason, 'Priority is already P1');
      },
    );

    test(
      'keeps active confirmed pending snapshots open for dispatch retry',
      () async {
        final retrySet = makeTestChangeSet(
          id: 'cs-confirmed-retry',
          taskId: 'task-confirmed-retry',
          createdAt: kAgentTestDate,
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
            ),
          ],
        );
        final confirmedDecision = makeTestChangeDecision(
          id: 'cd-confirmed-retry',
          changeSetId: retrySet.id,
          toolName: 'update_task_priority',
          taskId: retrySet.taskId,
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          createdAt: kAgentTestDate.add(const Duration(minutes: 5)),
        );

        await repo.upsertEntity(retrySet);
        await repo.upsertEntity(confirmedDecision);

        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: retrySet.taskId,
        );

        expect(ledger.open, hasLength(1));
        expect(ledger.open.single.status, ChangeItemStatus.pending);
        expect(ledger.open.single.verdict, ChangeDecisionVerdict.confirmed);
        expect(ledger.resolved, isEmpty);
        expect(ledger.pendingSets, hasLength(1));
        expect(
          ledger.pendingSets.single.items.single.status,
          ChangeItemStatus.pending,
        );
      },
    );

    test(
      'uses user decisions to close stale rejected and deferred snapshots',
      () async {
        const cases = [
          (
            verdict: ChangeDecisionVerdict.rejected,
            status: ChangeItemStatus.rejected,
            reason: 'User declined the priority change',
          ),
          (
            verdict: ChangeDecisionVerdict.deferred,
            status: ChangeItemStatus.deferred,
            reason: 'User will decide later',
          ),
        ];

        for (var i = 0; i < cases.length; i++) {
          final testCase = cases[i];
          final changeSetId = 'cs-user-decision-$i';
          const taskId = 'task-user-decision';
          await repo.upsertEntity(
            makeTestChangeSet(
              id: changeSetId,
              taskId: taskId,
              createdAt: kAgentTestDate.add(Duration(minutes: i)),
              items: [
                ChangeItem(
                  toolName: 'update_task_priority',
                  args: {'priority': 'P${i + 1}'},
                  humanSummary: 'Set priority to P${i + 1}',
                ),
              ],
            ),
          );
          await repo.upsertEntity(
            makeTestChangeDecision(
              id: 'cd-user-decision-$i',
              changeSetId: changeSetId,
              toolName: 'update_task_priority',
              verdict: testCase.verdict,
              taskId: taskId,
              args: {'priority': 'P${i + 1}'},
              rejectionReason: testCase.reason,
              humanSummary: 'Set priority to P${i + 1}',
              createdAt: kAgentTestDate.add(Duration(minutes: i + 10)),
            ),
          );
        }

        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: 'task-user-decision',
        );

        expect(ledger.open, isEmpty);
        expect(ledger.pendingSets, isEmpty);
        expect(ledger.resolved, hasLength(cases.length));
        for (final testCase in cases) {
          final entry = ledger.resolved.singleWhere(
            (e) => e.verdict == testCase.verdict,
          );
          expect(entry.status, testCase.status);
          expect(entry.resolvedBy, DecisionActor.user);
          expect(entry.reason, testCase.reason);
        }
      },
    );

    test(
      'uses confirmed decisions to close resolved-parent pending snapshots',
      () async {
        final resolvedPendingSet = makeTestChangeSet(
          id: 'cs-resolved-confirmed-pending',
          taskId: 'task-resolved-confirmed-pending',
          status: ChangeSetStatus.resolved,
          resolvedAt: kAgentTestDate.add(const Duration(minutes: 6)),
          createdAt: kAgentTestDate,
          items: const [
            ChangeItem(
              toolName: 'update_task_priority',
              args: {'priority': 'P1'},
              humanSummary: 'Set priority to P1',
            ),
          ],
        );
        final confirmedDecision = makeTestChangeDecision(
          id: 'cd-resolved-confirmed-pending',
          changeSetId: resolvedPendingSet.id,
          toolName: 'update_task_priority',
          taskId: resolvedPendingSet.taskId,
          args: const {'priority': 'P1'},
          humanSummary: 'Set priority to P1',
          createdAt: kAgentTestDate.add(const Duration(minutes: 5)),
        );

        await repo.upsertEntity(resolvedPendingSet);
        await repo.upsertEntity(confirmedDecision);

        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: resolvedPendingSet.taskId,
        );

        expect(ledger.open, isEmpty);
        expect(ledger.pendingSets, isEmpty);
        expect(ledger.resolved, hasLength(1));
        final entry = ledger.resolved.single;
        expect(entry.status, ChangeItemStatus.confirmed);
        expect(entry.verdict, ChangeDecisionVerdict.confirmed);
        expect(entry.resolvedBy, DecisionActor.user);
      },
    );

    test('filters change sets from other tasks out of the ledger', () async {
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-target',
          taskId: 'target-task',
          createdAt: kAgentTestDate,
        ),
      );
      await repo.upsertEntity(
        makeTestChangeSet(
          id: 'cs-other',
          taskId: 'other-task',
          createdAt: kAgentTestDate,
        ),
      );

      final ledger = await repo.getProposalLedger(
        kTestAgentId,
        taskId: 'target-task',
      );

      expect(ledger.open, hasLength(1));
      expect(ledger.open.single.changeSetId, 'cs-target');
      expect(ledger.resolved, isEmpty);
    });

    test(
      'returns ProposalLedger.empty when the task has no change sets',
      () async {
        final ledger = await repo.getProposalLedger(
          kTestAgentId,
          taskId: 'task-with-nothing',
        );

        expect(ledger.isEmpty, isTrue);
        expect(ledger.open, isEmpty);
        expect(ledger.resolved, isEmpty);
      },
    );

    test('caps resolved entries at resolvedLimit most-recent', () async {
      // Ten resolved sets, each with one confirmed item.
      for (var i = 0; i < 10; i++) {
        final csId = 'cs-$i';
        await repo.upsertEntity(
          makeTestChangeSet(
            id: csId,
            taskId: 'task-cap',
            status: ChangeSetStatus.resolved,
            createdAt: kAgentTestDate.add(Duration(minutes: i)),
            items: [
              ChangeItem(
                toolName: 'set_task_title',
                args: {'title': 'Title $i'},
                humanSummary: 'Rename $i',
                status: ChangeItemStatus.confirmed,
              ),
            ],
          ),
        );
        await repo.upsertEntity(
          makeTestChangeDecision(
            id: 'cd-$i',
            changeSetId: csId,
            taskId: 'task-cap',
            toolName: 'set_task_title',
            args: {'title': 'Title $i'},
            humanSummary: 'Rename $i',
            createdAt: kAgentTestDate.add(Duration(minutes: i, seconds: 30)),
          ),
        );
      }

      final ledger = await repo.getProposalLedger(
        kTestAgentId,
        taskId: 'task-cap',
        resolvedLimit: 3,
      );

      expect(ledger.resolved, hasLength(3));
      // Newest first — latest three are Title 9, 8, 7.
      expect(ledger.resolved[0].humanSummary, 'Rename 9');
      expect(ledger.resolved[1].humanSummary, 'Rename 8');
      expect(ledger.resolved[2].humanSummary, 'Rename 7');
    });
  });
}
