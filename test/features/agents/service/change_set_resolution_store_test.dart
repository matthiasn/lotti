import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_resolution_store.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

const _successResult = ToolExecutionResult(
  success: true,
  output: 'Created follow-up task',
  mutatedEntityId: 'task-actual-1',
);

ChangeItem _createFollowUpItem({
  String? placeholderId = 'placeholder-1',
  ChangeItemStatus status = ChangeItemStatus.pending,
}) {
  return ChangeItem(
    toolName: TaskAgentToolNames.createFollowUpTask,
    args: {
      'title': 'Follow-up task',
      '_placeholderTaskId': ?placeholderId,
    },
    humanSummary: 'Create follow-up task',
    status: status,
  );
}

ChangeItem _migrationItem({
  required String id,
  String targetTaskId = 'placeholder-1',
  ChangeItemStatus status = ChangeItemStatus.pending,
}) {
  return ChangeItem(
    toolName: TaskAgentToolNames.migrateChecklistItem,
    args: {'id': id, 'targetTaskId': targetTaskId},
    humanSummary: 'Migrate checklist item $id',
    status: status,
  );
}

void main() {
  setUpAll(registerAllFallbackValues);

  const subDomain = 'ChangeSetConfirmation';
  final testClock = Clock.fixed(DateTime(2024, 3, 15, 12));

  late MockAgentSyncService mockSyncService;
  late MockAgentRepository mockRepository;
  late MockDomainLogger mockDomainLogger;
  late ChangeSetResolutionStore store;

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockRepository = MockAgentRepository();
    mockDomainLogger = MockDomainLogger();

    when(() => mockSyncService.repository).thenReturn(mockRepository);
    // Default: no persisted entity, so fresh reads fall back to the
    // passed-in change set. Override per test to exercise re-reads.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});

    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);
    when(
      () => mockDomainLogger.error(
        any(),
        any(),
        message: any(named: 'message'),
        subDomain: any(named: 'subDomain'),
        stackTrace: any(named: 'stackTrace'),
      ),
    ).thenReturn(null);

    store = ChangeSetResolutionStore(
      syncService: mockSyncService,
      subDomain: subDomain,
      domainLogger: mockDomainLogger,
    );
  });

  group('captureResolvedId / resolvedIdFor', () {
    test(
      'captures mapping for successful create_follow_up_task and logs',
      () {
        store.captureResolvedId(_createFollowUpItem(), _successResult);

        expect(store.resolvedIdFor('placeholder-1'), 'task-actual-1');
        expect(store.resolvedIdFor('placeholder-other'), isNull);
        verify(
          () => mockDomainLogger.log(
            LogDomain.agentWorkflow,
            any(that: contains('Captured placeholder resolution')),
            subDomain: subDomain,
          ),
        ).called(1);
      },
    );

    final nonCapturingCases =
        <String, ({ChangeItem item, ToolExecutionResult result})>{
          'tool is not create_follow_up_task': (
            item: _migrationItem(id: 'cl-1'),
            result: _successResult,
          ),
          'dispatch result failed': (
            item: _createFollowUpItem(),
            result: const ToolExecutionResult(
              success: false,
              output: 'Error',
              mutatedEntityId: 'task-actual-1',
            ),
          ),
          'placeholder arg missing': (
            item: _createFollowUpItem(placeholderId: null),
            result: _successResult,
          ),
          'mutatedEntityId is null': (
            item: _createFollowUpItem(),
            result: const ToolExecutionResult(success: true, output: 'Created'),
          ),
          'mutatedEntityId is empty': (
            item: _createFollowUpItem(),
            result: const ToolExecutionResult(
              success: true,
              output: 'Created',
              mutatedEntityId: '',
            ),
          ),
        };

    for (final entry in nonCapturingCases.entries) {
      test('does not capture when ${entry.key}', () {
        store.captureResolvedId(entry.value.item, entry.value.result);

        expect(store.resolvedIdFor('placeholder-1'), isNull);
        verifyNever(
          () => mockDomainLogger.log(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
          ),
        );
      });
    }
  });

  group('persistResolvedIdToSiblings', () {
    test(
      'rewrites matching siblings from the latest persisted state and '
      'upserts',
      () async {
        final createItem = _createFollowUpItem();
        // The stale snapshot passed in misses one sibling; the persisted
        // state has two matching migrations plus one with another target.
        final stale = makeTestChangeSet(
          items: [
            createItem,
            _migrationItem(id: 'cl-1'),
          ],
        );
        final fresh = makeTestChangeSet(
          items: [
            createItem,
            _migrationItem(id: 'cl-1'),
            _migrationItem(id: 'cl-2'),
            _migrationItem(id: 'cl-3', targetTaskId: 'task-unrelated'),
          ],
        );
        when(
          () => mockRepository.getEntity(stale.id),
        ).thenAnswer((_) async => fresh);

        await store.persistResolvedIdToSiblings(
          createItem,
          _successResult,
          stale,
        );

        final captured =
            verify(
                  () => mockSyncService.upsertEntity(captureAny()),
                ).captured.single
                as ChangeSetEntity;
        // Re-read state was used (four items, not the stale two).
        expect(captured.items, hasLength(4));
        expect(captured.items[1].args['targetTaskId'], 'task-actual-1');
        expect(captured.items[2].args['targetTaskId'], 'task-actual-1');
        expect(captured.items[3].args['targetTaskId'], 'task-unrelated');
        // Non-target args are preserved on rewrite.
        expect(captured.items[1].args['id'], 'cl-1');
        verify(
          () => mockDomainLogger.log(
            LogDomain.agentWorkflow,
            any(that: contains('Persisted resolved targetTaskId')),
            subDomain: subDomain,
          ),
        ).called(1);
      },
    );

    test(
      'does not upsert when no sibling references the placeholder',
      () async {
        final createItem = _createFollowUpItem();
        final changeSet = makeTestChangeSet(
          items: [
            createItem,
            _migrationItem(id: 'cl-1', targetTaskId: 'task-unrelated'),
          ],
        );
        when(
          () => mockRepository.getEntity(changeSet.id),
        ).thenAnswer((_) async => changeSet);

        await store.persistResolvedIdToSiblings(
          createItem,
          _successResult,
          changeSet,
        );

        verifyNever(() => mockSyncService.upsertEntity(any()));
        verifyNever(
          () => mockDomainLogger.log(
            any(),
            any(),
            subDomain: any(named: 'subDomain'),
          ),
        );
      },
    );

    final guardCases =
        <String, ({ChangeItem item, ToolExecutionResult result})>{
          'tool is not create_follow_up_task': (
            item: _migrationItem(id: 'cl-1'),
            result: _successResult,
          ),
          'dispatch result failed': (
            item: _createFollowUpItem(),
            result: const ToolExecutionResult(success: false, output: 'Error'),
          ),
          'placeholder arg missing': (
            item: _createFollowUpItem(placeholderId: null),
            result: _successResult,
          ),
          'mutatedEntityId is empty': (
            item: _createFollowUpItem(),
            result: const ToolExecutionResult(
              success: true,
              output: 'Created',
              mutatedEntityId: '',
            ),
          ),
        };

    for (final entry in guardCases.entries) {
      test('returns before reading or writing when ${entry.key}', () async {
        final changeSet = makeTestChangeSet(
          items: [
            _createFollowUpItem(),
            _migrationItem(id: 'cl-1'),
          ],
        );

        await store.persistResolvedIdToSiblings(
          entry.value.item,
          entry.value.result,
          changeSet,
        );

        verifyNever(() => mockRepository.getEntity(any()));
        verifyNever(() => mockSyncService.upsertEntity(any()));
      });
    }
  });

  group('cascadeRejectMigrationItems', () {
    test(
      'rejects only pending matching migrations, persisting decision and '
      'status update',
      () async {
        final fresh = makeTestChangeSet(
          items: [
            _createFollowUpItem(status: ChangeItemStatus.rejected),
            _migrationItem(id: 'cl-1'),
            _migrationItem(id: 'cl-2', status: ChangeItemStatus.rejected),
            _migrationItem(id: 'cl-3', targetTaskId: 'task-unrelated'),
            const ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 30},
              humanSummary: 'Set estimate',
            ),
          ],
        );
        when(
          () => mockRepository.getEntity(fresh.id),
        ).thenAnswer((_) async => fresh);

        await withClock(testClock, () async {
          await store.cascadeRejectMigrationItems(
            fresh,
            'placeholder-1',
            'Follow-up task declined',
          );
        });

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(captured, hasLength(2));

        // Claimed like a user rejection: the item, then its decision.
        final decision = captured[1] as ChangeDecisionEntity;
        expect(decision.changeSetId, fresh.id);
        expect(decision.itemIndex, 1);
        expect(decision.toolName, TaskAgentToolNames.migrateChecklistItem);
        expect(decision.verdict, ChangeDecisionVerdict.rejected);
        expect(decision.rejectionReason, 'Follow-up task declined');
        expect(decision.args, fresh.items[1].args);

        final updatedSet = captured[0] as ChangeSetEntity;
        expect(updatedSet.items[1].status, ChangeItemStatus.rejected);
        expect(updatedSet.items[1].revision, 1);
        // Already-resolved and non-matching siblings stay untouched.
        expect(updatedSet.items[2].status, ChangeItemStatus.rejected);
        expect(updatedSet.items[3].status, ChangeItemStatus.pending);
        expect(updatedSet.items[4].status, ChangeItemStatus.pending);
        expect(updatedSet.status, ChangeSetStatus.partiallyResolved);
      },
    );

    test('uses default rejection reason when none is given', () async {
      final fresh = makeTestChangeSet(
        items: [
          _createFollowUpItem(),
          _migrationItem(id: 'cl-1'),
        ],
      );
      when(
        () => mockRepository.getEntity(fresh.id),
      ).thenAnswer((_) async => fresh);

      await withClock(testClock, () async {
        await store.cascadeRejectMigrationItems(fresh, 'placeholder-1', null);
      });

      final decision = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured.whereType<ChangeDecisionEntity>().single;
      expect(decision.rejectionReason, 'Target follow-up task was rejected');
    });
  });

  group('freshChangeSet', () {
    test('returns the latest persisted change set', () async {
      final fallback = makeTestChangeSet();
      final fresh = makeTestChangeSet(status: ChangeSetStatus.resolved);
      when(
        () => mockRepository.getEntity(fallback.id),
      ).thenAnswer((_) async => fresh);

      expect(await store.freshChangeSet(fallback), same(fresh));
    });

    test(
      'deleted chat action sets never recover executable fallback items',
      () async {
        final fallback = makeTestChangeSet(id: 'query-chat:question:actions');
        final fresh = await store.freshChangeSet(fallback);
        expect(fresh.items, isEmpty);
        expect(fresh.deletedAt, isNotNull);
        expect(
          await store.transitionChangeSetItem(
            fallback,
            0,
            from: ChangeItemStatus.values.toSet(),
            to: ChangeItemStatus.pending,
          ),
          isNull,
        );
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test('falls back when the entity is missing', () async {
      final fallback = makeTestChangeSet();

      expect(await store.freshChangeSet(fallback), same(fallback));
    });

    test('falls back when the entity has an unexpected type', () async {
      final fallback = makeTestChangeSet();
      when(
        () => mockRepository.getEntity(fallback.id),
      ).thenAnswer((_) async => makeTestChangeDecision(id: fallback.id));

      expect(await store.freshChangeSet(fallback), same(fallback));
    });
  });

  group('persistDecision', () {
    test(
      'persists and returns a decision with change-set coordinates',
      () async {
        final changeSet = makeTestChangeSet();

        final decision = await withClock(testClock, () {
          return store.persistDecision(
            changeSet: changeSet,
            itemIndex: 1,
            toolName: 'set_task_title',
            verdict: ChangeDecisionVerdict.retracted,
            actor: DecisionActor.agent,
            retractionReason: 'Timer changed',
            humanSummary: 'Set title to "New Title"',
            args: {'title': 'New Title'},
          );
        });

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.single;
        expect(captured, same(decision));
        expect(decision.id, isNotEmpty);
        expect(decision.agentId, changeSet.agentId);
        expect(decision.changeSetId, changeSet.id);
        expect(decision.taskId, changeSet.taskId);
        expect(decision.itemIndex, 1);
        expect(decision.toolName, 'set_task_title');
        expect(decision.verdict, ChangeDecisionVerdict.retracted);
        expect(decision.actor, DecisionActor.agent);
        expect(decision.retractionReason, 'Timer changed');
        expect(decision.humanSummary, 'Set title to "New Title"');
        expect(decision.args, {'title': 'New Title'});
        expect(decision.createdAt, testClock.now());
        expect(decision.vectorClock, const VectorClock({}));
      },
    );

    test('defaults to the user actor', () async {
      final changeSet = makeTestChangeSet();

      final decision = await withClock(testClock, () {
        return store.persistDecision(
          changeSet: changeSet,
          itemIndex: 0,
          toolName: 'update_task_estimate',
          verdict: ChangeDecisionVerdict.confirmed,
        );
      });

      expect(decision.actor, DecisionActor.user);
      expect(decision.rejectionReason, isNull);
      expect(decision.retractionReason, isNull);
    });
  });

  group('transitionChangeSetItem', () {
    test(
      'moves the item on the latest persisted state, bumps its revision and '
      'derives resolution',
      () async {
        final stale = makeTestChangeSet(
          items: [
            _migrationItem(id: 'cl-1'),
            _migrationItem(id: 'cl-2', status: ChangeItemStatus.confirmed),
          ],
        );
        final fresh = makeTestChangeSet(
          items: [
            _migrationItem(id: 'cl-1', status: ChangeItemStatus.confirmed),
            _migrationItem(id: 'cl-2', status: ChangeItemStatus.confirmed),
          ],
        );
        when(
          () => mockRepository.getEntity(stale.id),
        ).thenAnswer((_) async => fresh);

        final updated = await withClock(testClock, () {
          return store.transitionChangeSetItem(
            stale,
            1,
            from: const {ChangeItemStatus.confirmed},
            to: ChangeItemStatus.retracted,
          );
        });

        // The fresh state was used: item 0 keeps its persisted confirmed
        // status that the stale snapshot did not have.
        expect(updated, isNotNull);
        expect(updated!.items[0].status, ChangeItemStatus.confirmed);
        expect(updated.items[0].revision, isNull, reason: 'untouched');
        expect(updated.items[1].status, ChangeItemStatus.retracted);
        expect(updated.items[1].revision, 1);
        expect(updated.status, ChangeSetStatus.resolved);
        expect(updated.resolvedAt, testClock.now());

        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.single;
        expect(captured, same(updated));
      },
    );

    test(
      'with an observed item, leaves an item alone whose revision moved on '
      'even though its status matches again',
      () async {
        final observed = _migrationItem(
          id: 'cl-1',
        ).withStatus(ChangeItemStatus.confirmed);
        // Reopened and confirmed again since: confirmed, two revisions later.
        final changeSet = makeTestChangeSet(
          items: [
            observed
                .withStatus(ChangeItemStatus.pending)
                .withStatus(ChangeItemStatus.confirmed),
          ],
        );

        expect(
          await store.transitionChangeSetItem(
            changeSet,
            0,
            from: const {ChangeItemStatus.confirmed},
            to: ChangeItemStatus.pending,
            observed: observed,
          ),
          isNull,
        );
        final same = await store.transitionChangeSetItem(
          changeSet,
          0,
          from: const {ChangeItemStatus.confirmed},
          to: ChangeItemStatus.pending,
          observed: changeSet.items.single,
        );
        expect(same!.items.single.status, ChangeItemStatus.pending);
        verify(() => mockSyncService.upsertEntity(any())).called(1);
      },
    );

    test(
      'leaves an item alone that is no longer in a from status, so a failed '
      'dispatch cannot undo a decision it did not make',
      () async {
        final changeSet = makeTestChangeSet(
          items: [
            _migrationItem(id: 'cl-1', status: ChangeItemStatus.rejected),
          ],
        );

        final updated = await store.transitionChangeSetItem(
          changeSet,
          0,
          from: const {ChangeItemStatus.confirmed},
          to: ChangeItemStatus.pending,
        );

        expect(updated, isNull);
        verifyNever(() => mockSyncService.upsertEntity(any()));
      },
    );

    test('reads and writes inside one transaction', () async {
      final changeSet = makeTestChangeSet(
        items: [_migrationItem(id: 'cl-1', status: ChangeItemStatus.confirmed)],
      );
      var inTransaction = false;
      mockSyncService.transactionDelegate = <T>(action) async {
        inTransaction = true;
        try {
          return await action();
        } finally {
          inTransaction = false;
        }
      };
      when(() => mockRepository.getEntity(changeSet.id)).thenAnswer((_) async {
        expect(inTransaction, isTrue, reason: 'read inside the transaction');
        return changeSet;
      });
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {
        expect(inTransaction, isTrue, reason: 'write inside the transaction');
      });

      final updated = await store.transitionChangeSetItem(
        changeSet,
        0,
        from: const {ChangeItemStatus.confirmed},
        to: ChangeItemStatus.pending,
      );

      expect(updated!.items.single.status, ChangeItemStatus.pending);
    });

    for (final index in [-1, 2]) {
      test(
        'returns null without persisting for out-of-range index $index',
        () async {
          final changeSet = makeTestChangeSet(
            items: [
              _migrationItem(id: 'cl-1'),
              _migrationItem(id: 'cl-2'),
            ],
          );

          final updated = await withClock(testClock, () {
            return store.transitionChangeSetItem(
              changeSet,
              index,
              from: const {ChangeItemStatus.pending},
              to: ChangeItemStatus.rejected,
            );
          });

          expect(updated, isNull);
          verifyNever(() => mockSyncService.upsertEntity(any()));
        },
      );
    }
  });

  group('claimChangeSetItem', () {
    /// Serializes transactions the way Drift does, and makes the repository
    /// return the last upserted version of [initial].
    void serializeOver(ChangeSetEntity initial) {
      var stored = initial;
      var tail = Future<void>.value();
      mockSyncService.transactionDelegate = <T>(action) {
        final run = tail.then((_) => action());
        tail = run.then<void>((_) {}, onError: (_) {});
        return run;
      };
      when(
        () => mockRepository.getEntity(initial.id),
      ).thenAnswer((_) async => stored);
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        stored = invocation.positionalArguments.first as ChangeSetEntity;
      });
    }

    test(
      'moves a pending item to confirmed inside one transaction',
      () async {
        final changeSet = makeTestChangeSet(
          items: [
            _migrationItem(id: 'cl-1', status: ChangeItemStatus.rejected),
            _migrationItem(id: 'cl-2'),
          ],
        );
        var inTransaction = false;
        mockSyncService.transactionDelegate = <T>(action) async {
          inTransaction = true;
          try {
            return await action();
          } finally {
            inTransaction = false;
          }
        };
        when(() => mockRepository.getEntity(changeSet.id)).thenAnswer((
          _,
        ) async {
          expect(inTransaction, isTrue, reason: 'check and set are atomic');
          return changeSet;
        });

        final claimed = await withClock(
          testClock,
          () => store.claimChangeSetItem(changeSet, 1),
        );

        expect(claimed!.items[1].status, ChangeItemStatus.confirmed);
        expect(claimed.status, ChangeSetStatus.resolved);
        expect(claimed.resolvedAt, testClock.now());
        final captured = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.single;
        expect(captured, same(claimed));
      },
    );

    test(
      'claims with the resolved target as one change, which the sibling '
      'rewrite then leaves alone',
      () async {
        // ChangeSetLifecycle.tla, ClaimResolvesTarget.
        final createItem = _createFollowUpItem(
          status: ChangeItemStatus.confirmed,
        );
        final initial = makeTestChangeSet(
          items: [
            createItem,
            _migrationItem(id: 'cl-1'),
          ],
        );
        serializeOver(initial);

        final claimed = (await withClock(
          testClock,
          () => store.claimChangeSetItem(
            initial,
            1,
            args: {'id': 'cl-1', 'targetTaskId': 'task-actual-1'},
          ),
        ))!;
        await withClock(
          testClock,
          () => store.persistResolvedIdToSiblings(
            createItem,
            _successResult,
            initial,
          ),
        );
        final reverted = await withClock(
          testClock,
          () => store.transitionChangeSetItem(
            initial,
            1,
            from: const {ChangeItemStatus.confirmed},
            to: ChangeItemStatus.pending,
            observed: claimed.items[1],
          ),
        );

        expect(claimed.items[1].revision, 1);
        expect(claimed.items[1].args['targetTaskId'], 'task-actual-1');
        // Only the claim wrote the set before the revert.
        verify(() => mockSyncService.upsertEntity(any())).called(2);
        expect(reverted!.items[1].status, ChangeItemStatus.pending);
        expect(reverted.items[1].args['targetTaskId'], 'task-actual-1');
      },
    );

    for (final status in [
      ChangeItemStatus.confirmed,
      ChangeItemStatus.rejected,
      ChangeItemStatus.retracted,
    ]) {
      test(
        'loses without writing when the persisted item is ${status.name}',
        () async {
          final snapshot = makeTestChangeSet(items: [_migrationItem(id: 'a')]);
          when(() => mockRepository.getEntity(snapshot.id)).thenAnswer(
            (_) async => snapshot.copyWith(
              items: [_migrationItem(id: 'a', status: status)],
            ),
          );

          final claimed = await store.claimChangeSetItem(snapshot, 0);

          expect(claimed, isNull);
          verifyNever(() => mockSyncService.upsertEntity(any()));
        },
      );
    }

    test('judges an unpersisted set by the caller snapshot', () async {
      final snapshot = makeTestChangeSet(items: [_migrationItem(id: 'a')]);

      final claimed = await store.claimChangeSetItem(snapshot, 0);

      expect(claimed!.items.single.status, ChangeItemStatus.confirmed);
    });

    test('refuses a deleted query-chat set', () async {
      final snapshot = makeTestChangeSet(
        id: 'query-chat:question:actions',
        items: [_migrationItem(id: 'a')],
      );

      final claimed = await store.claimChangeSetItem(snapshot, 0);

      expect(claimed, isNull);
      verifyNever(() => mockSyncService.upsertEntity(any()));
    });

    for (final index in [-1, 1]) {
      test('refuses out-of-range index $index', () async {
        final snapshot = makeTestChangeSet(items: [_migrationItem(id: 'a')]);

        expect(await store.claimChangeSetItem(snapshot, index), isNull);
        verifyNever(() => mockSyncService.upsertEntity(any()));
      });
    }

    test('of two concurrent claims on one item exactly one wins', () async {
      // Regression for ChangeSetConfirm.tla AtMostOnceApply: both confirms
      // read "pending" before either wrote, and both dispatched the tool.
      final changeSet = makeTestChangeSet(items: [_migrationItem(id: 'a')]);
      serializeOver(changeSet);

      final results = await withClock(
        testClock,
        () => Future.wait([
          store.claimChangeSetItem(changeSet, 0),
          store.claimChangeSetItem(changeSet, 0),
        ]),
      );

      expect(results.whereType<ChangeSetEntity>(), hasLength(1));
      verify(() => mockSyncService.upsertEntity(any())).called(1);
    });
  });

  group('notifyChangeSetResolved', () {
    test(
      'invokes the callback with the freshest persisted change set',
      () async {
        final fallback = makeTestChangeSet();
        final fresh = makeTestChangeSet(status: ChangeSetStatus.resolved);
        when(
          () => mockRepository.getEntity(fallback.id),
        ).thenAnswer((_) async => fresh);

        final received = <ChangeSetEntity>[];
        await store.notifyChangeSetResolved(fallback, (changeSet) async {
          received.add(changeSet);
        });

        expect(received.single, same(fresh));
      },
    );

    test('is a no-op when the callback is null', () async {
      await store.notifyChangeSetResolved(makeTestChangeSet(), null);

      verifyNever(() => mockRepository.getEntity(any()));
    });

    test('logs and swallows callback errors', () async {
      final fallback = makeTestChangeSet();

      await store.notifyChangeSetResolved(fallback, (_) async {
        throw StateError('listener exploded');
      });

      verify(
        () => mockDomainLogger.error(
          LogDomain.agentWorkflow,
          any(that: isA<StateError>()),
          message: any(
            named: 'message',
            that: contains('Post-resolution notification sync failed'),
          ),
          subDomain: subDomain,
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('writers racing a claim (ChangeSetLifecycle.tla)', () {
    late ChangeSetEntity stored;
    late Completer<void> gate;

    /// Storage for [initial] with Drift-like serialized transactions. The
    /// read number [gatedRead] returns the state as it was when it was made,
    /// but only once [gate] completes: the await between a writer's read and
    /// its write, which another writer can slip into.
    void storeWithGatedRead(ChangeSetEntity initial, {required int gatedRead}) {
      stored = initial;
      gate = Completer<void>();
      var reads = 0;
      var tail = Future<void>.value();
      mockSyncService.transactionDelegate = <T>(action) {
        if (Zone.current[#storeTx] == true) return action();
        final run = tail.then(
          (_) => runZoned(action, zoneValues: {#storeTx: true}),
        );
        tail = run.then<void>((_) {}, onError: (_) {});
        return run;
      };
      when(() => mockRepository.getEntity(initial.id)).thenAnswer((_) async {
        final snapshot = stored;
        reads++;
        if (reads == gatedRead) await gate.future;
        return snapshot;
      });
      when(() => mockSyncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity = invocation.positionalArguments.first;
        if (entity is ChangeSetEntity) stored = entity;
      });
    }

    test(
      'the sibling rewrite keeps a migration claimed while it ran',
      () async {
        // The rewrite read the set with the migration pending; the migration
        // was claimed (and applied) before the rewrite wrote the set back,
        // which put it back to pending — a retry would apply it again.
        final createItem = _createFollowUpItem(
          status: ChangeItemStatus.confirmed,
        );
        storeWithGatedRead(
          makeTestChangeSet(
            items: [
              createItem,
              _migrationItem(id: 'cl-1'),
            ],
          ),
          gatedRead: 1,
        );

        await withClock(testClock, () async {
          final rewrite = store.persistResolvedIdToSiblings(
            createItem,
            _successResult,
            stored,
          );
          await pumpEventQueue();
          final claim = store.claimChangeSetItem(stored, 1);
          await pumpEventQueue();
          gate.complete();
          await Future.wait([rewrite, claim]);
        });

        final migration = stored.items[1];
        expect(migration.status, ChangeItemStatus.confirmed);
        expect(migration.args['targetTaskId'], 'task-actual-1');
        expect(migration.revision, 2, reason: 'rewrite, then claim');
      },
    );

    test(
      'the migration cascade keeps a sibling claimed while it ran',
      () async {
        // The cascade read the set to reject the migration; another item was
        // claimed before the cascade wrote the set back, and went back to
        // pending.
        storeWithGatedRead(
          makeTestChangeSet(
            items: [
              _createFollowUpItem(status: ChangeItemStatus.rejected),
              _migrationItem(id: 'cl-1'),
              const ChangeItem(
                toolName: 'update_task_estimate',
                args: {'minutes': 30},
                humanSummary: 'Set estimate',
              ),
            ],
          ),
          // The cascade's first read finds the migration; the second is the
          // one its write is based on.
          gatedRead: 2,
        );

        await withClock(testClock, () async {
          final cascade = store.cascadeRejectMigrationItems(
            stored,
            'placeholder-1',
            null,
          );
          await pumpEventQueue();
          final claim = store.claimChangeSetItem(stored, 2);
          await pumpEventQueue();
          gate.complete();
          await Future.wait([cascade, claim]);
        });

        expect(stored.items[1].status, ChangeItemStatus.rejected);
        expect(stored.items[2].status, ChangeItemStatus.confirmed);
      },
    );
  });
}
