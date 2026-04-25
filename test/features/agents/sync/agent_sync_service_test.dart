import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockAgentRepository mockRepository;
  late MockOutboxService mockOutboxService;
  late MockVectorClockService mockVectorClockService;
  late AgentSyncService syncService;

  final testDate = DateTime(2024, 3, 15);
  const testClock = VectorClock({'host1': 1});

  final testEntity = AgentDomainEntity.agent(
    id: 'agent-1',
    agentId: 'agent-1',
    kind: 'task_agent',
    displayName: 'Test Agent',
    lifecycle: AgentLifecycle.active,
    mode: AgentInteractionMode.autonomous,
    allowedCategoryIds: const {},
    currentStateId: 'state-1',
    config: const AgentConfig(),
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
  );

  final testStateEntity = AgentDomainEntity.agentState(
    id: 'state-1',
    agentId: 'agent-1',
    revision: 0,
    slots: const AgentSlots(),
    updatedAt: testDate,
    vectorClock: null,
  );

  final testMessageEntity = AgentDomainEntity.agentMessage(
    id: 'msg-1',
    agentId: 'agent-1',
    threadId: 'thread-1',
    kind: AgentMessageKind.thought,
    createdAt: testDate,
    vectorClock: null,
    metadata: const AgentMessageMetadata(),
  );

  final testPayloadEntity = AgentDomainEntity.agentMessagePayload(
    id: 'payload-1',
    agentId: 'agent-1',
    createdAt: testDate,
    vectorClock: null,
    content: const {'text': 'hello'},
  );

  final testReportEntity = AgentDomainEntity.agentReport(
    id: 'report-1',
    agentId: 'agent-1',
    scope: 'current',
    createdAt: testDate,
    vectorClock: null,
  );

  final testReportHeadEntity = AgentDomainEntity.agentReportHead(
    id: 'head-1',
    agentId: 'agent-1',
    scope: 'current',
    reportId: 'report-1',
    updatedAt: testDate,
    vectorClock: null,
  );

  final testBasicLink = AgentLink.basic(
    id: 'link-1',
    fromId: 'agent-1',
    toId: 'state-1',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
  );

  final testAgentStateLink = AgentLink.agentState(
    id: 'link-2',
    fromId: 'agent-1',
    toId: 'state-1',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
  );

  final testMessagePrevLink = AgentLink.messagePrev(
    id: 'link-3',
    fromId: 'msg-2',
    toId: 'msg-1',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
  );

  final testMessagePayloadLink = AgentLink.messagePayload(
    id: 'link-4',
    fromId: 'msg-1',
    toId: 'payload-1',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
  );

  final testToolEffectLink = AgentLink.toolEffect(
    id: 'link-5',
    fromId: 'msg-1',
    toId: 'entry-1',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
  );

  final testAgentTaskLink = AgentLink.agentTask(
    id: 'link-6',
    fromId: 'agent-1',
    toId: 'task-1',
    createdAt: testDate,
    updatedAt: testDate,
    vectorClock: null,
  );

  setUpAll(registerAllFallbackValues);

  setUp(() {
    // Register a fake DomainLogger so _enqueuePostWrite can log swallowed
    // outbox errors without blowing up on an unregistered GetIt lookup.
    if (!getIt.isRegistered<DomainLogger>()) {
      getIt.registerSingleton<DomainLogger>(_FakeDomainLogger());
    }

    mockRepository = MockAgentRepository();
    mockOutboxService = MockOutboxService();
    mockVectorClockService = MockVectorClockService();

    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});
    when(
      () => mockRepository.insertLinkExclusive(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockVectorClockService.getNextVectorClock(
        previous: any(named: 'previous'),
      ),
    ).thenAnswer((_) async => testClock);

    syncService = AgentSyncService(
      repository: mockRepository,
      outboxService: mockOutboxService,
      vectorClockService: mockVectorClockService,
    );
  });

  group('AgentSyncService', () {
    group('upsertEntity', () {
      test('stamps vector clock before persisting and enqueuing', () async {
        await syncService.upsertEntity(testEntity);

        final stampedEntity = testEntity.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertEntity(stampedEntity)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(
              that: isA<SyncAgentEntity>().having(
                (m) => m.agentEntity?.vectorClock,
                'vectorClock',
                testClock,
              ),
            ),
          ),
        ).called(1);
        verify(
          () => mockVectorClockService.getNextVectorClock(),
        ).called(1);
      });

      test('preserves original clock when fromSync is true', () async {
        final syncedEntity = testEntity.copyWith(
          vectorClock: const VectorClock({'remote': 42}),
        );
        await syncService.upsertEntity(syncedEntity, fromSync: true);

        verify(() => mockRepository.upsertEntity(syncedEntity)).called(1);
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
        verifyNever(
          () => mockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        );
      });

      test('works with agentState variant', () async {
        await syncService.upsertEntity(testStateEntity);

        final stamped = testStateEntity.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertEntity(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentMessage variant', () async {
        await syncService.upsertEntity(testMessageEntity);

        final stamped = testMessageEntity.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertEntity(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentMessagePayload variant', () async {
        await syncService.upsertEntity(testPayloadEntity);

        final stamped = testPayloadEntity.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertEntity(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentReport variant', () async {
        await syncService.upsertEntity(testReportEntity);

        final stamped = testReportEntity.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertEntity(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentReportHead variant', () async {
        await syncService.upsertEntity(testReportHeadEntity);

        final stamped = testReportHeadEntity.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertEntity(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('propagates repository error, outbox not called', () async {
        when(
          () => mockRepository.upsertEntity(any()),
        ).thenThrow(Exception('db error'));

        await expectLater(
          () => syncService.upsertEntity(testEntity),
          throwsA(isA<Exception>()),
        );

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test(
        'swallows outbox error after entity is saved — preserves the '
        'commit-on-write invariant so the already-persisted VC counter is '
        'not re-handed to another entity by the next reservation',
        () async {
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenThrow(Exception('outbox error'));

          // Must NOT throw: the DB write already claimed the VC on disk; an
          // outbox-layer failure cannot be allowed to cascade into a VC
          // rewind.
          await syncService.upsertEntity(testEntity);

          final stamped = testEntity.copyWith(vectorClock: testClock);
          verify(() => mockRepository.upsertEntity(stamped)).called(1);
          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
        },
      );
    });

    group('upsertLink', () {
      test('stamps vector clock before persisting and enqueuing', () async {
        await syncService.upsertLink(testBasicLink);

        final stampedLink = testBasicLink.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertLink(stampedLink)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(
              that: isA<SyncAgentLink>().having(
                (m) => m.agentLink?.vectorClock,
                'vectorClock',
                testClock,
              ),
            ),
          ),
        ).called(1);
      });

      test('preserves original clock when fromSync is true', () async {
        final syncedLink = testBasicLink.copyWith(
          vectorClock: const VectorClock({'remote': 42}),
        );
        await syncService.upsertLink(syncedLink, fromSync: true);

        verify(() => mockRepository.upsertLink(syncedLink)).called(1);
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
        verifyNever(
          () => mockVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        );
      });

      test('works with agentState link variant', () async {
        await syncService.upsertLink(testAgentStateLink);

        final stamped = testAgentStateLink.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertLink(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with messagePrev link variant', () async {
        await syncService.upsertLink(testMessagePrevLink);

        final stamped = testMessagePrevLink.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertLink(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with messagePayload link variant', () async {
        await syncService.upsertLink(testMessagePayloadLink);

        final stamped = testMessagePayloadLink.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertLink(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with toolEffect link variant', () async {
        await syncService.upsertLink(testToolEffectLink);

        final stamped = testToolEffectLink.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertLink(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with agentTask link variant', () async {
        await syncService.upsertLink(testAgentTaskLink);

        final stamped = testAgentTaskLink.copyWith(vectorClock: testClock);
        verify(() => mockRepository.upsertLink(stamped)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('propagates repository error, outbox not called', () async {
        when(
          () => mockRepository.upsertLink(any()),
        ).thenThrow(Exception('db error'));

        await expectLater(
          () => syncService.upsertLink(testBasicLink),
          throwsA(isA<Exception>()),
        );

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test(
        'swallows outbox error after link is saved — see upsertEntity '
        'twin for the commit-on-write rationale',
        () async {
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenThrow(Exception('outbox error'));

          await syncService.upsertLink(testBasicLink);

          final stamped = testBasicLink.copyWith(vectorClock: testClock);
          verify(() => mockRepository.upsertLink(stamped)).called(1);
          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
        },
      );
    });

    group('repository', () {
      test('exposes underlying repository for reads', () {
        expect(syncService.repository, same(mockRepository));
      });
    });

    group('runInWakeCycle', () {
      test(
        'buffers agent messages and flushes one bundle on completion',
        () async {
          await syncService.runInWakeCycle(
            agentId: 'agent-1',
            wakeRunKey: 'run-1',
            action: () async {
              await syncService.upsertEntity(testEntity);
              await syncService.upsertLink(testBasicLink);

              verifyNever(() => mockOutboxService.enqueueMessage(any()));
            },
          );

          final captured = verify(
            () => mockOutboxService.enqueueMessage(captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final bundle = captured.single as SyncAgentBundle;
          expect(bundle.agentId, 'agent-1');
          expect(bundle.wakeRunKey, 'run-1');
          expect(bundle.entities, hasLength(1));
          expect(bundle.links, hasLength(1));
        },
      );

      test('transaction messages join the active wake bundle', () async {
        await syncService.runInWakeCycle(
          agentId: 'agent-1',
          wakeRunKey: 'run-1',
          action: () async {
            await syncService.runInTransaction(() async {
              await syncService.upsertEntity(testEntity);
              await syncService.upsertLink(testBasicLink);
            });

            verifyNever(() => mockOutboxService.enqueueMessage(any()));
          },
        );

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        final bundle = captured.single as SyncAgentBundle;
        expect(bundle.entities.single.agentEntity, isNotNull);
        expect(bundle.links.single.agentLink, isNotNull);
      });

      test('flushes buffered messages when the wake fails', () async {
        await expectLater(
          () => syncService.runInWakeCycle<void>(
            agentId: 'agent-1',
            wakeRunKey: 'run-failed',
            action: () async {
              await syncService.upsertEntity(testEntity);
              throw StateError('wake failed');
            },
          ),
          throwsA(isA<StateError>()),
        );

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        final bundle = captured.single as SyncAgentBundle;
        expect(bundle.wakeRunKey, 'run-failed');
        expect(bundle.entities, hasLength(1));
        expect(bundle.links, isEmpty);
      });

      test('reentrant call reuses the active interceptor', () async {
        await syncService.runInWakeCycle(
          agentId: 'agent-outer',
          wakeRunKey: 'run-outer',
          action: () async {
            await syncService.upsertEntity(testEntity);
            // Nested runInWakeCycle must NOT install a second interceptor
            // — its action runs against the outer buffer and emits no
            // separate bundle.
            await syncService.runInWakeCycle(
              agentId: 'agent-inner',
              wakeRunKey: 'run-inner',
              action: () async {
                await syncService.upsertLink(testBasicLink);
              },
            );
          },
        );

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        // Only the OUTER bundle is flushed (one enqueue), and it contains
        // the inner cycle's link too.
        expect(captured, hasLength(1));
        final bundle = captured.single as SyncAgentBundle;
        expect(bundle.agentId, 'agent-outer');
        expect(bundle.wakeRunKey, 'run-outer');
        expect(bundle.entities, hasLength(1));
        expect(bundle.links, hasLength(1));
      });

      test(
        'success-path bundle flush failure is swallowed and logged',
        () async {
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenThrow(StateError('outbox down'));

          // Wake action returns normally — flush failure must NOT propagate.
          final result = await syncService.runInWakeCycle<String>(
            agentId: 'agent-1',
            wakeRunKey: 'run-flush-fail',
            action: () async {
              await syncService.upsertEntity(testEntity);
              return 'ok';
            },
          );

          expect(result, 'ok');
          // Flush was attempted exactly once with a bundle.
          verify(
            () => mockOutboxService.enqueueMessage(
              any(that: isA<SyncAgentBundle>()),
            ),
          ).called(1);
        },
      );

      test(
        'failure-path bundle flush failure is swallowed; original error wins',
        () async {
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenThrow(StateError('outbox down'));

          // Action throws AND flush throws. Caller sees the action error,
          // not the flush error.
          await expectLater(
            () => syncService.runInWakeCycle<void>(
              agentId: 'agent-1',
              wakeRunKey: 'run-double-fail',
              action: () async {
                await syncService.upsertEntity(testEntity);
                throw const FormatException('original wake error');
              },
            ),
            throwsA(isA<FormatException>()),
          );

          verify(
            () => mockOutboxService.enqueueMessage(
              any(that: isA<SyncAgentBundle>()),
            ),
          ).called(1);
        },
      );

      test('flushes nothing when no agent messages were buffered', () async {
        await syncService.runInWakeCycle(
          agentId: 'agent-1',
          wakeRunKey: 'run-empty',
          action: () async {
            // Wake produced no agent writes — buffer stays empty so no
            // bundle is enqueued.
          },
        );

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });
    });

    group('insertLinkExclusive', () {
      test('stamps clock and enqueues outside of wake/transaction', () async {
        await syncService.insertLinkExclusive(testBasicLink);

        final stampedLink = testBasicLink.copyWith(vectorClock: testClock);
        verify(() => mockRepository.insertLinkExclusive(stampedLink)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(
              that: isA<SyncAgentLink>().having(
                (m) => m.agentLink?.vectorClock,
                'vectorClock',
                testClock,
              ),
            ),
          ),
        ).called(1);
      });

      test('preserves original clock when fromSync is true', () async {
        final synced = testBasicLink.copyWith(
          vectorClock: const VectorClock({'remote': 9}),
        );
        await syncService.insertLinkExclusive(synced, fromSync: true);

        verify(() => mockRepository.insertLinkExclusive(synced)).called(1);
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('buffers into wake bundle when called inside wake cycle', () async {
        await syncService.runInWakeCycle(
          agentId: 'agent-1',
          wakeRunKey: 'run-1',
          action: () async {
            await syncService.insertLinkExclusive(testBasicLink);
          },
        );

        final captured = verify(
          () => mockOutboxService.enqueueMessage(captureAny()),
        ).captured;
        final bundle = captured.single as SyncAgentBundle;
        expect(bundle.links, hasLength(1));
        expect(
          bundle.links.single.agentLink?.vectorClock,
          testClock,
        );
      });

      test('defers enqueue until transaction commit', () async {
        await syncService.runInTransaction(() async {
          await syncService.insertLinkExclusive(testBasicLink);
          verifyNever(() => mockOutboxService.enqueueMessage(any()));
        });

        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });
    });

    group('runInTransaction', () {
      test('delegates to repository', () async {
        var called = false;
        await syncService.runInTransaction(() async {
          called = true;
        });
        expect(called, isTrue);
      });

      test('buffers outbox messages during transaction', () async {
        await syncService.runInTransaction(() async {
          await syncService.upsertEntity(testEntity);
          await syncService.upsertLink(testBasicLink);

          // Outbox must NOT have been called yet — messages are buffered.
          verifyNever(() => mockOutboxService.enqueueMessage(any()));
        });

        // After commit, both messages are flushed to outbox.
        verify(() => mockOutboxService.enqueueMessage(any())).called(2);
      });

      test('discards buffered messages on rollback', () async {
        await expectLater(
          () => syncService.runInTransaction(() async {
            await syncService.upsertEntity(testEntity);
            await syncService.upsertLink(testBasicLink);
            throw Exception('simulated rollback');
          }),
          throwsA(isA<Exception>()),
        );

        // Outbox must never be called — messages are discarded.
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('non-TX upserts enqueue immediately', () async {
        await syncService.upsertEntity(testEntity);

        verify(() => mockOutboxService.enqueueMessage(any())).called(1);
      });

      test('mixed entity and link writes in a single transaction', () async {
        await syncService.runInTransaction(() async {
          await syncService.upsertEntity(testEntity);
          await syncService.upsertEntity(testStateEntity);
          await syncService.upsertLink(testBasicLink);
        });

        // All three messages flushed after commit.
        verify(() => mockOutboxService.enqueueMessage(any())).called(3);
      });

      test('fromSync writes inside TX are not buffered or flushed', () async {
        await syncService.runInTransaction(() async {
          await syncService.upsertEntity(testEntity, fromSync: true);
          await syncService.upsertLink(testBasicLink, fromSync: true);
        });

        // fromSync skips outbox entirely, even inside a transaction.
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('nested TX buffers all messages until outermost commit', () async {
        await syncService.runInTransaction(() async {
          await syncService.upsertEntity(testEntity);

          // Inner transaction
          await syncService.runInTransaction(() async {
            await syncService.upsertLink(testBasicLink);
            await syncService.upsertEntity(testStateEntity);

            // Nothing flushed yet — still inside outermost TX.
            verifyNever(() => mockOutboxService.enqueueMessage(any()));
          });

          // Inner TX returned, but outermost is still open.
          verifyNever(() => mockOutboxService.enqueueMessage(any()));
        });

        // After outermost commit, all three messages are flushed.
        verify(() => mockOutboxService.enqueueMessage(any())).called(3);
      });

      test('nested TX rollback discards all messages', () async {
        await expectLater(
          () => syncService.runInTransaction(() async {
            await syncService.upsertEntity(testEntity);

            await syncService.runInTransaction(() async {
              await syncService.upsertLink(testBasicLink);
            });

            // Outer TX throws after inner committed.
            throw Exception('outer rollback');
          }),
          throwsA(isA<Exception>()),
        );

        // Outbox must never be called — all messages discarded.
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('inner TX rollback propagates, outer messages discarded', () async {
        await expectLater(
          () => syncService.runInTransaction(() async {
            await syncService.upsertEntity(testEntity);

            await syncService.runInTransaction(() async {
              await syncService.upsertLink(testBasicLink);
              throw Exception('inner rollback');
            });
          }),
          throwsA(isA<Exception>()),
        );

        // Inner exception propagates to outer; outbox never called.
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test(
        'inner TX rollback caught by outer — only outer messages flushed',
        () async {
          await syncService.runInTransaction(() async {
            // Outer write — should be flushed.
            await syncService.upsertEntity(testEntity);

            // Inner TX rolls back, but outer catches and continues.
            try {
              await syncService.runInTransaction(() async {
                await syncService.upsertLink(testBasicLink);
                throw Exception('inner rollback');
              });
            } on Exception {
              // Intentionally caught — outer TX continues.
            }

            // Another outer write after the caught inner failure.
            await syncService.upsertEntity(testStateEntity);
          });

          // Only the two outer entity messages should be flushed.
          // The inner link message must have been discarded on savepoint rollback.
          verify(
            () => mockOutboxService.enqueueMessage(
              any(that: isA<SyncAgentEntity>()),
            ),
          ).called(2);
          verifyNever(
            () => mockOutboxService.enqueueMessage(
              any(that: isA<SyncAgentLink>()),
            ),
          );
        },
      );

      test('concurrent chains are isolated — rollback in one does not '
          'affect the other', () async {
        // Chain A: will fail; its messages must be discarded.
        // Chain B: will succeed; its messages must be flushed.
        final chainA = syncService
            .runInTransaction<void>(() async {
              await syncService.upsertEntity(testEntity);
              throw Exception('chain A rollback');
            })
            .then<void>((_) {})
            .catchError((_) {});

        final chainB = syncService.runInTransaction(() async {
          await syncService.upsertLink(testBasicLink);
        });

        await Future.wait([chainA, chainB]);

        // Only chain B's single message (the link) should have been flushed.
        // Chain A's entity message must have been discarded on rollback.
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
        verifyNever(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        );
      });

      test(
        'partial enqueue failure still attempts all messages',
        () async {
          var callCount = 0;
          when(() => mockOutboxService.enqueueMessage(any())).thenAnswer((
            _,
          ) async {
            callCount++;
            if (callCount == 1) {
              throw Exception('outbox write failed');
            }
          });

          await expectLater(
            syncService.runInTransaction(() async {
              await syncService.upsertEntity(testEntity);
              await syncService.upsertLink(testBasicLink);
            }),
            throwsA(isA<Exception>()),
          );

          // Both messages should have been attempted despite the first
          // one failing.
          verify(() => mockOutboxService.enqueueMessage(any())).called(2);
        },
      );
    });
  });
}

/// Minimal DomainLogger double — no-op for both the gated info channel and
/// the always-on error channel. The tests don't assert on logs; they just
/// need the singleton lookup in AgentSyncService._enqueuePostWrite to
/// succeed so the swallow-outbox-error path completes.
class _FakeDomainLogger implements DomainLogger {
  @override
  final Set<String> enabledDomains = {};

  @override
  void log(
    String domain,
    String message, {
    String? subDomain,
    dynamic level,
  }) {}

  @override
  void error(
    String domain,
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? subDomain,
  }) {}
}
