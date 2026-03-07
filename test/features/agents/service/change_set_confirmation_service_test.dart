import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService mockSyncService;
  late MockTaskToolDispatcher mockToolDispatcher;
  late MockAgentRepository mockRepository;
  late MockLabelsRepository mockLabelsRepository;
  late ChangeSetConfirmationService service;

  final testClock = Clock.fixed(DateTime(2024, 6, 15, 12));

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockToolDispatcher = MockTaskToolDispatcher();
    mockRepository = MockAgentRepository();
    mockLabelsRepository = MockLabelsRepository();

    when(() => mockSyncService.repository).thenReturn(mockRepository);

    // Default stub: getEntity returns null so _updateChangeSetItemStatus
    // falls back to the passed-in changeSet. Override in specific tests
    // when testing the re-read behavior.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

    service = ChangeSetConfirmationService(
      syncService: mockSyncService,
      toolDispatcher: mockToolDispatcher,
      labelsRepository: mockLabelsRepository,
    );
  });

  ChangeSetEntity makeChangeSetWith({
    List<ChangeItem>? items,
  }) {
    return makeTestChangeSet(
      items:
          items ??
          const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 120},
              humanSummary: 'Set estimate to 2 hours',
            ),
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'New Title'},
              humanSummary: 'Set title to "New Title"',
            ),
          ],
    );
  }

  group('ChangeSetConfirmationService', () {
    group('confirmItem', () {
      test('persists decision before dispatch and returns result', () async {
        final changeSet = makeChangeSetWith();
        final upsertOrder = <String>[];

        when(
          () => mockToolDispatcher.dispatch(
            any(),
            any(),
            any(),
          ),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Estimate set to 120 minutes',
          ),
        );

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((invocation) async {
          final entity = invocation.positionalArguments[0];
          if (entity is ChangeDecisionEntity) {
            upsertOrder.add('decision');
          } else if (entity is ChangeSetEntity) {
            upsertOrder.add('changeSet');
          }
        });

        await withClock(testClock, () async {
          final result = await service.confirmItem(changeSet, 0);

          expect(result.success, isTrue);
          expect(result.output, 'Estimate set to 120 minutes');

          // Decision and status update are persisted BEFORE tool dispatch
          // to prevent duplicate side effects on crash/retry.
          expect(upsertOrder, ['decision', 'changeSet']);

          // Verify tool dispatch was called with the correct args.
          verify(
            () => mockToolDispatcher.dispatch(
              'update_task_estimate',
              {'minutes': 120},
              'task-001',
            ),
          ).called(1);

          // Verify decision entity was persisted.
          final decisionCapture = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          // Two calls: decision entity + updated change set.
          expect(decisionCapture, hasLength(2));

          final decision = decisionCapture[0] as ChangeDecisionEntity;
          expect(decision.verdict, ChangeDecisionVerdict.confirmed);
          expect(decision.itemIndex, 0);
          expect(decision.toolName, 'update_task_estimate');

          final updatedChangeSet = decisionCapture[1] as ChangeSetEntity;
          expect(
            updatedChangeSet.items[0].status,
            ChangeItemStatus.confirmed,
          );
          expect(
            updatedChangeSet.status,
            ChangeSetStatus.partiallyResolved,
          );
        });
      });

      test('reverts item to pending when tool dispatch fails', () async {
        final changeSet = makeChangeSetWith();

        when(
          () => mockToolDispatcher.dispatch(any(), any(), any()),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: false,
            output: 'Task not found',
            errorMessage: 'Task lookup failed',
          ),
        );

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        await withClock(testClock, () async {
          final result = await service.confirmItem(changeSet, 0);

          expect(result.success, isFalse);
          expect(result.output, 'Task not found');

          // Decision + status were persisted before dispatch, then status
          // was reverted on failure. Expect 3 upsert calls:
          // 1. decision, 2. confirmed status, 3. reverted to pending.
          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          expect(captured, hasLength(3));

          // First: decision entity
          expect(captured[0], isA<ChangeDecisionEntity>());

          // Second: item marked as confirmed
          final confirmedSet = captured[1] as ChangeSetEntity;
          expect(
            confirmedSet.items[0].status,
            ChangeItemStatus.confirmed,
          );

          // Third: reverted back to pending
          final revertedSet = captured[2] as ChangeSetEntity;
          expect(
            revertedSet.items[0].status,
            ChangeItemStatus.pending,
          );
        });
      });

      test('skips already-confirmed item without dispatching', () async {
        final changeSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 120},
              humanSummary: 'Already done',
              status: ChangeItemStatus.confirmed,
            ),
          ],
        );

        await withClock(testClock, () async {
          final result = await service.confirmItem(changeSet, 0);

          expect(result.success, isFalse);
          expect(result.output, contains('already confirmed'));

          // No tool dispatch or persistence.
          verifyNever(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          );
          verifyNever(
            () => mockSyncService.upsertEntity(any()),
          );
        });
      });

      test('returns failure for out-of-bounds item index', () async {
        final changeSet = makeChangeSetWith();

        await withClock(testClock, () async {
          final result = await service.confirmItem(changeSet, 5);

          expect(result.success, isFalse);
          expect(result.output, 'Invalid change item index');

          verifyNever(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          );
          verifyNever(
            () => mockSyncService.upsertEntity(any()),
          );
        });
      });

      test('returns failure for negative item index', () async {
        final changeSet = makeChangeSetWith();

        await withClock(testClock, () async {
          final result = await service.confirmItem(changeSet, -1);

          expect(result.success, isFalse);
          expect(result.output, 'Invalid change item index');
        });
      });

      test('marks set as resolved when last item is confirmed', () async {
        final changeSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 60},
              humanSummary: 'Set estimate to 1 hour',
              status: ChangeItemStatus.rejected,
            ),
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Last'},
              humanSummary: 'Set title to "Last"',
            ),
          ],
        );

        when(
          () => mockToolDispatcher.dispatch(any(), any(), any()),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Done',
          ),
        );

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        await withClock(testClock, () async {
          await service.confirmItem(changeSet, 1);

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          // Two upserts: decision + change set status update (before dispatch).
          expect(captured, hasLength(2));

          final updatedChangeSet = captured[1] as ChangeSetEntity;
          expect(updatedChangeSet.status, ChangeSetStatus.resolved);
          expect(updatedChangeSet.resolvedAt, isNotNull);
        });
      });
    });

    group('rejectItem', () {
      test('persists rejected decision without tool dispatch', () async {
        final changeSet = makeChangeSetWith();

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        await withClock(testClock, () async {
          final applied = await service.rejectItem(
            changeSet,
            0,
            reason: 'Not needed',
          );

          expect(applied, isTrue);

          // Verify tool dispatch was NOT called.
          verifyNever(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          );

          final captured = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;

          expect(captured, hasLength(2));

          final decision = captured[0] as ChangeDecisionEntity;
          expect(decision.verdict, ChangeDecisionVerdict.rejected);
          expect(decision.rejectionReason, 'Not needed');

          final updatedChangeSet = captured[1] as ChangeSetEntity;
          expect(
            updatedChangeSet.items[0].status,
            ChangeItemStatus.rejected,
          );
          expect(
            updatedChangeSet.status,
            ChangeSetStatus.partiallyResolved,
          );
        });
      });
    });

    group('confirmAll', () {
      test('confirms all pending items and returns results', () async {
        final changeSet = makeChangeSetWith();
        final partiallyResolved = changeSet.copyWith(
          items: [
            changeSet.items[0].copyWith(status: ChangeItemStatus.confirmed),
            changeSet.items[1],
          ],
          status: ChangeSetStatus.partiallyResolved,
        );

        when(
          () => mockToolDispatcher.dispatch(any(), any(), any()),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Done',
          ),
        );

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        // Sequential answers:
        // Call 1: confirmAll's _freshChangeSet — return original (both pending)
        // Call 2: confirmItem's _freshChangeSet for item 0 — return original
        // Subsequent calls: return the partially-resolved set.
        var getEntityCallCount = 0;
        when(
          () => mockRepository.getEntity(changeSet.id),
        ).thenAnswer((_) async {
          getEntityCallCount++;
          if (getEntityCallCount <= 2) return changeSet;
          return partiallyResolved;
        });

        await withClock(testClock, () async {
          final results = await service.confirmAll(changeSet);

          expect(results, hasLength(2));
          expect(results[0].success, isTrue);
          expect(results[1].success, isTrue);

          // Verify two tool dispatches happened.
          verify(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).called(2);
        });
      });

      test('skips already-resolved items', () async {
        final changeSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 60},
              humanSummary: 'Already confirmed',
              status: ChangeItemStatus.confirmed,
            ),
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Pending'},
              humanSummary: 'Still pending',
            ),
          ],
        );

        when(
          () => mockToolDispatcher.dispatch(any(), any(), any()),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Done',
          ),
        );

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        when(
          () => mockRepository.getEntity(changeSet.id),
        ).thenAnswer((_) async => changeSet);

        await withClock(testClock, () async {
          final results = await service.confirmAll(changeSet);

          // Only one pending item should be confirmed.
          expect(results, hasLength(1));
          verify(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).called(1);
        });
      });
      test('returns empty when no items are pending', () async {
        final changeSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 60},
              humanSummary: 'Already confirmed',
              status: ChangeItemStatus.confirmed,
            ),
            ChangeItem(
              toolName: 'set_task_title',
              args: {'title': 'Rejected'},
              humanSummary: 'Already rejected',
              status: ChangeItemStatus.rejected,
            ),
          ],
        );

        await withClock(testClock, () async {
          final results = await service.confirmAll(changeSet);

          expect(results, isEmpty);
          verifyNever(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          );
          verifyNever(
            () => mockSyncService.upsertEntity(any()),
          );
        });
      });

      test('handles null repo re-read gracefully', () async {
        final changeSet = makeChangeSetWith();

        when(
          () => mockToolDispatcher.dispatch(any(), any(), any()),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Done',
          ),
        );

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        // getEntity returns null — confirmAll should still proceed
        // using the passed-in changeSet.
        when(
          () => mockRepository.getEntity(changeSet.id),
        ).thenAnswer((_) async => null);

        await withClock(testClock, () async {
          final results = await service.confirmAll(changeSet);

          // Both items confirmed (second iteration uses original changeSet
          // since repo returned null).
          expect(results, hasLength(2));
        });
      });
    });

    group('placeholder ID resolution', () {
      test(
        'confirmItem resolves placeholder targetTaskId for migration items',
        () async {
          // Create a change set with a create_follow_up_task item followed by
          // a migrate_checklist_item that references a placeholder.
          const placeholderId = 'placeholder-uuid-001';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Follow-Up',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create follow-up task',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-001',
                  'title': 'Buy milk',
                  'targetTaskId': placeholderId,
                },
                humanSummary: 'Migrate "Buy milk"',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          // First call: create_follow_up_task succeeds with actual ID.
          when(
            () => mockToolDispatcher.dispatch(
              'create_follow_up_task',
              any(),
              any(),
            ),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Created follow-up',
              mutatedEntityId: 'actual-task-id-999',
            ),
          );

          // Second call: migrate_checklist_item with resolved targetTaskId.
          when(
            () => mockToolDispatcher.dispatch(
              'migrate_checklist_item',
              any(),
              any(),
            ),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Migrated item',
            ),
          );

          // confirmAll re-reads: return updated change set after each confirm.
          var callCount = 0;
          when(
            () => mockRepository.getEntity(changeSet.id),
          ).thenAnswer((_) async {
            callCount++;
            // First few calls return original, later calls return
            // partially resolved.
            if (callCount <= 2) return changeSet;
            return changeSet.copyWith(
              items: [
                changeSet.items[0].copyWith(
                  status: ChangeItemStatus.confirmed,
                ),
                changeSet.items[1],
              ],
              status: ChangeSetStatus.partiallyResolved,
            );
          });

          await withClock(testClock, () async {
            final results = await service.confirmAll(changeSet);

            expect(results, hasLength(2));
            expect(results[0].success, isTrue);
            expect(results[1].success, isTrue);

            // Verify the migration dispatch received the resolved ID.
            final migrateCapture = verify(
              () => mockToolDispatcher.dispatch(
                'migrate_checklist_item',
                captureAny(),
                any(),
              ),
            ).captured;

            final migrateArgs = migrateCapture[0] as Map<String, dynamic>;
            expect(migrateArgs['targetTaskId'], 'actual-task-id-999');
          });
        },
      );

      test(
        'confirmItem returns failure for unresolved migration placeholder',
        () async {
          // Migration item with a create_follow_up_task that hasn't been
          // confirmed yet. The placeholder is in _resolvedIds = {}, so
          // confirmItem should return a clear error without dispatching.
          const placeholderId = 'unresolved-placeholder';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Pending Task',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create pending task',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-002',
                  'title': 'Walk dog',
                  'targetTaskId': placeholderId,
                },
                humanSummary: 'Migrate "Walk dog"',
              ),
            ],
          );

          await withClock(testClock, () async {
            // Confirm the migration item (index 1), not the create item.
            final result = await service.confirmItem(changeSet, 1);

            expect(result.success, isFalse);
            expect(
              result.output,
              contains('target task has not been created yet'),
            );
            expect(
              result.errorMessage,
              'Unresolved placeholder targetTaskId',
            );

            // No dispatch should have been attempted.
            verifyNever(
              () => mockToolDispatcher.dispatch(any(), any(), any()),
            );
          });
        },
      );

      test(
        'captureResolvedId stores mapping from placeholder to actual ID',
        () async {
          const placeholderId = 'placeholder-002';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Task B',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create task B',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Created',
              mutatedEntityId: 'resolved-id-002',
            ),
          );

          await withClock(testClock, () async {
            await service.confirmItem(changeSet, 0);

            // Now confirm a migration item that references the placeholder.
            final migrationSet = makeTestChangeSet(
              id: 'cs-002',
              items: const [
                ChangeItem(
                  toolName: 'migrate_checklist_item',
                  args: {
                    'id': 'item-005',
                    'title': 'Test item',
                    'targetTaskId': placeholderId,
                  },
                  humanSummary: 'Migrate test item',
                ),
              ],
            );

            when(
              () => mockRepository.getEntity('cs-002'),
            ).thenAnswer((_) async => null);

            when(
              () => mockToolDispatcher.dispatch(
                'migrate_checklist_item',
                any(),
                any(),
              ),
            ).thenAnswer(
              (_) async => const ToolExecutionResult(
                success: true,
                output: 'Migrated',
              ),
            );

            await service.confirmItem(migrationSet, 0);

            // Verify the resolved ID was used.
            final captured = verify(
              () => mockToolDispatcher.dispatch(
                'migrate_checklist_item',
                captureAny(),
                any(),
              ),
            ).captured;

            final args = captured[0] as Map<String, dynamic>;
            expect(args['targetTaskId'], 'resolved-id-002');
          });
        },
      );

      test(
        'persists resolved targetTaskId to sibling migration items',
        () async {
          const placeholderId = 'placeholder-persist';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Persist Task',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create persist task',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-010',
                  'title': 'Migrate me',
                  'targetTaskId': placeholderId,
                },
                humanSummary: 'Migrate "Migrate me"',
              ),
            ],
          );

          final upsertedEntities = <AgentDomainEntity>[];
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((invocation) async {
            upsertedEntities.add(
              invocation.positionalArguments[0] as AgentDomainEntity,
            );
          });

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Created follow-up',
              mutatedEntityId: 'actual-persist-id',
            ),
          );

          await withClock(testClock, () async {
            await service.confirmItem(changeSet, 0);
          });

          // Find the change set upsert that updated sibling args.
          final persistedSets = upsertedEntities
              .whereType<ChangeSetEntity>()
              .toList();

          // The last change set upsert should have the migration item's
          // targetTaskId resolved.
          final lastSet = persistedSets.last;
          final migrationItem = lastSet.items.firstWhere(
            (i) => i.toolName == 'migrate_checklist_item',
          );
          expect(
            migrationItem.args['targetTaskId'],
            'actual-persist-id',
            reason:
                'Sibling migration items should be updated with '
                'the actual task ID',
          );
        },
      );

      test(
        'new service instance confirms migration items with '
        'already-resolved args',
        () async {
          // Simulate a service restart: migration items have already been
          // updated with the real targetTaskId by _persistResolvedIdToSiblings.
          const realTaskId = 'real-task-id-999';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Already Created',
                  '_placeholderTaskId': 'old-placeholder',
                },
                humanSummary: 'Create task',
                status: ChangeItemStatus.confirmed,
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-020',
                  'title': 'Already resolved',
                  'targetTaskId': realTaskId,
                },
                humanSummary: 'Migrate "Already resolved"',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          when(
            () => mockToolDispatcher.dispatch(
              'migrate_checklist_item',
              any(),
              any(),
            ),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Migrated',
            ),
          );

          // Fresh service instance — _resolvedIds is empty.
          final freshService = ChangeSetConfirmationService(
            syncService: mockSyncService,
            toolDispatcher: mockToolDispatcher,
            labelsRepository: mockLabelsRepository,
          );

          await withClock(testClock, () async {
            final result = await freshService.confirmItem(changeSet, 1);

            expect(
              result.success,
              isTrue,
              reason: 'Should dispatch with the already-resolved real ID',
            );

            final captured = verify(
              () => mockToolDispatcher.dispatch(
                'migrate_checklist_item',
                captureAny(),
                any(),
              ),
            ).captured;

            final args = captured[0] as Map<String, dynamic>;
            expect(args['targetTaskId'], realTaskId);
          });
        },
      );
    });

    group('rejectItem - edge cases', () {
      test('returns false for out-of-bounds item index', () async {
        final changeSet = makeChangeSetWith();

        await withClock(testClock, () async {
          final applied = await service.rejectItem(changeSet, 10);

          expect(applied, isFalse);
          verifyNever(
            () => mockSyncService.upsertEntity(any()),
          );
        });
      });

      test('skips already-rejected item and returns false', () async {
        final changeSet = makeTestChangeSet(
          items: const [
            ChangeItem(
              toolName: 'update_task_estimate',
              args: {'minutes': 120},
              humanSummary: 'Already rejected',
              status: ChangeItemStatus.rejected,
            ),
          ],
        );

        await withClock(testClock, () async {
          final applied = await service.rejectItem(changeSet, 0);

          expect(applied, isFalse);
          verifyNever(
            () => mockSyncService.upsertEntity(any()),
          );
        });
      });
    });

    group('rejectItem - label suppression', () {
      test(
        'rejecting an assign_task_label item suppresses the label',
        () async {
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'assign_task_label',
                args: {'id': 'label-bug', 'confidence': 'high'},
                humanSummary: 'Assign label: "Bug" (high)',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          when(
            () => mockLabelsRepository.suppressLabelOnTask(
              taskId: any(named: 'taskId'),
              labelId: any(named: 'labelId'),
            ),
          ).thenAnswer((_) async => true);

          await withClock(testClock, () async {
            final applied = await service.rejectItem(changeSet, 0);

            expect(applied, isTrue);

            // Verify suppress was called with the correct args.
            verify(
              () => mockLabelsRepository.suppressLabelOnTask(
                taskId: 'task-001',
                labelId: 'label-bug',
              ),
            ).called(1);
          });
        },
      );

      test(
        'rejecting a non-label item does not call suppressLabelOnTask',
        () async {
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'update_task_estimate',
                args: {'minutes': 120},
                humanSummary: 'Set estimate to 2 hours',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            await service.rejectItem(changeSet, 0);

            verifyNever(
              () => mockLabelsRepository.suppressLabelOnTask(
                taskId: any(named: 'taskId'),
                labelId: any(named: 'labelId'),
              ),
            );
          });
        },
      );
    });
  });
}
