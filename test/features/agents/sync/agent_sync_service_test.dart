import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
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

enum _GeneratedSyncWriteKind {
  entity,
  link,
  exclusiveLink,
  entityFromSync,
  linkFromSync,
  exclusiveLinkFromSync,
}

enum _GeneratedSyncOperationKind {
  write,
  innerSuccess,
  innerCaughtRollback,
  innerUncaughtRollback,
  abortOuter,
}

enum _GeneratedSyncOutboxFailureSlot { none, first, second, last }

enum _GeneratedSyncMessageKind { entity, link }

enum _GeneratedPersistedWriteKind { entity, link, exclusiveLink }

class _GeneratedSyncRollbackException implements Exception {
  const _GeneratedSyncRollbackException();
}

class _ExpectedPersistedWrite {
  const _ExpectedPersistedWrite({
    required this.kind,
    required this.fromSync,
  });

  final _GeneratedPersistedWriteKind kind;
  final bool fromSync;
}

class _ObservedPersistedWrite {
  const _ObservedPersistedWrite({
    required this.kind,
    required this.hasVectorClock,
  });

  final _GeneratedPersistedWriteKind kind;
  final bool hasVectorClock;
}

class _GeneratedTransactionSnapshot {
  const _GeneratedTransactionSnapshot({
    required this.expectedPersistedWriteCount,
    required this.observedPersistedWriteCount,
    required this.expectedOutboxKindCount,
  });

  final int expectedPersistedWriteCount;
  final int observedPersistedWriteCount;
  final int expectedOutboxKindCount;
}

class _GeneratedTransactionAwareAgentRepository extends MockAgentRepository {
  _GeneratedTransactionAwareAgentRepository({
    required this.snapshot,
    required this.rollbackTo,
  });

  final _GeneratedTransactionSnapshot Function() snapshot;
  final void Function(_GeneratedTransactionSnapshot snapshot) rollbackTo;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    final marker = snapshot();
    try {
      return await action();
    } catch (_) {
      rollbackTo(marker);
      rethrow;
    }
  }
}

class _GeneratedSyncTransactionOperation {
  const _GeneratedSyncTransactionOperation({
    required this.kind,
    required this.firstWrite,
    required this.secondWrite,
  });

  final _GeneratedSyncOperationKind kind;
  final _GeneratedSyncWriteKind firstWrite;
  final _GeneratedSyncWriteKind secondWrite;

  @override
  String toString() {
    return '_GeneratedSyncTransactionOperation('
        'kind: $kind, firstWrite: $firstWrite, secondWrite: $secondWrite)';
  }
}

class _GeneratedSyncTransactionScenario {
  const _GeneratedSyncTransactionScenario({
    required this.operations,
    required this.outboxFailureSlot,
  });

  final List<_GeneratedSyncTransactionOperation> operations;
  final _GeneratedSyncOutboxFailureSlot outboxFailureSlot;

  int? failureAttemptFor(int flushCount) {
    if (flushCount == 0) return null;
    return switch (outboxFailureSlot) {
      _GeneratedSyncOutboxFailureSlot.none => null,
      _GeneratedSyncOutboxFailureSlot.first => 1,
      _GeneratedSyncOutboxFailureSlot.second => flushCount >= 2 ? 2 : null,
      _GeneratedSyncOutboxFailureSlot.last => flushCount,
    };
  }

  @override
  String toString() {
    return '_GeneratedSyncTransactionScenario('
        'operations: $operations, outboxFailureSlot: $outboxFailureSlot)';
  }
}

extension _GeneratedSyncWriteKindX on _GeneratedSyncWriteKind {
  bool get fromSync {
    return switch (this) {
      _GeneratedSyncWriteKind.entity ||
      _GeneratedSyncWriteKind.link ||
      _GeneratedSyncWriteKind.exclusiveLink => false,
      _GeneratedSyncWriteKind.entityFromSync ||
      _GeneratedSyncWriteKind.linkFromSync ||
      _GeneratedSyncWriteKind.exclusiveLinkFromSync => true,
    };
  }

