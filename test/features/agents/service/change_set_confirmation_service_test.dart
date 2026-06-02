import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/tools/agent_tool_executor.dart';
import 'package:lotti/features/agents/tools/agent_tool_registry.dart';
import 'package:lotti/features/agents/tools/running_timer_update_handler.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedCascadeItemKind { matchingMigration, otherMigration, otherTool }

class _GeneratedCascadeSibling {
  const _GeneratedCascadeSibling({
    required this.kind,
    required this.status,
    required this.seed,
  });

  final _GeneratedCascadeItemKind kind;
  final ChangeItemStatus status;
  final int seed;

  bool get shouldCascade =>
      kind == _GeneratedCascadeItemKind.matchingMigration &&
      status == ChangeItemStatus.pending;

  ChangeItem item(String placeholderId) {
    return switch (kind) {
      _GeneratedCascadeItemKind.matchingMigration => ChangeItem(
        toolName: TaskAgentToolNames.migrateChecklistItem,
        args: {
          'id': 'item-$seed',
          'title': 'Generated item $seed',
          'targetTaskId': placeholderId,
        },
        humanSummary: 'Migrate generated item $seed',
        status: status,
      ),
      _GeneratedCascadeItemKind.otherMigration => ChangeItem(
        toolName: TaskAgentToolNames.migrateChecklistItem,
        args: {
          'id': 'item-$seed',
          'title': 'Generated item $seed',
          'targetTaskId': 'other-placeholder-$seed',
        },
        humanSummary: 'Migrate generated item $seed elsewhere',
        status: status,
      ),
      _GeneratedCascadeItemKind.otherTool => ChangeItem(
        toolName: TaskAgentToolNames.updateTaskEstimate,
        args: {'minutes': 15 + seed % 240},
        humanSummary: 'Set estimate for generated item $seed',
        status: status,
      ),
    };
  }

  ChangeItemStatus expectedStatus({required bool createRejected}) {
    if (createRejected && shouldCascade) {
      return ChangeItemStatus.rejected;
    }
    return status;
  }

  @override
  String toString() {
    return '_GeneratedCascadeSibling('
        'kind: $kind, status: $status, seed: $seed)';
  }
}

class _GeneratedCascadeScenario {
  const _GeneratedCascadeScenario({
    required this.createStatus,
    required this.siblings,
  });

  static const placeholderId = 'generated-placeholder';

  final ChangeItemStatus createStatus;
  final List<_GeneratedCascadeSibling> siblings;

  bool get shouldApply => createStatus == ChangeItemStatus.pending;

  List<ChangeItem> get items => [
    ChangeItem(
      toolName: TaskAgentToolNames.createFollowUpTask,
      args: const {
        'title': 'Generated split task',
        '_placeholderTaskId': placeholderId,
      },
      humanSummary: 'Create generated split task',
      status: createStatus,
    ),
    for (final sibling in siblings) sibling.item(placeholderId),
  ];

  List<ChangeItemStatus> get expectedStatuses {
    if (!shouldApply) {
      return items.map((item) => item.status).toList(growable: false);
    }
    return [
      ChangeItemStatus.rejected,
      for (final sibling in siblings)
        sibling.expectedStatus(createRejected: true),
    ];
  }

  int get expectedDecisionCount {
    if (!shouldApply) return 0;
    return 1 + siblings.where((sibling) => sibling.shouldCascade).length;
  }

  ChangeSetStatus? get expectedSetStatus {
    if (!shouldApply) return null;
    final statuses = expectedStatuses;
    final anyResolved = statuses.any(
      (status) => status != ChangeItemStatus.pending,
    );
    if (!anyResolved) return ChangeSetStatus.pending;

    final allResolved = statuses.every(
      (status) => status != ChangeItemStatus.pending,
    );
    return allResolved
        ? ChangeSetStatus.resolved
        : ChangeSetStatus.partiallyResolved;
  }

  @override
  String toString() {
    return '_GeneratedCascadeScenario('
        'createStatus: $createStatus, siblings: $siblings)';
  }
}

extension _AnyGeneratedCascadeScenario on glados.Any {
  glados.Generator<ChangeItemStatus> get changeItemStatus =>
      glados.AnyUtils(this).choose(ChangeItemStatus.values);

  glados.Generator<_GeneratedCascadeItemKind> get cascadeItemKind =>
      glados.AnyUtils(this).choose(_GeneratedCascadeItemKind.values);

