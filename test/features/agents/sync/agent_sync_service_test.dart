import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  late MockAgentRepository mockRepository;
  late MockOutboxService mockOutboxService;
  late AgentSyncService syncService;

  final testDate = DateTime(2024, 3, 15);

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
    mockRepository = MockAgentRepository();
    mockOutboxService = MockOutboxService();

    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});
    when(() => mockOutboxService.enqueueMessage(any()))
        .thenAnswer((_) async {});

    syncService = AgentSyncService(
      repository: mockRepository,
      outboxService: mockOutboxService,
    );
  });

  group('AgentSyncService', () {
    group('upsertEntity', () {
      test('calls repository AND enqueues sync message', () async {
        await syncService.upsertEntity(testEntity);

        verify(() => mockRepository.upsertEntity(testEntity)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(
              that: isA<SyncAgentEntity>().having(
                (m) => m.agentEntity,
                'agentEntity',
                testEntity,
              ),
            ),
          ),
        ).called(1);
      });

      test('calls repository but NOT outbox when fromSync is true', () async {
        await syncService.upsertEntity(testEntity, fromSync: true);

        verify(() => mockRepository.upsertEntity(testEntity)).called(1);
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('works with agentState variant', () async {
        await syncService.upsertEntity(testStateEntity);

        verify(() => mockRepository.upsertEntity(testStateEntity)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentMessage variant', () async {
        await syncService.upsertEntity(testMessageEntity);

        verify(() => mockRepository.upsertEntity(testMessageEntity)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentMessagePayload variant', () async {
        await syncService.upsertEntity(testPayloadEntity);

        verify(() => mockRepository.upsertEntity(testPayloadEntity)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentReport variant', () async {
        await syncService.upsertEntity(testReportEntity);

        verify(() => mockRepository.upsertEntity(testReportEntity)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('works with agentReportHead variant', () async {
        await syncService.upsertEntity(testReportHeadEntity);

        verify(
          () => mockRepository.upsertEntity(testReportHeadEntity),
        ).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentEntity>()),
          ),
        ).called(1);
      });

      test('propagates repository error, outbox not called', () async {
        when(() => mockRepository.upsertEntity(any()))
            .thenThrow(Exception('db error'));

        await expectLater(
          () => syncService.upsertEntity(testEntity),
          throwsA(isA<Exception>()),
        );

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('propagates outbox error after entity is saved', () async {
        when(() => mockOutboxService.enqueueMessage(any()))
            .thenThrow(Exception('outbox error'));

        await expectLater(
          () => syncService.upsertEntity(testEntity),
          throwsA(isA<Exception>()),
        );

        // Entity was saved before the outbox call
        verify(() => mockRepository.upsertEntity(testEntity)).called(1);
      });
    });

    group('upsertLink', () {
      test('calls repository AND enqueues sync message', () async {
        await syncService.upsertLink(testBasicLink);

        verify(() => mockRepository.upsertLink(testBasicLink)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(
              that: isA<SyncAgentLink>().having(
                (m) => m.agentLink,
                'agentLink',
                testBasicLink,
              ),
            ),
          ),
        ).called(1);
      });

      test('calls repository but NOT outbox when fromSync is true', () async {
        await syncService.upsertLink(testBasicLink, fromSync: true);

        verify(() => mockRepository.upsertLink(testBasicLink)).called(1);
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('works with agentState link variant', () async {
        await syncService.upsertLink(testAgentStateLink);

        verify(() => mockRepository.upsertLink(testAgentStateLink)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with messagePrev link variant', () async {
        await syncService.upsertLink(testMessagePrevLink);

        verify(() => mockRepository.upsertLink(testMessagePrevLink)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with messagePayload link variant', () async {
        await syncService.upsertLink(testMessagePayloadLink);

        verify(
          () => mockRepository.upsertLink(testMessagePayloadLink),
        ).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with toolEffect link variant', () async {
        await syncService.upsertLink(testToolEffectLink);

        verify(() => mockRepository.upsertLink(testToolEffectLink)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('works with agentTask link variant', () async {
        await syncService.upsertLink(testAgentTaskLink);

        verify(() => mockRepository.upsertLink(testAgentTaskLink)).called(1);
        verify(
          () => mockOutboxService.enqueueMessage(
            any(that: isA<SyncAgentLink>()),
          ),
        ).called(1);
      });

      test('propagates repository error, outbox not called', () async {
        when(() => mockRepository.upsertLink(any()))
            .thenThrow(Exception('db error'));

        await expectLater(
          () => syncService.upsertLink(testBasicLink),
          throwsA(isA<Exception>()),
        );

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test('propagates outbox error after link is saved', () async {
        when(() => mockOutboxService.enqueueMessage(any()))
            .thenThrow(Exception('outbox error'));

        await expectLater(
          () => syncService.upsertLink(testBasicLink),
          throwsA(isA<Exception>()),
        );

        verify(() => mockRepository.upsertLink(testBasicLink)).called(1);
      });
    });

    group('repository', () {
      test('exposes underlying repository for reads', () {
        expect(syncService.repository, same(mockRepository));
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

      test('inner TX rollback caught by outer — only outer messages flushed',
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
      });

      test(
          'concurrent chains are isolated — rollback in one does not '
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
          when(() => mockOutboxService.enqueueMessage(any()))
              .thenAnswer((_) async {
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