  _GeneratedPersistedWriteKind get persistedKind {
    return switch (this) {
      _GeneratedSyncWriteKind.entity ||
      _GeneratedSyncWriteKind.entityFromSync =>
        _GeneratedPersistedWriteKind.entity,
      _GeneratedSyncWriteKind.link ||
      _GeneratedSyncWriteKind.linkFromSync => _GeneratedPersistedWriteKind.link,
      _GeneratedSyncWriteKind.exclusiveLink ||
      _GeneratedSyncWriteKind.exclusiveLinkFromSync =>
        _GeneratedPersistedWriteKind.exclusiveLink,
    };
  }

  _GeneratedSyncMessageKind? get outboxMessageKind {
    if (fromSync) return null;
    return switch (this) {
      _GeneratedSyncWriteKind.entity => _GeneratedSyncMessageKind.entity,
      _GeneratedSyncWriteKind.link ||
      _GeneratedSyncWriteKind.exclusiveLink => _GeneratedSyncMessageKind.link,
      _GeneratedSyncWriteKind.entityFromSync ||
      _GeneratedSyncWriteKind.linkFromSync ||
      _GeneratedSyncWriteKind.exclusiveLinkFromSync => null,
    };
  }
}

extension _AnyGeneratedAgentSyncServiceScenario on glados.Any {
  glados.Generator<_GeneratedSyncWriteKind> get syncWriteKind =>
      glados.AnyUtils(this).choose(_GeneratedSyncWriteKind.values);

  glados.Generator<_GeneratedSyncOperationKind> get syncOperationKind =>
      glados.AnyUtils(this).choose(_GeneratedSyncOperationKind.values);

  glados.Generator<_GeneratedSyncOutboxFailureSlot> get syncOutboxFailureSlot =>
      glados.AnyUtils(this).choose(_GeneratedSyncOutboxFailureSlot.values);

  glados.Generator<_GeneratedSyncTransactionOperation>
  get syncTransactionOperation => glados.CombinableAny(this).combine3(
    syncOperationKind,
    syncWriteKind,
    syncWriteKind,
    (
      _GeneratedSyncOperationKind kind,
      _GeneratedSyncWriteKind firstWrite,
      _GeneratedSyncWriteKind secondWrite,
    ) => _GeneratedSyncTransactionOperation(
      kind: kind,
      firstWrite: firstWrite,
      secondWrite: secondWrite,
    ),
  );