  glados.Generator<_GeneratedCascadeSibling> get cascadeSibling =>
      glados.CombinableAny(this).combine3(
        cascadeItemKind,
        changeItemStatus,
        glados.IntAnys(this).intInRange(0, 1000),
        (
          _GeneratedCascadeItemKind kind,
          ChangeItemStatus status,
          int seed,
        ) => _GeneratedCascadeSibling(
          kind: kind,
          status: status,
          seed: seed,
        ),
      );

  glados.Generator<_GeneratedCascadeScenario> get cascadeScenario =>
      glados.CombinableAny(this).combine2(
        changeItemStatus,
        glados.ListAnys(
          this,
        ).listWithLengthInRange(0, 7, cascadeSibling),
        (
          ChangeItemStatus createStatus,
          List<_GeneratedCascadeSibling> siblings,
        ) => _GeneratedCascadeScenario(
          createStatus: createStatus,
          siblings: siblings,
        ),
      );
}

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService mockSyncService;
  late MockTaskToolDispatcher mockToolDispatcher;
  late MockAgentRepository mockRepository;
  late MockLabelsRepository mockLabelsRepository;
  late MockDomainLogger mockDomainLogger;
  late ChangeSetConfirmationService service;

  final testClock = Clock.fixed(DateTime(2024, 6, 15, 12));

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockToolDispatcher = MockTaskToolDispatcher();
    mockRepository = MockAgentRepository();
    mockLabelsRepository = MockLabelsRepository();
    mockDomainLogger = MockDomainLogger();

    when(() => mockSyncService.repository).thenReturn(mockRepository);

    // Default stub: getEntity returns null so _updateChangeSetItemStatus
    // falls back to the passed-in changeSet. Override in specific tests
    // when testing the re-read behavior.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);

    // Stub DomainLogger methods.
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

    service = ChangeSetConfirmationService(
      syncService: mockSyncService,
      toolDispatcher: mockToolDispatcher.dispatch,
      labelsRepository: mockLabelsRepository,
      domainLogger: mockDomainLogger,
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

      test(
        'returns failure when reverting failed dispatch to pending cannot '
        'be persisted',
        () async {
          final changeSet = makeChangeSetWith();
          var readCount = 0;

          when(() => mockRepository.getEntity(changeSet.id)).thenAnswer((
            _,
          ) async {
            readCount += 1;
            if (readCount == 3) {
              return changeSet.copyWith(items: const []);
            }
            return null;
          });
          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: false,
              output: 'Handler failed',
              errorMessage: 'Handler failed',
            ),
          );
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final result = await service.confirmItem(changeSet, 0);

            expect(result.success, isFalse);
            expect(
              result.errorMessage,
              'Failed to update failed confirmation status',
            );
            verify(
              () => mockDomainLogger.error(
                LogDomain.agentWorkflow,
                any(that: contains('Failed to revert item 0')),
                subDomain: any(named: 'subDomain'),
                stackTrace: any(named: 'stackTrace'),
              ),
            ).called(1);
          });
        },
      );

      test(
        'retracts failed running-timer update when the active timer stopped',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: TaskAgentToolNames.updateRunningTimer,
                args: {
                  'timerId': 'timer-entry-001',
                  'summary': 'Refined timer text',
                },
                humanSummary: 'Update running timer text',
              ),
            ],
          );

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: false,
              output: 'Error: no timer is currently running',
              errorMessage: 'No active timer',
            ),
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final result = await service.confirmItem(changeSet, 0);

            expect(result.success, isFalse);
            expect(result.errorMessage, 'No active timer');

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            expect(captured, hasLength(4));

            final confirmedDecision = captured[0] as ChangeDecisionEntity;
            expect(
              confirmedDecision.verdict,
              ChangeDecisionVerdict.confirmed,
            );

            final confirmedSet = captured[1] as ChangeSetEntity;
            expect(
              confirmedSet.items.single.status,
              ChangeItemStatus.confirmed,
            );

            final retractionDecision = captured[2] as ChangeDecisionEntity;
            expect(
              retractionDecision.verdict,
              ChangeDecisionVerdict.retracted,
            );
            expect(retractionDecision.actor, DecisionActor.agent);
            expect(
              retractionDecision.retractionReason,
              contains('No active timer'),
            );

            final retractedSet = captured[3] as ChangeSetEntity;
            expect(
              retractedSet.items.single.status,
              ChangeItemStatus.retracted,
            );
            expect(retractedSet.status, ChangeSetStatus.resolved);
          });
        },
      );

      test(
        'keeps running-timer update retryable for non-stale failures',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: TaskAgentToolNames.updateRunningTimer,
                args: {
                  'timerId': 'timer-entry-001',
                  'summary': 'Refined timer text',
                },
                humanSummary: 'Update running timer text',
              ),
            ],
          );

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: false,
              output: 'Backend temporarily unavailable',
              errorMessage: 'Backend temporarily unavailable',
            ),
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final result = await service.confirmItem(changeSet, 0);

            expect(result.success, isFalse);
            expect(result.errorMessage, 'Backend temporarily unavailable');

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            expect(captured, hasLength(3));
            expect(
              (captured[2] as ChangeSetEntity).items.single.status,
              ChangeItemStatus.pending,
            );
            expect(
              captured.whereType<ChangeDecisionEntity>().map((d) => d.verdict),
              isNot(contains(ChangeDecisionVerdict.retracted)),
            );
          });
        },
      );

      for (final failure in const [
        RunningTimerUpdateFailure.invalidSummary,
        RunningTimerUpdateFailure.invalidTimerId,
        RunningTimerUpdateFailure.noActiveTimer,
        RunningTimerUpdateFailure.sourceTaskMismatch,
        RunningTimerUpdateFailure.timerIdMismatch,
        RunningTimerUpdateFailure.unsupportedEntityType,
      ]) {
        test(
          'auto-retracts running-timer update for stale failure: $failure',
          () async {
            final changeSet = makeChangeSetWith(
              items: const [
                ChangeItem(
                  toolName: TaskAgentToolNames.updateRunningTimer,
                  args: {
                    'timerId': 'timer-entry-001',
                    'summary': 'Refined timer text',
                  },
                  humanSummary: 'Update running timer text',
                ),
              ],
            );

            when(
              () => mockToolDispatcher.dispatch(any(), any(), any()),
            ).thenAnswer(
              (_) async => ToolExecutionResult(
                success: false,
                output: 'Handler rejected stale running timer update',
                errorMessage: failure,
              ),
            );
            when(
              () => mockSyncService.upsertEntity(any()),
            ).thenAnswer((_) async {});

            await withClock(testClock, () async {
              final result = await service.confirmItem(changeSet, 0);

              expect(result.success, isFalse);
              expect(result.errorMessage, failure);

              final captured = verify(
                () => mockSyncService.upsertEntity(captureAny()),
              ).captured;

              expect(captured, hasLength(4));
              expect(
                (captured[0] as ChangeDecisionEntity).verdict,
                ChangeDecisionVerdict.confirmed,
              );
              expect(
                (captured[1] as ChangeSetEntity).items.single.status,
                ChangeItemStatus.confirmed,
              );

              final retractionDecision = captured[2] as ChangeDecisionEntity;
              expect(
                retractionDecision.verdict,
                ChangeDecisionVerdict.retracted,
              );
              expect(retractionDecision.actor, DecisionActor.agent);
              expect(retractionDecision.retractionReason, contains(failure));

              final retractedSet = captured[3] as ChangeSetEntity;
              expect(
                retractedSet.items.single.status,
                ChangeItemStatus.retracted,
              );
              expect(retractedSet.status, ChangeSetStatus.resolved);
            });
          },
        );
      }

      test(
        'returns failure when auto-retract status update cannot be persisted',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: TaskAgentToolNames.updateRunningTimer,
                args: {
                  'timerId': 'timer-1',
                  'summary': 'Private timer summary',
                },
                humanSummary: 'Update running timer text',
              ),
            ],
          );
          var readCount = 0;

          when(() => mockRepository.getEntity(changeSet.id)).thenAnswer((
            _,
          ) async {
            readCount += 1;
            if (readCount == 3) {
              return changeSet.copyWith(items: const []);
            }
            return null;
          });
          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: false,
              output: 'Error: no timer is currently running',
              errorMessage: 'No active timer',
            ),
          );
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final result = await service.confirmItem(changeSet, 0);

            expect(result.success, isFalse);
            expect(
              result.errorMessage,
              'Failed to update failed confirmation status',
            );
            verify(
              () => mockDomainLogger.error(
                LogDomain.agentWorkflow,
                any(that: contains('Failed to mark item 0')),
                subDomain: any(named: 'subDomain'),
                stackTrace: any(named: 'stackTrace'),
              ),
            ).called(1);
          });
        },
      );

      test(
        'retracts failed running-timer update when dispatch throws',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: TaskAgentToolNames.updateRunningTimer,
                args: {
                  'timerId': 'timer-entry-001',
                  'summary': 'Refined timer text',
                },
                humanSummary: 'Update running timer text',
              ),
            ],
          );

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenThrow(StateError('No active timer'));

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final result = await service.confirmItem(changeSet, 0);

            expect(result.success, isFalse);
            expect(result.errorMessage, 'No active timer');
            expect(result.errorMessage, isNot(contains('StateError')));

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            expect(captured, hasLength(4));
            expect(
              (captured[2] as ChangeDecisionEntity).verdict,
              ChangeDecisionVerdict.retracted,
            );
            expect(
              (captured[3] as ChangeSetEntity).items.single.status,
              ChangeItemStatus.retracted,
            );
          });
        },
      );

      // Drives _dispatchFailureMessage / _looksLikeNoActiveTimerError via the
      // dispatch-throws path for running-timer updates. dispatchThrew==true so
      // the item is always auto-retracted, and the retraction reason embeds the
      // sanitised error message produced by _dispatchFailureMessage. We assert
      // on that observable retraction reason / result.errorMessage rather than
      // re-implementing the mapping.
      for (final scenario in const [
        (
          name: 'maps generic thrown error to a runtimeType-only message',
          thrown: 'database connection lost',
          expectedErrorMessage: 'Tool dispatch failed (StateError)',
        ),
        (
          name: 'maps "no timer is currently running" wording to noActiveTimer',
          thrown: 'no timer is currently running right now',
          expectedErrorMessage: RunningTimerUpdateFailure.noActiveTimer,
        ),
      ]) {
        test(
          'dispatch-throws on running-timer update: ${scenario.name}',
          () async {
            final changeSet = makeChangeSetWith(
              items: const [
                ChangeItem(
                  toolName: TaskAgentToolNames.updateRunningTimer,
                  args: {
                    'timerId': 'timer-entry-001',
                    'summary': 'Refined timer text',
                  },
                  humanSummary: 'Update running timer text',
                ),
              ],
            );

            when(
              () => mockToolDispatcher.dispatch(any(), any(), any()),
            ).thenThrow(StateError(scenario.thrown));
            when(
              () => mockSyncService.upsertEntity(any()),
            ).thenAnswer((_) async {});

            await withClock(testClock, () async {
              final result = await service.confirmItem(changeSet, 0);

              expect(result.success, isFalse);
              expect(result.errorMessage, scenario.expectedErrorMessage);
              // The raw thrown text must never leak into the result message.
              expect(result.errorMessage, isNot(contains(scenario.thrown)));

              final captured = verify(
                () => mockSyncService.upsertEntity(captureAny()),
              ).captured;

              expect(captured, hasLength(4));
              final retraction = captured[2] as ChangeDecisionEntity;
              expect(retraction.verdict, ChangeDecisionVerdict.retracted);
              // _failedConfirmationRetractionReason takes the non-empty
              // errorMessage branch and embeds it in the reason.
              expect(
                retraction.retractionReason,
                contains(scenario.expectedErrorMessage),
              );
              expect(
                (captured[3] as ChangeSetEntity).items.single.status,
                ChangeItemStatus.retracted,
              );
            });
          },
        );
      }

      test('invokes post-confirm callback after successful dispatch', () async {
        final changeSet = makeChangeSetWith(
          items: const [
            ChangeItem(
              toolName: 'recommend_next_steps',
              args: {
                'steps': [
                  {'title': 'Verify rollout'},
                ],
              },
              humanSummary: 'Recommend 1 next step',
            ),
          ],
        );
        ChangeDecisionEntity? capturedDecision;
        ChangeItem? capturedItem;

        final serviceWithCallback = ChangeSetConfirmationService(
          syncService: mockSyncService,
          toolDispatcher: mockToolDispatcher.dispatch,
          labelsRepository: mockLabelsRepository,
          domainLogger: mockDomainLogger,
          onConfirmedDecision:
              ({
                required changeSet,
                required item,
                required decision,
              }) async {
                capturedItem = item;
                capturedDecision = decision;
              },
        );

        when(
          () => mockToolDispatcher.dispatch(any(), any(), any()),
        ).thenAnswer(
          (_) async => const ToolExecutionResult(
            success: true,
            output: 'Accepted 1 recommended next step(s)',
          ),
        );
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        await withClock(testClock, () async {
          final result = await serviceWithCallback.confirmItem(changeSet, 0);

          expect(result.success, isTrue);
          expect(capturedItem?.toolName, 'recommend_next_steps');
          expect(capturedDecision, isNotNull);
          expect(capturedDecision?.toolName, 'recommend_next_steps');
          expect(capturedDecision?.verdict, ChangeDecisionVerdict.confirmed);
          expect(capturedDecision?.taskId, changeSet.taskId);
        });
      });

      test(
        'notifies post-resolution callback with the confirmed change set',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: 'update_task_estimate',
                args: {'minutes': 45},
                humanSummary: 'Set estimate to 45 minutes',
              ),
            ],
          );
          final resolvedSets = <ChangeSetEntity>[];
          final serviceWithCallback = ChangeSetConfirmationService(
            syncService: mockSyncService,
            toolDispatcher: mockToolDispatcher.dispatch,
            labelsRepository: mockLabelsRepository,
            domainLogger: mockDomainLogger,
            onChangeSetResolved: (changeSet) async {
              resolvedSets.add(changeSet);
            },
          );

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Estimate set to 45 minutes',
            ),
          );
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await serviceWithCallback.confirmItem(changeSet, 0);

          expect(resolvedSets, hasLength(1));
          expect(
            resolvedSets.single.items.single.status,
            ChangeItemStatus.confirmed,
          );
          expect(resolvedSets.single.status, ChangeSetStatus.resolved);
        },
      );

      test(
        'keeps successful confirmation when post-resolution callback fails',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: 'update_task_estimate',
                args: {'minutes': 45},
                humanSummary: 'Set estimate to 45 minutes',
              ),
            ],
          );
          final serviceWithCallback = ChangeSetConfirmationService(
            syncService: mockSyncService,
            toolDispatcher: mockToolDispatcher.dispatch,
            labelsRepository: mockLabelsRepository,
            domainLogger: mockDomainLogger,
            onChangeSetResolved: (_) async {
              throw StateError('notification-sync-boom');
            },
          );

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Estimate set to 45 minutes',
            ),
          );
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final result = await serviceWithCallback.confirmItem(changeSet, 0);

          expect(result.success, isTrue);
          verify(
            () => mockDomainLogger.error(
              LogDomain.agentWorkflow,
              any(),
              message: any(
                named: 'message',
                that: contains('Post-resolution notification sync failed'),
              ),
              subDomain: any(named: 'subDomain'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).called(1);
        },
      );

      test(
        'reverts item to pending when post-confirm callback fails',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: 'recommend_next_steps',
                args: {
                  'steps': [
                    {'title': 'Verify rollout'},
                  ],
                },
                humanSummary: 'Recommend 1 next step',
              ),
            ],
          );

          final serviceWithCallback = ChangeSetConfirmationService(
            syncService: mockSyncService,
            toolDispatcher: mockToolDispatcher.dispatch,
            labelsRepository: mockLabelsRepository,
            domainLogger: mockDomainLogger,
            onConfirmedDecision:
                ({
                  required changeSet,
                  required item,
                  required decision,
                }) async {
                  throw StateError('failed to persist recommendation');
                },
          );

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Accepted 1 recommended next step(s)',
            ),
          );
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final result = await serviceWithCallback.confirmItem(changeSet, 0);

            expect(result.success, isFalse);
            expect(
              result.errorMessage,
              contains('Post-confirmation handling failed'),
            );
            expect(
              result.errorMessage,
              isNot(contains('failed to persist recommendation')),
            );

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            expect(captured, hasLength(3));
            expect(captured[0], isA<ChangeDecisionEntity>());
            expect(
              (captured[1] as ChangeSetEntity).items.first.status,
              ChangeItemStatus.confirmed,
            );
            expect(
              (captured[2] as ChangeSetEntity).items.first.status,
              ChangeItemStatus.pending,
            );
          });
        },
      );

      test(
        'dispatches create_time_entry args unchanged',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: 'create_time_entry',
                args: {
                  'startTime': '2026-03-17T14:00:00',
                  'endTime': '2026-03-17T15:00:00',
                  'summary': 'Worked on API integration',
                },
                humanSummary:
                    'Time entry 14:00–15:00: "Worked on API integration"',
              ),
            ],
          );

          when(
            () => mockToolDispatcher.dispatch(any(), any(), any()),
          ).thenAnswer(
            (_) async => const ToolExecutionResult(
              success: true,
              output: 'Created time entry',
            ),
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            await service.confirmItem(changeSet, 0);

            verify(
              () => mockToolDispatcher.dispatch(
                'create_time_entry',
                {
                  'startTime': '2026-03-17T14:00:00',
                  'endTime': '2026-03-17T15:00:00',
                  'summary': 'Worked on API integration',
                },
                'task-001',
              ),
            ).called(1);
          });
        },
      );

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

      test(
        'aborts dispatch when concurrent shape change removes confirmed item',
        () async {
          final changeSet = makeChangeSetWith();
          final changedSet = changeSet.copyWith(items: [changeSet.items.first]);
          var reads = 0;

          when(() => mockRepository.getEntity(changeSet.id)).thenAnswer((
            _,
          ) async {
            reads += 1;
            return reads == 1 ? changeSet : changedSet;
          });
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final result = await service.confirmItem(changeSet, 1);

            expect(result.success, isFalse);
            expect(
              result.errorMessage,
              'Concurrent change set update detected',
            );
            verifyNever(
              () => mockToolDispatcher.dispatch(any(), any(), any()),
            );
            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;
            expect(captured.single, isA<ChangeDecisionEntity>());
          });
        },
      );

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

      test(
        'notifies post-resolution callback with the rejected change set',
        () async {
          final changeSet = makeChangeSetWith(
            items: const [
              ChangeItem(
                toolName: 'set_task_title',
                args: {'title': 'Skip'},
                humanSummary: 'Set title to "Skip"',
              ),
            ],
          );
          final resolvedSets = <ChangeSetEntity>[];
          final serviceWithCallback = ChangeSetConfirmationService(
            syncService: mockSyncService,
            toolDispatcher: mockToolDispatcher.dispatch,
            labelsRepository: mockLabelsRepository,
            domainLogger: mockDomainLogger,
            onChangeSetResolved: (changeSet) async {
              resolvedSets.add(changeSet);
            },
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          final applied = await serviceWithCallback.rejectItem(
            changeSet,
            0,
            reason: 'Not useful',
          );

          expect(applied, isTrue);
          expect(resolvedSets, hasLength(1));
          expect(
            resolvedSets.single.items.single.status,
            ChangeItemStatus.rejected,
          );
          expect(resolvedSets.single.status, ChangeSetStatus.resolved);
        },
      );
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
            toolDispatcher: mockToolDispatcher.dispatch,
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

      test(
        'returns false when concurrent shape change removes rejected item',
        () async {
          final changeSet = makeChangeSetWith();
          final changedSet = changeSet.copyWith(items: [changeSet.items.first]);
          var reads = 0;

          when(() => mockRepository.getEntity(changeSet.id)).thenAnswer((
            _,
          ) async {
            reads += 1;
            return reads == 1 ? changeSet : changedSet;
          });
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          await withClock(testClock, () async {
            final applied = await service.rejectItem(changeSet, 1);

            expect(applied, isFalse);
            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;
            expect(captured.single, isA<ChangeDecisionEntity>());
          });
        },
      );
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

    group('rejectItem - cascade rejection of migration items', () {
      test(
        'rejecting create_follow_up_task cascade-rejects sibling migrations',
        () async {
          const placeholderId = 'placeholder-cascade-001';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Split Task',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create follow-up task: "Split Task"',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-1',
                  'title': 'Buy milk',
                  'targetTaskId': placeholderId,
                },
                humanSummary: 'Migrate to follow-up: "Buy milk"',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-2',
                  'title': 'Walk dog',
                  'targetTaskId': placeholderId,
                },
                humanSummary: 'Migrate to follow-up: "Walk dog"',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          // _freshChangeSet and _cascadeRejectMigrationItems both call
          // getEntity — return the change set (then progressively updated
          // versions as items are rejected).
          when(
            () => mockRepository.getEntity(changeSet.id),
          ).thenAnswer((_) async => changeSet);

          await withClock(testClock, () async {
            final applied = await service.rejectItem(changeSet, 0);

            expect(applied, isTrue);

            // The create item + 2 migration siblings = 3 decisions + 3 status
            // updates = 6 upserts total.
            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            // Count rejected decisions.
            final decisions = captured.whereType<ChangeDecisionEntity>();
            expect(
              decisions.length,
              3,
              reason: 'One decision per rejected item (create + 2 migrations)',
            );
            for (final d in decisions) {
              expect(d.verdict, ChangeDecisionVerdict.rejected);
            }
          });
        },
      );

      test(
        'rejecting create_follow_up_task does not reject unrelated items',
        () async {
          const placeholderId = 'placeholder-cascade-002';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Split Task',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create follow-up task: "Split Task"',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-1',
                  'title': 'Buy milk',
                  'targetTaskId': 'other-placeholder',
                },
                humanSummary: 'Migrate to different task',
              ),
              ChangeItem(
                toolName: 'update_task_estimate',
                args: {'minutes': 60},
                humanSummary: 'Set estimate',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          when(
            () => mockRepository.getEntity(changeSet.id),
          ).thenAnswer((_) async => changeSet);

          await withClock(testClock, () async {
            await service.rejectItem(changeSet, 0);

            final captured = verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured;

            // Only 1 decision (the create item) — no cascade because
            // the migration targets a different placeholder.
            final decisions = captured.whereType<ChangeDecisionEntity>();
            expect(decisions.length, 1);

            // The change set update should only reject item 0.
            final changeSets = captured.whereType<ChangeSetEntity>();
            final lastCS = changeSets.last;
            expect(lastCS.items[0].status, ChangeItemStatus.rejected);
            expect(lastCS.items[1].status, ChangeItemStatus.pending);
            expect(lastCS.items[2].status, ChangeItemStatus.pending);
          });
        },
      );

      glados.Glados(
        glados.any.cascadeScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test(
        'matches generated cascade rejection semantics',
        (scenario) async {
          final localSyncService = MockAgentSyncService();
          final localRepository = MockAgentRepository();
          final localToolDispatcher = MockTaskToolDispatcher();
          final localLabelsRepository = MockLabelsRepository();
          final localService = ChangeSetConfirmationService(
            syncService: localSyncService,
            toolDispatcher: localToolDispatcher.dispatch,
            labelsRepository: localLabelsRepository,
          );
          final upserts = <AgentDomainEntity>[];
          var persisted = makeTestChangeSet(items: scenario.items);

          when(() => localSyncService.repository).thenReturn(localRepository);
          when(
            () => localRepository.getEntity(persisted.id),
          ).thenAnswer((_) async => persisted);
          when(
            () => localSyncService.upsertEntity(any()),
          ).thenAnswer((invocation) async {
            final entity =
                invocation.positionalArguments.first as AgentDomainEntity;
            upserts.add(entity);
            if (entity is ChangeSetEntity) {
              persisted = entity;
            }
          });

          await withClock(testClock, () async {
            final applied = await localService.rejectItem(
              persisted,
              0,
              reason: 'generated rejection',
            );

            expect(applied, scenario.shouldApply, reason: '$scenario');
            expect(
              persisted.items.map((item) => item.status),
              scenario.expectedStatuses,
              reason: '$scenario',
            );

            final decisions = upserts.whereType<ChangeDecisionEntity>();
            expect(
              decisions.length,
              scenario.expectedDecisionCount,
              reason: '$scenario',
            );
            for (final decision in decisions) {
              expect(decision.verdict, ChangeDecisionVerdict.rejected);
              expect(decision.rejectionReason, 'generated rejection');
            }

            if (scenario.shouldApply) {
              expect(
                persisted.status,
                scenario.expectedSetStatus,
                reason: '$scenario',
              );
              expect(
                persisted.resolvedAt,
                scenario.expectedSetStatus == ChangeSetStatus.resolved
                    ? testClock.now()
                    : null,
                reason: '$scenario',
              );
            } else {
              expect(upserts, isEmpty, reason: '$scenario');
            }

            verifyNever(
              () => localToolDispatcher.dispatch(any(), any(), any()),
            );
            verifyNever(
              () => localLabelsRepository.suppressLabelOnTask(
                taskId: any(named: 'taskId'),
                labelId: any(named: 'labelId'),
              ),
            );
          });
        },
        tags: 'glados',
      );
    });

    group('domain logging', () {
      test('logs skip message for already-confirmed item', () async {
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
          await service.confirmItem(changeSet, 0);

          verify(
            () => mockDomainLogger.log(
              LogDomain.agentWorkflow,
              any(that: contains('Skipping item 0')),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
        });
      });

      test('logs confirming message without tool argument values', () async {
        const privateSummary =
            'Astro setup is complete via Claude Code with server-side notes';
        const timerId = '550a8331-56f3-11f1-abeb-739703ba5291';
        final changeSet = makeChangeSetWith(
          items: const [
            ChangeItem(
              toolName: TaskAgentToolNames.updateRunningTimer,
              args: {
                'summary': privateSummary,
                'timerId': timerId,
              },
              humanSummary: 'Update running timer text',
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
          await service.confirmItem(changeSet, 0);

          final captured =
              verify(
                    () => mockDomainLogger.log(
                      LogDomain.agentWorkflow,
                      captureAny(that: contains('Confirming item 0')),
                      subDomain: any(named: 'subDomain'),
                    ),
                  ).captured.single
                  as String;

          expect(captured, contains('knownArgs=[summary,timerId]'));
          expect(captured, isNot(contains(privateSummary)));
          expect(captured, isNot(contains(timerId)));
          expect(captured, isNot(contains('dispatchArgs')));
        });
      });

      test('logs error when tool dispatch fails', () async {
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
          await service.confirmItem(changeSet, 0);

          verify(
            () => mockDomainLogger.error(
              LogDomain.agentWorkflow,
              any(that: contains('Tool dispatch failed for item 0')),
              subDomain: any(named: 'subDomain'),
              stackTrace: any(named: 'stackTrace'),
            ),
          ).called(1);
        });
      });

      test('logs skip message for already-rejected item on reject', () async {
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
          await service.rejectItem(changeSet, 0);

          verify(
            () => mockDomainLogger.log(
              LogDomain.agentWorkflow,
              any(that: contains('Skipping reject for item 0')),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
        });
      });

      test('logs rejecting message', () async {
        final changeSet = makeChangeSetWith();

        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        await withClock(testClock, () async {
          await service.rejectItem(changeSet, 0);

          verify(
            () => mockDomainLogger.log(
              LogDomain.agentWorkflow,
              any(that: contains('Rejecting item 0')),
              subDomain: any(named: 'subDomain'),
            ),
          ).called(1);
        });
      });

      test(
        'logs placeholder resolution on successful create_follow_up_task',
        () async {
          const placeholderId = 'placeholder-log-test';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Log Task',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create task',
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
              mutatedEntityId: 'actual-id-log',
            ),
          );

          await withClock(testClock, () async {
            await service.confirmItem(changeSet, 0);

            verify(
              () => mockDomainLogger.log(
                LogDomain.agentWorkflow,
                any(that: contains('Captured placeholder resolution')),
                subDomain: any(named: 'subDomain'),
              ),
            ).called(1);
          });
        },
      );

      test(
        'logs cascade-reject for sibling migration items',
        () async {
          const placeholderId = 'placeholder-cascade-log';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Cascade Log',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create task',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-cascade',
                  'title': 'Migrate me',
                  'targetTaskId': placeholderId,
                },
                humanSummary: 'Migrate item',
              ),
            ],
          );

          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});

          when(
            () => mockRepository.getEntity(changeSet.id),
          ).thenAnswer((_) async => changeSet);

          await withClock(testClock, () async {
            await service.rejectItem(changeSet, 0);

            verify(
              () => mockDomainLogger.log(
                LogDomain.agentWorkflow,
                any(that: contains('Cascade-rejecting migration item')),
                subDomain: any(named: 'subDomain'),
              ),
            ).called(1);
          });
        },
      );

      test(
        'logs persisted resolved targetTaskId to siblings',
        () async {
          const placeholderId = 'placeholder-persist-log';
          final changeSet = makeTestChangeSet(
            items: const [
              ChangeItem(
                toolName: 'create_follow_up_task',
                args: {
                  'title': 'Persist Log',
                  '_placeholderTaskId': placeholderId,
                },
                humanSummary: 'Create task',
              ),
              ChangeItem(
                toolName: 'migrate_checklist_item',
                args: {
                  'id': 'item-persist',
                  'title': 'Persist item',
                  'targetTaskId': placeholderId,
                },
                humanSummary: 'Migrate item',
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
              mutatedEntityId: 'actual-persist-log-id',
            ),
          );

          await withClock(testClock, () async {
            await service.confirmItem(changeSet, 0);

            verify(
              () => mockDomainLogger.log(
                LogDomain.agentWorkflow,
                any(that: contains('Persisted resolved targetTaskId')),
                subDomain: any(named: 'subDomain'),
              ),
            ).called(1);
          });
        },
      );
    });
  });
}
