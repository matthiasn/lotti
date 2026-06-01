import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_data/entity_factories.dart';

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

/// One generated local agent-state write: the persisted row's head and the
/// caller's (possibly stale) head independently present or absent, plus a
/// distinguishing `lastWakeAt` to prove the caller's other fields survive.
class _GeneratedHeadPreservationScenario {
  const _GeneratedHeadPreservationScenario({
    required this.persistedStateExists,
    required this.persistedHead,
    required this.callerHead,
    required this.lastWakeAt,
  });

  final bool persistedStateExists;
  final String? persistedHead;
  final String? callerHead;
  final DateTime lastWakeAt;

  /// The head the write must end with: the persisted (append-owned) head when a
  /// state row exists, otherwise the caller's value (the first-ever write).
  String? get expectedHead => persistedStateExists ? persistedHead : callerHead;

  @override
  String toString() =>
      '_GeneratedHeadPreservationScenario('
      'persistedStateExists: $persistedStateExists, '
      'persistedHead: $persistedHead, callerHead: $callerHead, '
      'lastWakeAt: $lastWakeAt)';
}

/// One generated `appendMilestone` call: any milestone, with the thread id and
/// run key independently present or absent, at any created-at offset.
class _GeneratedMilestoneScenario {
  const _GeneratedMilestoneScenario({
    required this.milestone,
    required this.threadId,
    required this.runKey,
    required this.createdAt,
  });

  final AgentMilestone milestone;
  final String? threadId;
  final String? runKey;
  final DateTime createdAt;

  @override
  String toString() =>
      '_GeneratedMilestoneScenario(milestone: $milestone, '
      'threadId: $threadId, runKey: $runKey, createdAt: $createdAt)';
}

extension _AnyGeneratedAgentSyncServiceScenario on glados.Any {
  glados.Generator<_GeneratedSyncWriteKind> get syncWriteKind =>
      glados.AnyUtils(this).choose(_GeneratedSyncWriteKind.values);

  glados.Generator<_GeneratedHeadPreservationScenario>
  get headPreservationScenario => glados.CombinableAny(this).combine4(
    glados.IntAnys(this).intInRange(0, 2),
    glados.IntAnys(this).intInRange(0, 3),
    glados.IntAnys(this).intInRange(0, 3),
    glados.IntAnys(this).intInRange(0, 28),
    (
      int statePresentSelector,
      int persistedSelector,
      int callerSelector,
      int dayOffset,
    ) => _GeneratedHeadPreservationScenario(
      persistedStateExists: statePresentSelector == 1,
      persistedHead: persistedSelector == 0
          ? null
          : 'persisted-$persistedSelector',
      callerHead: callerSelector == 0 ? null : 'caller-$callerSelector',
      lastWakeAt: DateTime(2024, 3, 15).add(Duration(days: dayOffset)),
    ),
  );