  glados.Generator<_GeneratedSyncTransactionScenario>
  get syncTransactionScenario => glados.CombinableAny(this).combine2(
    glados.ListAnys(
      this,
    ).listWithLengthInRange(0, 8, syncTransactionOperation),
    syncOutboxFailureSlot,
    (
      List<_GeneratedSyncTransactionOperation> operations,
      _GeneratedSyncOutboxFailureSlot outboxFailureSlot,
    ) => _GeneratedSyncTransactionScenario(
      operations: operations,
      outboxFailureSlot: outboxFailureSlot,
    ),
  );
}

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
      glados.Glados(
        glados.any.syncTransactionScenario,
        glados.ExploreConfig(numRuns: 260),
      ).test('matches generated nested transaction buffer semantics', (
        scenario,
      ) async {
        final expectedPersistedWrites = <_ExpectedPersistedWrite>[];
        final observedPersistedWrites = <_ObservedPersistedWrite>[];
        final expectedOutboxKinds = <_GeneratedSyncMessageKind>[];
        final generatedRepository = _GeneratedTransactionAwareAgentRepository(
          snapshot: () => _GeneratedTransactionSnapshot(
            expectedPersistedWriteCount: expectedPersistedWrites.length,
            observedPersistedWriteCount: observedPersistedWrites.length,
            expectedOutboxKindCount: expectedOutboxKinds.length,
          ),
          rollbackTo: (snapshot) {
            expectedPersistedWrites.removeRange(
              snapshot.expectedPersistedWriteCount,
              expectedPersistedWrites.length,
            );
            observedPersistedWrites.removeRange(
              snapshot.observedPersistedWriteCount,
              observedPersistedWrites.length,
            );
            expectedOutboxKinds.removeRange(
              snapshot.expectedOutboxKindCount,
              expectedOutboxKinds.length,
            );
          },
        );
        final generatedOutboxService = MockOutboxService();
        final generatedVectorClockService = MockVectorClockService();
        final generatedSyncService = AgentSyncService(
          repository: generatedRepository,
          outboxService: generatedOutboxService,
          vectorClockService: generatedVectorClockService,
        );
        final outboxAttempts = <SyncMessage>[];
        var writeIndex = 0;
        var expectedLocalWriteAttempts = 0;
        var reservedVectorClocks = 0;
        var abortedByTransaction = false;

        AgentDomainEntity entityFor(int index) {
          return AgentDomainEntity.agentState(
            id: 'generated-state-$index',
            agentId: 'generated-agent-$index',
            revision: index,
            slots: const AgentSlots(),
            updatedAt: testDate,
            vectorClock: null,
          );
        }

        AgentLink linkFor(int index) {
          return AgentLink.basic(
            id: 'generated-link-$index',
            fromId: 'generated-agent-$index',
            toId: 'generated-state-$index',
            createdAt: testDate,
            updatedAt: testDate,
            vectorClock: null,
          );
        }

        _GeneratedSyncMessageKind messageKind(SyncMessage message) {
          if (message is SyncAgentEntity) {
            return _GeneratedSyncMessageKind.entity;
          }
          if (message is SyncAgentLink) {
            return _GeneratedSyncMessageKind.link;
          }
          throw StateError('Unexpected sync message type: $message');
        }

        when(
          () => generatedRepository.upsertEntity(any()),
        ).thenAnswer((invocation) async {
          final entity =
              invocation.positionalArguments.single as AgentDomainEntity;
          observedPersistedWrites.add(
            _ObservedPersistedWrite(
              kind: _GeneratedPersistedWriteKind.entity,
              hasVectorClock: entity.vectorClock != null,
            ),
          );
        });
        when(
          () => generatedRepository.upsertLink(any()),
        ).thenAnswer((invocation) async {
          final link = invocation.positionalArguments.single as AgentLink;
          observedPersistedWrites.add(
            _ObservedPersistedWrite(
              kind: _GeneratedPersistedWriteKind.link,
              hasVectorClock: link.vectorClock != null,
            ),
          );
        });
        when(
          () => generatedRepository.insertLinkExclusive(any()),
        ).thenAnswer((invocation) async {
          final link = invocation.positionalArguments.single as AgentLink;
          observedPersistedWrites.add(
            _ObservedPersistedWrite(
              kind: _GeneratedPersistedWriteKind.exclusiveLink,
              hasVectorClock: link.vectorClock != null,
            ),
          );
        });
        when(
          () => generatedOutboxService.enqueueMessage(any()),
        ).thenAnswer((invocation) async {
          final message = invocation.positionalArguments.single as SyncMessage;
          outboxAttempts.add(message);
          final failureAttempt = scenario.failureAttemptFor(
            expectedOutboxKinds.length,
          );
          if (failureAttempt == outboxAttempts.length) {
            throw Exception('generated outbox failure');
          }
        });
        when(
          () => generatedVectorClockService.getNextVectorClock(
            previous: any(named: 'previous'),
          ),
        ).thenAnswer((_) async {
          reservedVectorClocks++;
          return VectorClock({'generated': reservedVectorClocks});
        });

        Future<void> performWrite(_GeneratedSyncWriteKind kind) async {
          final index = writeIndex++;
          expectedPersistedWrites.add(
            _ExpectedPersistedWrite(
              kind: kind.persistedKind,
              fromSync: kind.fromSync,
            ),
          );
          final outboxKind = kind.outboxMessageKind;
          if (outboxKind != null) {
            expectedOutboxKinds.add(outboxKind);
            expectedLocalWriteAttempts++;
          }

          switch (kind) {
            case _GeneratedSyncWriteKind.entity:
              await generatedSyncService.upsertEntity(entityFor(index));
            case _GeneratedSyncWriteKind.link:
              await generatedSyncService.upsertLink(linkFor(index));
            case _GeneratedSyncWriteKind.exclusiveLink:
              await generatedSyncService.insertLinkExclusive(linkFor(index));
            case _GeneratedSyncWriteKind.entityFromSync:
              await generatedSyncService.upsertEntity(
                entityFor(index),
                fromSync: true,
              );
            case _GeneratedSyncWriteKind.linkFromSync:
              await generatedSyncService.upsertLink(
                linkFor(index),
                fromSync: true,
              );
            case _GeneratedSyncWriteKind.exclusiveLinkFromSync:
              await generatedSyncService.insertLinkExclusive(
                linkFor(index),
                fromSync: true,
              );
          }
        }

        Future<void> runOperation(
          _GeneratedSyncTransactionOperation operation,
        ) async {
          switch (operation.kind) {
            case _GeneratedSyncOperationKind.write:
              await performWrite(operation.firstWrite);
            case _GeneratedSyncOperationKind.innerSuccess:
              await generatedSyncService.runInTransaction(() async {
                await performWrite(operation.firstWrite);
                await performWrite(operation.secondWrite);
                expect(outboxAttempts, isEmpty, reason: '$scenario');
              });
            case _GeneratedSyncOperationKind.innerCaughtRollback:
              final snapshot = expectedOutboxKinds.length;
              try {
                await generatedSyncService.runInTransaction(() async {
                  await performWrite(operation.firstWrite);
                  await performWrite(operation.secondWrite);
                  throw const _GeneratedSyncRollbackException();
                });
              } on _GeneratedSyncRollbackException {
                expectedOutboxKinds.removeRange(
                  snapshot,
                  expectedOutboxKinds.length,
                );
              }
            case _GeneratedSyncOperationKind.innerUncaughtRollback:
              abortedByTransaction = true;
              await generatedSyncService.runInTransaction(() async {
                await performWrite(operation.firstWrite);
                await performWrite(operation.secondWrite);
                throw const _GeneratedSyncRollbackException();
              });
            case _GeneratedSyncOperationKind.abortOuter:
              await performWrite(operation.firstWrite);
              abortedByTransaction = true;
              throw const _GeneratedSyncRollbackException();
          }
        }

        Object? error;
        try {
          await generatedSyncService.runInTransaction(() async {
            for (final operation in scenario.operations) {
              await runOperation(operation);
              expect(
                outboxAttempts,
                isEmpty,
                reason: 'Outbox flushed before outer commit: $scenario',
              );
            }
          });
        } on Object catch (caught) {
          error = caught;
        }

        final expectedFlushKinds = abortedByTransaction
            ? const <_GeneratedSyncMessageKind>[]
            : expectedOutboxKinds;
        final expectedFailureAttempt = scenario.failureAttemptFor(
          expectedFlushKinds.length,
        );

        if (abortedByTransaction) {
          expect(error, isA<_GeneratedSyncRollbackException>());
        } else if (expectedFailureAttempt != null) {
          expect(error, isA<Exception>());
        } else {
          expect(error, isNull, reason: '$scenario');
        }

        expect(
          outboxAttempts.map(messageKind).toList(),
          expectedFlushKinds,
          reason: '$scenario',
        );
        expect(
          observedPersistedWrites,
          hasLength(expectedPersistedWrites.length),
          reason: '$scenario',
        );
        for (var i = 0; i < expectedPersistedWrites.length; i++) {
          final expected = expectedPersistedWrites[i];
          final observed = observedPersistedWrites[i];
          expect(observed.kind, expected.kind, reason: '$scenario at $i');
          expect(
            observed.hasVectorClock,
            isNot(expected.fromSync),
            reason: '$scenario at $i',
          );
        }
        expect(
          reservedVectorClocks,
          expectedLocalWriteAttempts,
          reason: '$scenario',
        );
      });

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