  glados.Generator<_GeneratedMilestoneScenario> get milestoneScenario =>
      glados.CombinableAny(this).combine4(
        glados.AnyUtils(this).choose(AgentMilestone.values),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 3),
        glados.IntAnys(this).intInRange(0, 28),
        (
          AgentMilestone milestone,
          int threadSelector,
          int runSelector,
          int dayOffset,
        ) => _GeneratedMilestoneScenario(
          milestone: milestone,
          threadId: threadSelector == 0 ? null : 'thread-$threadSelector',
          runKey: runSelector == 0 ? null : 'run-$runSelector',
          createdAt: DateTime(2024, 3, 15).add(Duration(days: dayOffset)),
        ),
      );

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
      getIt.registerSingleton<DomainLogger>(MockDomainLogger());
    }

    mockRepository = MockAgentRepository();
    mockOutboxService = MockOutboxService();
    mockVectorClockService = MockVectorClockService();

    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});
    // Local message upserts route through the causal-DAG append path, which
    // reads the agent's head and (when unset) backfills the prefix; default to
    // no head and no prior messages unless a test overrides.
    when(
      () => mockRepository.getAgentState(any()),
    ).thenAnswer((_) async => null);
    when(
      () => mockRepository.getAgentMessages(any()),
    ).thenAnswer((_) async => <AgentMessageEntity>[]);
    when(
      () => mockRepository.getMessagesByKind(any(), any()),
    ).thenAnswer((_) async => <AgentMessageEntity>[]);
    when(
      () => mockRepository.getLinksFrom(any()),
    ).thenAnswer((_) async => <AgentLink>[]);
    // The append path's idempotency guard looks the message up first; default
    // to "not yet persisted" so a plain append proceeds to chaining.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
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

      test('records the agent entity sequence before enqueuing', () async {
        final sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});
        final service = AgentSyncService(
          repository: mockRepository,
          outboxService: mockOutboxService,
          vectorClockService: mockVectorClockService,
          sequenceLogService: sequenceLog,
        );

        await service.upsertEntity(testEntity);

        verifyInOrder([
          () => sequenceLog.recordSentEntry(
            entryId: testEntity.id,
            vectorClock: testClock,
            payloadType: SyncSequencePayloadType.agentEntity,
          ),
          () => mockOutboxService.enqueueMessage(any<SyncMessage>()),
        ]);
      });

      test(
        'falls back to getIt-registered SyncSequenceLogService when '
        'constructor arg is null',
        () async {
          final sequenceLog = MockSyncSequenceLogService();
          when(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              payloadType: any(named: 'payloadType'),
            ),
          ).thenAnswer((_) async {});
          getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
          addTearDown(() => getIt.unregister<SyncSequenceLogService>());

          // syncService was constructed without sequenceLogService; should
          // resolve via getIt on first use.
          await syncService.upsertEntity(testEntity);

          verify(
            () => sequenceLog.recordSentEntry(
              entryId: testEntity.id,
              vectorClock: testClock,
              payloadType: SyncSequencePayloadType.agentEntity,
            ),
          ).called(1);
        },
      );

      test(
        'swallows sequence-log error after entity is saved — sequence is '
        'a best-effort post-write record; the VC is already on disk',
        () async {
          final sequenceLog = MockSyncSequenceLogService();
          when(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              payloadType: any(named: 'payloadType'),
            ),
          ).thenThrow(StateError('sequence ledger boom'));
          final service = AgentSyncService(
            repository: mockRepository,
            outboxService: mockOutboxService,
            vectorClockService: mockVectorClockService,
            sequenceLogService: sequenceLog,
          );

          // Must NOT rethrow; outbox enqueue must still occur.
          await service.upsertEntity(testEntity);

          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
        },
      );

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

      test('records the agent link sequence before enqueuing', () async {
        final sequenceLog = MockSyncSequenceLogService();
        when(
          () => sequenceLog.recordSentEntry(
            entryId: any(named: 'entryId'),
            vectorClock: any(named: 'vectorClock'),
            payloadType: any(named: 'payloadType'),
          ),
        ).thenAnswer((_) async {});
        final service = AgentSyncService(
          repository: mockRepository,
          outboxService: mockOutboxService,
          vectorClockService: mockVectorClockService,
          sequenceLogService: sequenceLog,
        );

        await service.upsertLink(testBasicLink);

        verifyInOrder([
          () => sequenceLog.recordSentEntry(
            entryId: testBasicLink.id,
            vectorClock: testClock,
            payloadType: SyncSequencePayloadType.agentLink,
          ),
          () => mockOutboxService.enqueueMessage(any<SyncMessage>()),
        ]);
      });

      test(
        'swallows sequence-log error after link is saved — best-effort '
        'record must not cascade into the upsertLink flow',
        () async {
          final sequenceLog = MockSyncSequenceLogService();
          when(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              payloadType: any(named: 'payloadType'),
            ),
          ).thenThrow(StateError('sequence ledger boom'));
          final service = AgentSyncService(
            repository: mockRepository,
            outboxService: mockOutboxService,
            vectorClockService: mockVectorClockService,
            sequenceLogService: sequenceLog,
          );

          await service.upsertLink(testBasicLink);

          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
        },
      );

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
        // Local agent-state writes re-read the persisted head to preserve it;
        // this test isn't about head preservation, so no prior state exists.
        when(
          () => generatedRepository.getAgentState(any()),
        ).thenAnswer((_) async => null);
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
      }, tags: 'glados');

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
        'inner TX rollback caught by outer truncates buffered sequence '
        'bindings so the outer commit does not record sent-sequence rows '
        'for inner writes that were rolled back by the savepoint',
        () async {
          final sequenceLog = MockSyncSequenceLogService();
          when(
            () => sequenceLog.recordSentEntry(
              entryId: any(named: 'entryId'),
              vectorClock: any(named: 'vectorClock'),
              payloadType: any(named: 'payloadType'),
            ),
          ).thenAnswer((_) async {});
          final service = AgentSyncService(
            repository: mockRepository,
            outboxService: mockOutboxService,
            vectorClockService: mockVectorClockService,
            sequenceLogService: sequenceLog,
          );

          await service.runInTransaction(() async {
            await service.upsertEntity(testEntity);

            try {
              await service.runInTransaction(() async {
                await service.upsertLink(testBasicLink);
                await service.upsertEntity(testStateEntity);
                throw Exception('inner rollback');
              });
            } on Exception {
              // Caught — outer TX continues.
            }
          });

          // Only the outer entity's sequence binding survived; the inner
          // link + state entity bindings were truncated on inner rollback.
          verify(
            () => sequenceLog.recordSentEntry(
              entryId: testEntity.id,
              vectorClock: any(named: 'vectorClock'),
              payloadType: SyncSequencePayloadType.agentEntity,
            ),
          ).called(1);
          verifyNever(
            () => sequenceLog.recordSentEntry(
              entryId: testBasicLink.id,
              vectorClock: any(named: 'vectorClock'),
              payloadType: any(named: 'payloadType'),
            ),
          );
          verifyNever(
            () => sequenceLog.recordSentEntry(
              entryId: testStateEntity.id,
              vectorClock: any(named: 'vectorClock'),
              payloadType: any(named: 'payloadType'),
            ),
          );
        },
      );

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

  group('AgentSyncService.upsertEntity — local message append', () {
    AgentMessageEntity newMessage() => makeTestMessage(
      id: 'm-new',
      agentId: 'agent-1',
      createdAt: DateTime(2024, 3, 15),
    );

    test('chains a new message to the current head and advances it', () async {
      when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
        (_) async => makeTestState(agentId: 'agent-1').copyWith(
          recentHeadMessageId: 'old-head',
        ),
      );

      await syncService.upsertEntity(newMessage());

      final upserted = verify(
        () => mockRepository.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      // Message stamped with prevMessageId = head; state advanced to the new id.
      expect(
        upserted.whereType<AgentMessageEntity>().single.prevMessageId,
        'old-head',
      );
      expect(
        upserted.whereType<AgentStateEntity>().single.recentHeadMessageId,
        'm-new',
      );
      // A messagePrev link new → head with a deterministic id.
      final link =
          verify(() => mockRepository.upsertLink(captureAny())).captured.single
              as AgentLink;
      expect(
        link,
        isA<MessagePrevLink>()
            .having((l) => l.id, 'id', 'msgprev-m-new')
            .having((l) => l.fromId, 'fromId', 'm-new')
            .having((l) => l.toId, 'toId', 'old-head'),
      );
    });

    test('a first message (no head) is a root — no link, head set', () async {
      when(
        () => mockRepository.getAgentState('agent-1'),
      ).thenAnswer((_) async => makeTestState(agentId: 'agent-1'));

      await syncService.upsertEntity(newMessage());

      final upserted = verify(
        () => mockRepository.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      expect(
        upserted.whereType<AgentMessageEntity>().single.prevMessageId,
        isNull,
      );
      expect(
        upserted.whereType<AgentStateEntity>().single.recentHeadMessageId,
        'm-new',
      );
      verifyNever(() => mockRepository.upsertLink(any()));
    });

    test(
      'backfills a legacy edge-less prefix into a chain on first append',
      () async {
        // Legacy agent: messages exist, but the head pointer was never set.
        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => makeTestState(agentId: 'agent-1'));
        when(() => mockRepository.getAgentMessages('agent-1')).thenAnswer(
          (_) async => [
            makeTestMessage(
              id: 'mA',
              agentId: 'agent-1',
              createdAt: DateTime(2024),
            ),
            makeTestMessage(
              id: 'mB',
              agentId: 'agent-1',
              createdAt: DateTime(2024, 1, 2),
            ),
            makeTestMessage(
              id: 'mC',
              agentId: 'agent-1',
              createdAt: DateTime(2024, 1, 3),
            ),
          ],
        );

        await syncService.upsertEntity(newMessage());

        // Prefix chained A←B←C, then the new message extends from C — one spine.
        final edges = {
          for (final link in verify(
            () => mockRepository.upsertLink(captureAny()),
          ).captured.cast<AgentLink>())
            (link as MessagePrevLink).fromId: link.toId,
        };
        expect(edges, {'mB': 'mA', 'mC': 'mB', 'm-new': 'mC'});

        final message = verify(() => mockRepository.upsertEntity(captureAny()))
            .captured
            .cast<AgentDomainEntity>()
            .whereType<AgentMessageEntity>()
            .single;
        expect(message.prevMessageId, 'mC');
      },
    );

    test('with no state row, only the message is persisted', () async {
      when(
        () => mockRepository.getAgentState('agent-1'),
      ).thenAnswer((_) async => null);

      await syncService.upsertEntity(newMessage());

      final upserted = verify(
        () => mockRepository.upsertEntity(captureAny()),
      ).captured;
      expect(upserted.length, 1); // message only — no state update
      expect((upserted.single as AgentMessageEntity).prevMessageId, isNull);
      verifyNever(() => mockRepository.upsertLink(any()));
    });

    test('skips backfill when there is no state row even if messages exist — '
        'avoids a per-append full-history rescan', () async {
      // No state row, but the agent already has messages. Without the
      // state-row guard, head stays null → backfill would re-scan every append
      // (the advanced head is never persisted without a state row → quadratic).
      when(
        () => mockRepository.getAgentState('agent-1'),
      ).thenAnswer((_) async => null);
      when(() => mockRepository.getAgentMessages('agent-1')).thenAnswer(
        (_) async => [makeTestMessage(id: 'mA', agentId: 'agent-1')],
      );

      await syncService.upsertEntity(newMessage());

      verifyNever(() => mockRepository.getAgentMessages(any()));
      final upserted = verify(
        () => mockRepository.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      // Persisted as a root; no edge, no head advance.
      expect(
        upserted.whereType<AgentMessageEntity>().single.prevMessageId,
        isNull,
      );
      verifyNever(() => mockRepository.upsertLink(any()));
    });

    test('re-appending an existing message preserves its edge and does not '
        're-chain it (no self-link)', () async {
      // The message is already persisted with a parent edge, and it is also the
      // current head — the worst case for a naive retry (would self-link m→m).
      when(() => mockRepository.getEntity('m-new')).thenAnswer(
        (_) async => newMessage().copyWith(prevMessageId: 'old-head'),
      );

      await syncService.upsertEntity(newMessage());

      final upserted = verify(
        () => mockRepository.upsertEntity(captureAny()),
      ).captured.cast<AgentDomainEntity>();
      final message = upserted.whereType<AgentMessageEntity>().single;
      // Existing edge preserved; emphatically not a self-link to its own id.
      expect(message.prevMessageId, 'old-head');
      expect(message.prevMessageId, isNot('m-new'));
      // Short-circuits before any chaining: no new link, no head advance, and
      // it never even reads the head.
      verifyNever(() => mockRepository.upsertLink(any()));
      expect(upserted.whereType<AgentStateEntity>(), isEmpty);
      verifyNever(() => mockRepository.getAgentState(any()));
    });
  });

  group('AgentSyncService.appendMilestone', () {
    AgentMessageEntity capturedMessage() => verify(
      () => mockRepository.upsertEntity(captureAny()),
    ).captured.whereType<AgentMessageEntity>().single;

    test('emits a system message tagged with the milestone, via the append '
        'path', () async {
      when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
        (_) async => makeTestState(agentId: 'agent-1').copyWith(
          recentHeadMessageId: 'prev-head',
        ),
      );

      await syncService.appendMilestone(
        agentId: 'agent-1',
        milestone: AgentMilestone.wakeCompleted,
        createdAt: DateTime(2024, 3, 15),
        threadId: 'thread-1',
        runKey: 'run-1',
      );

      final message = capturedMessage();
      expect(message.kind, AgentMessageKind.system);
      expect(message.agentId, 'agent-1');
      expect(message.threadId, 'thread-1');
      expect(message.createdAt, DateTime(2024, 3, 15));
      expect(message.metadata.milestone, AgentMilestone.wakeCompleted);
      expect(message.metadata.runKey, 'run-1');
      // Routed through _appendMessage: chained to the head and head advanced.
      expect(message.prevMessageId, 'prev-head');
      expect(
        verify(() => mockRepository.upsertLink(captureAny())).captured.single,
        isA<MessagePrevLink>()
            .having((l) => l.fromId, 'fromId', message.id)
            .having((l) => l.toId, 'toId', 'prev-head'),
      );
    });

    test('defaults threadId to the marker id for thread-less paths', () async {
      await syncService.appendMilestone(
        agentId: 'agent-1',
        milestone: AgentMilestone.oneOnOneCompleted,
        createdAt: DateTime(2024, 3, 15),
      );

      final message = capturedMessage();
      // No wake thread to join (dormant-skip / one-on-one): the marker stands
      // alone in its own thread keyed by its own id.
      expect(message.threadId, message.id);
      expect(message.metadata.milestone, AgentMilestone.oneOnOneCompleted);
      expect(message.metadata.runKey, isNull);
    });

    glados.Glados(
      glados.any.milestoneScenario,
      glados.ExploreConfig(numRuns: 200),
    ).test('emits a system marker preserving milestone, runKey and createdAt, '
        'defaulting threadId to the marker id', (scenario) async {
      // Fresh wiring per run so captures don't accumulate across iterations.
      final repository = MockAgentRepository();
      final upserted = <AgentDomainEntity>[];
      when(() => repository.upsertEntity(any())).thenAnswer((invocation) async {
        upserted.add(
          invocation.positionalArguments.single as AgentDomainEntity,
        );
      });
      when(() => repository.upsertLink(any())).thenAnswer((_) async {});
      when(() => repository.getEntity(any())).thenAnswer((_) async => null);
      when(
        () => repository.getAgentState(any()),
      ).thenAnswer((_) async => null);
      when(
        () => repository.getAgentMessages(any()),
      ).thenAnswer((_) async => <AgentMessageEntity>[]);
      final outboxService = MockOutboxService();
      when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});
      final vectorClockService = MockVectorClockService();
      when(
        () => vectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer((_) async => testClock);
      final service = AgentSyncService(
        repository: repository,
        outboxService: outboxService,
        vectorClockService: vectorClockService,
      );

      await service.appendMilestone(
        agentId: 'agent-x',
        milestone: scenario.milestone,
        createdAt: scenario.createdAt,
        threadId: scenario.threadId,
        runKey: scenario.runKey,
      );

      final message = upserted.whereType<AgentMessageEntity>().single;
      expect(message.kind, AgentMessageKind.system, reason: '$scenario');
      expect(message.agentId, 'agent-x', reason: '$scenario');
      expect(message.createdAt, scenario.createdAt, reason: '$scenario');
      expect(
        message.metadata.milestone,
        scenario.milestone,
        reason: '$scenario',
      );
      expect(message.metadata.runKey, scenario.runKey, reason: '$scenario');
      // An explicit thread joins the wake; otherwise the marker keys its own.
      expect(
        message.threadId,
        scenario.threadId ?? message.id,
        reason: '$scenario',
      );
    }, tags: 'glados');
  });

  group('AgentSyncService.upsertEntity — agent-state head preservation', () {
    AgentStateEntity callerState({String? head, DateTime? lastWakeAt}) =>
        makeTestState(agentId: 'agent-1').copyWith(
          recentHeadMessageId: head,
          lastWakeAt: lastWakeAt,
        );

    glados.Glados(
      glados.any.headPreservationScenario,
      glados.ExploreConfig(numRuns: 200),
    ).test('a local write keeps the persisted head and the other caller '
        'fields, for any head combination', (scenario) async {
      // Fresh wiring per run so captures don't accumulate across iterations.
      final repository = MockAgentRepository();
      final upserted = <AgentDomainEntity>[];
      when(() => repository.upsertEntity(any())).thenAnswer((invocation) async {
        upserted.add(
          invocation.positionalArguments.single as AgentDomainEntity,
        );
      });
      when(() => repository.getAgentState('agent-1')).thenAnswer(
        (_) async => scenario.persistedStateExists
            ? makeTestState(
                agentId: 'agent-1',
              ).copyWith(recentHeadMessageId: scenario.persistedHead)
            : null,
      );
      final outboxService = MockOutboxService();
      when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});
      final vectorClockService = MockVectorClockService();
      when(
        () => vectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
        ),
      ).thenAnswer((_) async => testClock);
      final service = AgentSyncService(
        repository: repository,
        outboxService: outboxService,
        vectorClockService: vectorClockService,
      );

      await service.upsertEntity(
        callerState(head: scenario.callerHead, lastWakeAt: scenario.lastWakeAt),
      );

      final written = upserted.whereType<AgentStateEntity>().single;
      // The append-owned head is never clobbered by the caller's stale value;
      // a first-ever write (no persisted row) keeps the caller's value.
      expect(
        written.recentHeadMessageId,
        scenario.expectedHead,
        reason: '$scenario',
      );
      // The caller's genuine field updates are untouched.
      expect(written.lastWakeAt, scenario.lastWakeAt, reason: '$scenario');
    }, tags: 'glados');

    test(
      'a synced (fromSync) state write keeps its own head, unread',
      () async {
        // Sync-received state carries the resolver-merged head; it must not be
        // overwritten with the local DB head, and the local head is never read.
        await syncService.upsertEntity(
          callerState(head: 'remote-head'),
          fromSync: true,
        );

        final written = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured.whereType<AgentStateEntity>().single;
        expect(written.recentHeadMessageId, 'remote-head');
        verifyNever(() => mockRepository.getAgentState(any()));
      },
    );
  });

  group('AgentSyncService.reconciledAgentState', () {
    test('returns null when the agent has no state row', () async {
      when(
        () => mockRepository.getAgentState('agent-x'),
      ).thenAnswer((_) async => null);

      expect(await syncService.reconciledAgentState('agent-x'), isNull);
    });

    test('returns the cache and does not persist when nothing diverged '
        '(empty log preserves the cached watermark)', () async {
      final cache = makeTestState(
        agentId: 'agent-1',
        lastWakeAt: DateTime(2024, 3, 5),
      );
      when(
        () => mockRepository.getAgentState('agent-1'),
      ).thenAnswer((_) async => cache);

      final result = await syncService.reconciledAgentState('agent-1');

      expect(result, cache);
      // Migration-safe no-op: an empty log must not null the cached watermark,
      // and an unchanged row must not be re-persisted (no outbox churn).
      verifyNever(() => mockRepository.upsertEntity(any()));
    });

    test('heals and persists when the log has a newer watermark', () async {
      final cache = makeTestState(
        agentId: 'agent-1',
        lastWakeAt: DateTime(2024, 3),
      );
      final marker = makeTestMessage(
        id: 'w',
        agentId: 'agent-1',
        kind: AgentMessageKind.system,
        createdAt: DateTime(2024, 3, 9),
        metadata: const AgentMessageMetadata(
          milestone: AgentMilestone.wakeCompleted,
        ),
      );
      when(
        () => mockRepository.getAgentState('agent-1'),
      ).thenAnswer((_) async => cache);
      when(
        () => mockRepository.getMessagesByKind(
          'agent-1',
          AgentMessageKind.system,
        ),
      ).thenAnswer((_) async => [marker]);

      final result = await syncService.reconciledAgentState('agent-1');

      expect(result!.lastWakeAt, DateTime(2024, 3, 9));
      // The healed row is persisted, propagating the correction to peers.
      final upserted = verify(
        () => mockRepository.upsertEntity(captureAny()),
      ).captured.whereType<AgentStateEntity>().single;
      expect(upserted.lastWakeAt, DateTime(2024, 3, 9));
    });
  });
}
