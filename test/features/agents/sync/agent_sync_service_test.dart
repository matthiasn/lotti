import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/projection/join_plan.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/sync/agent_sync_service.dart';
import 'package:lotti/features/sync/model/sync_message.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_log_service.dart';
import 'package:lotti/features/sync/sequence/sync_sequence_payload_type.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../agent_test_device.dart';
import '../test_data/entity_factories.dart';
import '../test_data/evolution_factories.dart';
import 'agent_replica_bench.dart';
import 'fork_test_support.dart';
import 'in_memory_agent_repository.dart';

part 'agent_links_model_conformance.dart';
part 'agent_replication_model_conformance.dart';

/// Records whether the scope accepts or releases a reservation, without
/// pretending that a repository call proves the scope committed successfully.
class _RecordingVectorClockService extends MockVectorClockService {
  final outcomes = <String>[];

  @override
  Future<T> withVcScope<T>(
    Future<T> Function() action, {
    bool Function(T result)? commitWhen,
  }) async {
    try {
      final result = await action();
      outcomes.add((commitWhen?.call(result) ?? true) ? 'commit' : 'release');
      return result;
    } catch (_) {
      outcomes.add('release');
      rethrow;
    }
  }
}

enum _GeneratedSyncWriteKind {
  entity,
  link,
  entityFromSync,
  linkFromSync,
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

enum _GeneratedPersistedWriteKind { entity, link }

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

/// Simulates a parse completion trying to commit after a legacy rewrite reads
/// the capture. A repository transaction serializes that completion after the
/// rewrite; without one it lands between the read and write and is overwritten.
class _InterleavingCaptureRepository extends MockAgentRepository {
  _InterleavingCaptureRepository({
    required CaptureEntity initial,
    required this.completedAt,
  }) : stored = initial;

  final DateTime completedAt;
  CaptureEntity stored;
  bool _insideTransaction = false;
  bool _completeAfterTransaction = false;
  int transactionCount = 0;

  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    transactionCount++;
    _insideTransaction = true;
    try {
      return await action();
    } finally {
      _insideTransaction = false;
      if (_completeAfterTransaction) {
        stored = stored.copyWith(parseCompletedAt: completedAt);
        _completeAfterTransaction = false;
      }
    }
  }

  @override
  Future<AgentDomainEntity?> getEntity(String id) async {
    final snapshot = stored;
    if (_insideTransaction) {
      _completeAfterTransaction = true;
    } else {
      stored = stored.copyWith(parseCompletedAt: completedAt);
    }
    return snapshot;
  }

  @override
  Future<void> upsertEntity(AgentDomainEntity entity) async {
    stored = entity as CaptureEntity;
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
      _GeneratedSyncWriteKind.entity || _GeneratedSyncWriteKind.link => false,
      _GeneratedSyncWriteKind.entityFromSync ||
      _GeneratedSyncWriteKind.linkFromSync => true,
    };
  }

  _GeneratedPersistedWriteKind get persistedKind {
    return switch (this) {
      _GeneratedSyncWriteKind.entity ||
      _GeneratedSyncWriteKind.entityFromSync =>
        _GeneratedPersistedWriteKind.entity,
      _GeneratedSyncWriteKind.link ||
      _GeneratedSyncWriteKind.linkFromSync => _GeneratedPersistedWriteKind.link,
    };
  }

  _GeneratedSyncMessageKind? get outboxMessageKind {
    if (fromSync) return null;
    return switch (this) {
      _GeneratedSyncWriteKind.entity => _GeneratedSyncMessageKind.entity,
      _GeneratedSyncWriteKind.link => _GeneratedSyncMessageKind.link,
      _GeneratedSyncWriteKind.entityFromSync ||
      _GeneratedSyncWriteKind.linkFromSync => null,
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
  _registerReplicationModelConformance();
  _registerLinkModelConformance();
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

  setUp(() async {
    // Register a fake DomainLogger so _enqueuePostWrite can log swallowed
    // outbox errors without blowing up on an unregistered GetIt lookup.
    await setUpTestGetIt(
      additionalSetup: () {
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(MockDomainLogger());
      },
    );

    mockRepository = MockAgentRepository();
    mockOutboxService = MockOutboxService();
    mockVectorClockService = MockVectorClockService();

    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});
    // A link write reads the version stored under its id, a tombstone
    // included, to succeed it; default to none.
    when(
      () => mockRepository.getLinkByIdIncludingDeleted(any()),
    ).thenAnswer((_) async => null);
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
    // Head recovery (an unset head over a non-empty log) reads the log's
    // messagePrev edges; default to none (a legacy, edge-less log).
    when(
      () => mockRepository.getLinksFromMultiple(
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => <String, List<AgentLink>>{});
    // An append advances a set head past any child it has here; default to
    // none, so the head is already the tip.
    when(
      () => mockRepository.getLinksToMultiple(
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => <String, List<AgentLink>>{});
    // The append path's idempotency guard looks the message up first; default
    // to "not yet persisted" so a plain append proceeds to chaining.
    when(() => mockRepository.getEntity(any())).thenAnswer((_) async => null);
    when(
      () => mockOutboxService.enqueueMessage(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockVectorClockService.getNextVectorClock(
        previous: any(named: 'previous'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async => testClock);

    syncService = AgentSyncService(
      repository: mockRepository,
      outboxService: mockOutboxService,
      vectorClockService: mockVectorClockService,
    );
  });

  tearDown(tearDownTestGetIt);

  group('AgentSyncService', () {
    group('updateAgentState', () {
      test(
        'updates the latest row while preserving the append-owned head',
        () async {
          final current = (testStateEntity as AgentStateEntity).copyWith(
            recentHeadMessageId: 'current-head',
            scheduledWakeAt: DateTime(2026, 8, 15, 6),
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => current);

          final changed = await syncService.updateAgentState(
            'agent-1',
            (state) => state.copyWith(
              recentHeadMessageId: 'stale-head',
              scheduledWakeAt: null,
            ),
          );

          expect(changed, isTrue);
          final written =
              verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(written.scheduledWakeAt, isNull);
          expect(written.recentHeadMessageId, 'current-head');
          expect(written.vectorClock, testClock);
          verify(
            () => mockOutboxService.enqueueMessage(
              any(
                that: isA<SyncAgentEntity>().having(
                  (message) => message.agentEntity,
                  'agentEntity',
                  written,
                ),
              ),
            ),
          ).called(1);
        },
      );

      test('does not write when the row is absent or unchanged', () async {
        expect(
          await syncService.updateAgentState('agent-1', (state) => state),
          isFalse,
        );

        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => testStateEntity as AgentStateEntity);
        expect(
          await syncService.updateAgentState('agent-1', (state) => state),
          isFalse,
        );

        verifyNever(() => mockRepository.upsertEntity(any()));
        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test(
        'rejects a transform that replaces the state row identity',
        () async {
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => testStateEntity as AgentStateEntity);

          await expectLater(
            () => syncService.updateAgentState(
              'agent-1',
              (state) => state.copyWith(id: 'different-state'),
            ),
            throwsArgumentError,
          );

          verifyNever(() => mockRepository.upsertEntity(any()));
        },
      );
    });

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
          () => mockVectorClockService.getNextVectorClock(
            payload: any(named: 'payload'),
          ),
        ).called(1);
      });

      test(
        'names the entity as the reservation payload and leaves binding the '
        'sequence log to the outbox',
        () async {
          final sequenceLog = MockSyncSequenceLogService();
          getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
          addTearDown(() => getIt.unregister<SyncSequenceLogService>());

          await syncService.upsertEntity(testEntity);

          verify(
            () => mockVectorClockService.getNextVectorClock(
              previous: any(named: 'previous'),
              payload: (
                id: testEntity.id,
                type: SyncSequencePayloadType.agentEntity,
              ),
            ),
          ).called(1);
          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
          // Binding before the enqueue is durable would mark the counter
          // `received` while nothing would ever send it after a crash.
          verifyZeroInteractions(sequenceLog);
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
            payload: any(named: 'payload'),
          ),
        );
      });

      test(
        'propagates a preserved capture completion marker in the sync envelope',
        () async {
          final completedAt = DateTime(2026, 3, 15, 10);
          final completed =
              AgentDomainEntity.capture(
                    id: 'capture-1',
                    agentId: 'agent-1',
                    transcript: 'Original',
                    capturedAt: testDate,
                    createdAt: testDate,
                    vectorClock: const VectorClock({'local': 1}),
                    parseCompletedAt: completedAt,
                  )
                  as CaptureEntity;
          final legacyRewrite = completed.copyWith(
            transcript: 'Legacy rewrite',
            vectorClock: const VectorClock({'legacy': 2}),
            parseCompletedAt: null,
          );
          when(
            () => mockRepository.getEntity(completed.id),
          ).thenAnswer((_) async => completed);

          await syncService.upsertEntity(legacyRewrite);

          final persisted =
              verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.single
                  as CaptureEntity;
          expect(persisted.transcript, legacyRewrite.transcript);
          expect(persisted.parseCompletedAt, completedAt);
          expect(persisted.vectorClock, testClock);

          final message =
              verify(
                    () => mockOutboxService.enqueueMessage(captureAny()),
                  ).captured.single
                  as SyncAgentEntity;
          final syncedCapture = message.agentEntity! as CaptureEntity;
          expect(syncedCapture.parseCompletedAt, completedAt);
          expect(syncedCapture.vectorClock, testClock);
        },
      );

      test(
        'propagates the stable capture day in the sync envelope',
        () async {
          final existing =
              AgentDomainEntity.capture(
                    id: 'capture-stable-day',
                    agentId: 'agent-1',
                    transcript: 'Original',
                    capturedAt: testDate,
                    createdAt: testDate,
                    dayId: 'dayplan-2024-03-14',
                    vectorClock: const VectorClock({'local': 1}),
                  )
                  as CaptureEntity;
          final legacyRewrite = existing.copyWith(
            transcript: 'Legacy rewrite',
            dayId: '',
            vectorClock: const VectorClock({'legacy': 2}),
          );
          when(
            () => mockRepository.getEntity(existing.id),
          ).thenAnswer((_) async => existing);

          await syncService.upsertEntity(legacyRewrite);

          final persisted =
              verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.single
                  as CaptureEntity;
          final message =
              verify(
                    () => mockOutboxService.enqueueMessage(captureAny()),
                  ).captured.single
                  as SyncAgentEntity;
          final syncedCapture = message.agentEntity! as CaptureEntity;

          expect(persisted.dayId, existing.dayId);
          expect(syncedCapture.dayId, existing.dayId);
          expect(syncedCapture.vectorClock, persisted.vectorClock);
        },
      );

      test(
        'serializes an interleaved capture completion after a legacy rewrite',
        () async {
          final completedAt = DateTime(2026, 3, 15, 10);
          final legacyRewrite =
              AgentDomainEntity.capture(
                    id: 'capture-1',
                    agentId: 'agent-1',
                    transcript: 'Legacy rewrite',
                    capturedAt: testDate,
                    createdAt: testDate,
                    vectorClock: const VectorClock({'legacy': 2}),
                  )
                  as CaptureEntity;
          final repository = _InterleavingCaptureRepository(
            initial: legacyRewrite,
            completedAt: completedAt,
          );
          final service = AgentSyncService(
            repository: repository,
            outboxService: mockOutboxService,
            vectorClockService: mockVectorClockService,
          );

          await service.upsertEntity(legacyRewrite);

          expect(repository.transactionCount, 1);
          expect(repository.stored.transcript, legacyRewrite.transcript);
          expect(repository.stored.parseCompletedAt, completedAt);
        },
      );

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
        final failure = StateError('entity write failed');
        when(
          () => mockRepository.upsertEntity(any()),
        ).thenAnswer((_) async => throw failure);

        await expectLater(
          () => syncService.upsertEntity(testEntity),
          throwsA(same(failure)),
        );

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test(
        'swallows outbox error after entity is saved — preserves the '
        'commit-on-write invariant so the already-persisted VC counter is '
        'not re-handed to another entity by the next reservation',
        () async {
          final failure = StateError('entity enqueue failed');
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async => throw failure);

          // Must NOT throw: the DB write already claimed the VC on disk; an
          // outbox-layer failure cannot be allowed to cascade into a VC
          // rewind.
          await syncService.upsertEntity(testEntity);

          final stamped = testEntity.copyWith(vectorClock: testClock);
          verify(() => mockRepository.upsertEntity(stamped)).called(1);
          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
          verify(
            () => getIt<DomainLogger>().error(
              LogDomain.sync,
              failure,
              message: any(named: 'message'),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'upsertEntity.enqueue',
            ),
          ).called(1);
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

      test(
        'names the link as the reservation payload and leaves binding the '
        'sequence log to the outbox',
        () async {
          final sequenceLog = MockSyncSequenceLogService();
          getIt.registerSingleton<SyncSequenceLogService>(sequenceLog);
          addTearDown(() => getIt.unregister<SyncSequenceLogService>());

          await syncService.upsertLink(testBasicLink);

          verify(
            () => mockVectorClockService.getNextVectorClock(
              previous: any(named: 'previous'),
              payload: (
                id: testBasicLink.id,
                type: SyncSequencePayloadType.agentLink,
              ),
            ),
          ).called(1);
          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
          verifyZeroInteractions(sequenceLog);
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
            payload: any(named: 'payload'),
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
        final failure = StateError('link write failed');
        when(
          () => mockRepository.upsertLink(any()),
        ).thenAnswer((_) async => throw failure);

        await expectLater(
          () => syncService.upsertLink(testBasicLink),
          throwsA(same(failure)),
        );

        verifyNever(() => mockOutboxService.enqueueMessage(any()));
      });

      test(
        'swallows outbox error after link is saved — see upsertEntity '
        'twin for the commit-on-write rationale',
        () async {
          final failure = StateError('link enqueue failed');
          when(
            () => mockOutboxService.enqueueMessage(any()),
          ).thenAnswer((_) async => throw failure);

          await syncService.upsertLink(testBasicLink);

          final stamped = testBasicLink.copyWith(vectorClock: testClock);
          verify(() => mockRepository.upsertLink(stamped)).called(1);
          verify(() => mockOutboxService.enqueueMessage(any())).called(1);
          verify(
            () => getIt<DomainLogger>().error(
              LogDomain.sync,
              failure,
              message: any(named: 'message'),
              stackTrace: any(named: 'stackTrace'),
              subDomain: 'upsertLink.enqueue',
            ),
          ).called(1);
        },
      );
    });

    group('repository', () {
      test('exposes underlying repository for reads', () {
        expect(syncService.repository, same(mockRepository));
      });
    });

    group('localHost', () {
      test('returns the host id from the vector clock service', () async {
        when(
          () => mockVectorClockService.getHost(),
        ).thenAnswer((_) async => 'host-abc');

        expect(await syncService.localHost(), 'host-abc');
        verify(() => mockVectorClockService.getHost()).called(1);
      });

      test('throws a StateError when the host id is unset', () async {
        when(
          () => mockVectorClockService.getHost(),
        ).thenAnswer((_) async => null);

        await expectLater(
          syncService.localHost(),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('no host id'),
            ),
          ),
        );
      });
    });

    test(
      'runInTransaction rethrows a deferred outbox-flush failure after the '
      'VC scope commits',
      () async {
        final clocks = _RecordingVectorClockService();
        when(
          () => clocks.getNextVectorClock(
            previous: any(named: 'previous'),
            payload: any(named: 'payload'),
          ),
        ).thenAnswer((_) async => testClock);
        final service = AgentSyncService(
          repository: mockRepository,
          outboxService: mockOutboxService,
          vectorClockService: clocks,
        );
        final failure = StateError('outbox down');
        when(
          () => mockOutboxService.enqueueMessage(any()),
        ).thenAnswer((_) async => throw failure);

        await expectLater(
          service.runInTransaction(() async {
            await service.upsertEntity(testEntity);
          }),
          throwsA(same(failure)),
        );

        // The DB write itself committed before the flush failed — the
        // deferred rethrow happens outside the VC scope.
        verify(() => mockRepository.upsertEntity(any())).called(1);
        expect(clocks.outcomes, ['commit', 'commit']);
      },
    );

    group('runInTransaction', () {
      glados.Glados(
        glados.any.syncTransactionScenario,
        glados.ExploreConfig(numRuns: 160),
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
        // Nor is it about resolving a write against the persisted row.
        when(
          () => generatedRepository.getEntity(any()),
        ).thenAnswer((_) async => null);
        when(
          () => generatedRepository.getLinkByIdIncludingDeleted(any()),
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
            payload: any(named: 'payload'),
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

      for (final rollbackFirst in [true, false]) {
        test(
          'concurrent chains isolate rollback when '
          '${rollbackFirst ? 'rollback' : 'commit'} finishes first',
          () {
            fakeAsync((async) {
              final releaseRollback = Completer<void>();
              final releaseCommit = Completer<void>();
              final failure = StateError('chain A rollback');
              final enqueued = <SyncMessage>[];
              when(
                () => mockOutboxService.enqueueMessage(any()),
              ).thenAnswer((invocation) async {
                enqueued.add(
                  invocation.positionalArguments.single as SyncMessage,
                );
              });
              final service = AgentSyncService(
                repository: mockRepository,
                outboxService: mockOutboxService,
                vectorClockService: mockVectorClockService,
              );

              // The repository boundary lets both callbacks overlap. SQLite's
              // actual write atomicity is checked by agent_repository_test.
              var rollbackReady = false;
              var commitReady = false;
              var rollbackObserved = false;
              String? committedResult;
              final rollingBack = service.runInTransaction<void>(() async {
                await service.upsertEntity(testEntity);
                rollbackReady = true;
                await releaseRollback.future;
                throw failure;
              });
              unawaited(
                expectLater(rollingBack, throwsA(same(failure))).then(
                  (_) => rollbackObserved = true,
                ),
              );
              unawaited(
                service
                    .runInTransaction(() async {
                      await service.upsertLink(testBasicLink);
                      commitReady = true;
                      await releaseCommit.future;
                      return 'chain B committed';
                    })
                    .then((value) => committedResult = value),
              );
              try {
                async.flushMicrotasks();
                expect(rollbackReady, isTrue);
                expect(commitReady, isTrue);
                expect(rollbackObserved, isFalse);
                expect(committedResult, isNull);
                expect(enqueued, isEmpty);

                final expectedMessages = [
                  SyncMessage.agentLink(
                    agentLink: testBasicLink.copyWith(vectorClock: testClock),
                    status: SyncEntryStatus.update,
                  ),
                ];
                if (rollbackFirst) {
                  releaseRollback.complete();
                  async.flushMicrotasks();
                  expect(rollbackObserved, isTrue);
                  expect(committedResult, isNull);
                  expect(enqueued, isEmpty);
                  releaseCommit.complete();
                } else {
                  releaseCommit.complete();
                  async.flushMicrotasks();
                  expect(committedResult, 'chain B committed');
                  expect(rollbackObserved, isFalse);
                  expect(enqueued, expectedMessages);
                  releaseRollback.complete();
                }
                async.flushMicrotasks();
                expect(rollbackObserved, isTrue);
                expect(committedResult, 'chain B committed');
                expect(enqueued, expectedMessages);
                verify(
                  () => mockRepository.upsertEntity(
                    testEntity.copyWith(vectorClock: testClock),
                  ),
                ).called(1);
                verify(
                  () => mockRepository.upsertLink(
                    testBasicLink.copyWith(vectorClock: testClock),
                  ),
                ).called(1);
              } finally {
                // Settle the expected failure even when an earlier assertion
                // fails, so a useful mismatch cannot become a timeout.
                if (!releaseRollback.isCompleted) releaseRollback.complete();
                if (!releaseCommit.isCompleted) releaseCommit.complete();
                async.flushMicrotasks();
              }
            });
          },
        );
      }

      for (final failedSlots in [
        {0},
        {1},
        {2},
        {0, 2},
      ]) {
        test(
          'partial enqueue failure at $failedSlots preserves ordered payloads '
          'and does not contaminate the next transaction',
          () async {
            final attempted = <SyncMessage>[];
            final accepted = <SyncMessage>[];
            final failures = List.generate(
              3,
              (index) => StateError('outbox slot $index'),
            );
            when(
              () => mockOutboxService.enqueueMessage(any()),
            ).thenAnswer((invocation) async {
              final message =
                  invocation.positionalArguments.single as SyncMessage;
              final slot = attempted.length;
              attempted.add(message);
              if (failedSlots.contains(slot)) throw failures[slot];
              accepted.add(message);
            });
            final expected = [
              SyncMessage.agentEntity(
                agentEntity: testEntity.copyWith(vectorClock: testClock),
                status: SyncEntryStatus.update,
              ),
              SyncMessage.agentLink(
                agentLink: testBasicLink.copyWith(vectorClock: testClock),
                status: SyncEntryStatus.update,
              ),
              SyncMessage.agentEntity(
                agentEntity: testPayloadEntity.copyWith(vectorClock: testClock),
                status: SyncEntryStatus.update,
              ),
            ];

            await expectLater(
              syncService.runInTransaction(() async {
                await syncService.upsertEntity(testEntity);
                await syncService.upsertLink(testBasicLink);
                await syncService.upsertEntity(testPayloadEntity);
                expect(attempted, isEmpty);
              }),
              throwsA(same(failures[failedSlots.first])),
            );
            expect(attempted, expected);
            final expectedAccepted = [
              for (var slot = 0; slot < expected.length; slot++)
                if (!failedSlots.contains(slot)) expected[slot],
            ];
            expect(accepted, expectedAccepted);

            final nextLink = testBasicLink.copyWith(
              id: 'next-transaction-link',
            );
            await syncService.runInTransaction(() async {
              await syncService.upsertLink(nextLink);
            });
            final nextMessage = SyncMessage.agentLink(
              agentLink: nextLink.copyWith(vectorClock: testClock),
              status: SyncEntryStatus.update,
            );
            expect(attempted, [...expected, nextMessage]);
            expect(accepted, [...expectedAccepted, nextMessage]);
          },
        );
      }
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
      'state row with null head + no prior messages: backfill is reached but '
      'returns null — root append, no edges',
      () async {
        // The edge between "first message is a root" and "no state row":
        // here the state row exists with an unset head, so the append DOES
        // enter the legacy backfill branch and queries the prefix — but it is
        // empty, so _backfillMessageChain returns null, writing no msgprev
        // edges. The message lands as a root and the head advances.
        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => makeTestState(agentId: 'agent-1'));
        when(
          () => mockRepository.getAgentMessages('agent-1'),
        ).thenAnswer((_) async => <AgentMessageEntity>[]);

        await syncService.upsertEntity(newMessage());

        // Backfill was attempted (distinguishes this from the no-state-row
        // path, which skips the prefix scan entirely).
        verify(() => mockRepository.getAgentMessages('agent-1')).called(1);
        // Empty prefix ⇒ no chain edges written at all.
        verifyNever(() => mockRepository.upsertLink(any()));

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
      },
    );

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
      glados.ExploreConfig(numRuns: 160),
    ).test('emits a system marker preserving milestone, runKey and createdAt, '
        'defaulting threadId to the marker id', (scenario) async {
      // Fresh wiring per run so captures don't accumulate across iterations.
      final repository = MockAgentRepository();
      when(
        () => repository.getLinkByIdIncludingDeleted(any()),
      ).thenAnswer((_) async => null);
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
          payload: any(named: 'payload'),
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
      glados.ExploreConfig(numRuns: 160),
    ).test('a local write keeps the persisted head and the other caller '
        'fields, for any head combination', (scenario) async {
      // Fresh wiring per run so captures don't accumulate across iterations.
      final repository = MockAgentRepository();
      when(
        () => repository.getLinkByIdIncludingDeleted(any()),
      ).thenAnswer((_) async => null);
      final upserted = <AgentDomainEntity>[];
      when(() => repository.upsertEntity(any())).thenAnswer((invocation) async {
        upserted.add(
          invocation.positionalArguments.single as AgentDomainEntity,
        );
      });
      AgentStateEntity? persisted() => scenario.persistedStateExists
          ? makeTestState(
              agentId: 'agent-1',
            ).copyWith(recentHeadMessageId: scenario.persistedHead)
          : null;
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => persisted());
      when(
        () => repository.getEntity(any()),
      ).thenAnswer((_) async => persisted());
      final outboxService = MockOutboxService();
      when(() => outboxService.enqueueMessage(any())).thenAnswer((_) async {});
      final vectorClockService = MockVectorClockService();
      when(
        () => vectorClockService.getNextVectorClock(
          previous: any(named: 'previous'),
          payload: any(named: 'payload'),
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

    test(
      'falls back to the cached row (and logs) when the reconcile fold throws '
      'on a corrupt log — a malformed peer log must not abort the wake',
      () async {
        // Capture the error log so we can assert the fall-back path logged it.
        final logger = MockDomainLogger();
        getIt
          ..unregister<DomainLogger>()
          ..registerSingleton<DomainLogger>(logger);

        final cache = makeTestState(
          agentId: 'agent-1',
          lastWakeAt: DateTime(2024, 3, 5),
        );
        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => cache);
        // A corrupt log: two distinct `system` markers share one id (different
        // vector clocks make them unequal events), so the kernel's
        // canonicalOrder throws DuplicateEventIdException inside the fold.
        when(
          () => mockRepository.getMessagesByKind(
            'agent-1',
            AgentMessageKind.system,
          ),
        ).thenAnswer(
          (_) async => [
            makeTestMessage(
              id: 'dup',
              agentId: 'agent-1',
              kind: AgentMessageKind.system,
              createdAt: DateTime(2024, 3, 6),
              vectorClock: const VectorClock({'a': 1}),
              metadata: const AgentMessageMetadata(
                milestone: AgentMilestone.wakeCompleted,
              ),
            ),
            makeTestMessage(
              id: 'dup',
              agentId: 'agent-1',
              kind: AgentMessageKind.system,
              createdAt: DateTime(2024, 3, 7),
              vectorClock: const VectorClock({'b': 1}),
              metadata: const AgentMessageMetadata(
                milestone: AgentMilestone.wakeCompleted,
              ),
            ),
          ],
        );

        // Must NOT rethrow: the malformed log falls back to the cached row.
        final result = await syncService.reconciledAgentState('agent-1');

        expect(result, same(cache));
        // No heal is persisted on the fall-back path.
        verifyNever(() => mockRepository.upsertEntity(any()));
        // The divergence is logged under the reconcile sub-domain.
        verify(
          () => logger.error(
            LogDomain.sync,
            any<Object>(),
            stackTrace: any(named: 'stackTrace'),
            subDomain: 'agentSync.reconcile',
            message: any(
              named: 'message',
              that: contains('reconcile fold failed for agent-1'),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('AgentSyncService.appendJoin', () {
    // ── write behaviour (mock repository) ────────────────────────────────────

    test(
      'writes the join node, an edge per parent, and advances the head',
      () async {
        when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
          (_) async => makeTestState(
            agentId: 'agent-1',
          ).copyWith(recentHeadMessageId: 'a'),
        );
        final joinId = computeJoinId(['a', 'b']);

        await syncService.appendJoin(
          agentId: 'agent-1',
          joinId: joinId,
          parentIds: ['b', 'a'], // unsorted on purpose
          at: DateTime(2024, 3, 15),
        );

        final upserted = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        final joinMsg = upserted.whereType<AgentMessageEntity>().single;
        expect(joinMsg.id, joinId);
        expect(joinMsg.threadId, joinId);
        expect(joinMsg.kind, AgentMessageKind.system);
        expect(joinMsg.metadata, const AgentMessageMetadata());
        expect(
          upserted.whereType<AgentStateEntity>().single.recentHeadMessageId,
          joinId,
        );
        final edges = verify(
          () => mockRepository.upsertLink(captureAny()),
        ).captured.cast<AgentLink>().whereType<MessagePrevLink>().toList();
        expect(edges.map((l) => l.id).toSet(), {
          'msgprev-$joinId-a',
          'msgprev-$joinId-b',
        });
        expect(edges.every((l) => l.fromId == joinId), isTrue);
        expect(edges.map((l) => l.toId).toSet(), {'a', 'b'});
      },
    );

    test(
      'does not rewrite the join node when it already exists (idempotent)',
      () async {
        final joinId = computeJoinId(['a', 'b']);
        when(() => mockRepository.getEntity(joinId)).thenAnswer(
          (_) async => makeTestMessage(
            id: joinId,
            agentId: 'agent-1',
            kind: AgentMessageKind.system,
          ),
        );
        when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
          (_) async => makeTestState(
            agentId: 'agent-1',
          ).copyWith(recentHeadMessageId: joinId),
        );

        await syncService.appendJoin(
          agentId: 'agent-1',
          joinId: joinId,
          parentIds: ['a', 'b'],
          at: DateTime(2024, 3, 15),
        );

        // Node present + head already at the join ⇒ no entity write at all, but
        // the edges are re-asserted (idempotent by id).
        verifyNever(() => mockRepository.upsertEntity(any()));
        verify(() => mockRepository.upsertLink(any())).called(2);
      },
    );

    test(
      'advances a stale head even when the join node already exists',
      () async {
        // The peer's identical join synced in (node present) but this device's
        // head pointer still sits on a now-joined parent — left there, the next
        // local append would immediately re-fork, so the head must advance.
        final joinId = computeJoinId(['a', 'b']);
        when(() => mockRepository.getEntity(joinId)).thenAnswer(
          (_) async => makeTestMessage(
            id: joinId,
            agentId: 'agent-1',
            kind: AgentMessageKind.system,
          ),
        );
        when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
          (_) async => makeTestState(
            agentId: 'agent-1',
          ).copyWith(recentHeadMessageId: 'a'),
        );

        await syncService.appendJoin(
          agentId: 'agent-1',
          joinId: joinId,
          parentIds: ['a', 'b'],
          at: DateTime(2024, 3, 15),
        );

        final upserted = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        expect(upserted.whereType<AgentMessageEntity>(), isEmpty); // node kept
        expect(
          upserted.whereType<AgentStateEntity>().single.recentHeadMessageId,
          joinId,
        );
      },
    );

    test(
      'does not regress the head when it has moved past the joined parents',
      () async {
        // Models a timed-out heal whose appendJoin completes *after* the
        // executor already advanced the head past the fork: collapsing back to
        // the join would orphan that progress, so the head is left alone.
        final joinId = computeJoinId(['a', 'b']);
        when(() => mockRepository.getAgentState('agent-1')).thenAnswer(
          (_) async => makeTestState(
            agentId: 'agent-1',
          ).copyWith(recentHeadMessageId: 'w-latest'), // moved past a/b
        );

        await syncService.appendJoin(
          agentId: 'agent-1',
          joinId: joinId,
          parentIds: ['a', 'b'],
          at: DateTime(2024, 3, 15),
        );

        final upserted = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        // The join node + edges are still recorded (the residual fork heals on
        // the next wake), but the head is NOT regressed onto the join.
        expect(upserted.whereType<AgentMessageEntity>().single.id, joinId);
        expect(upserted.whereType<AgentStateEntity>(), isEmpty);
        verify(() => mockRepository.upsertLink(any())).called(2);
      },
    );

    test(
      'with no state row, writes node and edges but advances no head',
      () async {
        final joinId = computeJoinId(['a', 'b']);
        // Default getAgentState ⇒ null.
        await syncService.appendJoin(
          agentId: 'agent-1',
          joinId: joinId,
          parentIds: ['a', 'b'],
          at: DateTime(2024, 3, 15),
        );

        final upserted = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured.cast<AgentDomainEntity>();
        expect(upserted.whereType<AgentMessageEntity>().single.id, joinId);
        expect(upserted.whereType<AgentStateEntity>(), isEmpty);
        verify(() => mockRepository.upsertLink(any())).called(2);
      },
    );

    test(
      'ignores a degenerate call with fewer than two distinct parents',
      () async {
        await syncService.appendJoin(
          agentId: 'agent-1',
          joinId: 'x',
          parentIds: ['a', 'a'], // collapses to one head
          at: DateTime(2024, 3, 15),
        );
        verifyNever(() => mockRepository.upsertEntity(any()));
        verifyNever(() => mockRepository.upsertLink(any()));
      },
    );

    // ── DAG convergence (real projection over an in-memory log) ───────────────
    // Bench, fork seeding, and head computation come from `fork_test_support`.

    test('heals a two-head fork to a single head (real projection)', () async {
      final b = makeForkBench();
      await seedForkInto(b.repo, head: 'b');
      expect(headsOfLog(b.repo.messages, b.repo.links).toSet(), {'a', 'b'});

      final joinId = computeJoinId(['a', 'b']);
      await b.service.appendJoin(
        agentId: 'agent-1',
        joinId: joinId,
        parentIds: ['a', 'b'],
        at: DateTime(2024, 2),
      );

      // The fork collapses: a, b are now the join's parents ⇒ the join is the
      // sole head, and this device's head pointer follows.
      expect(headsOfLog(b.repo.messages, b.repo.links), [joinId]);
      final state = await b.repo.getAgentState('agent-1');
      expect(state!.recentHeadMessageId, joinId);
    });

    test(
      'two devices emitting the same join converge to one node + head',
      () async {
        final a = makeForkBench();
        final c = makeForkBench();
        await seedForkInto(a.repo, head: 'a'); // device A extended branch a
        await seedForkInto(c.repo, head: 'b'); // device C extended branch b
        final joinId = computeJoinId(['a', 'b']);
        for (final dev in [a, c]) {
          await dev.service.appendJoin(
            agentId: 'agent-1',
            joinId: joinId,
            parentIds: ['a', 'b'],
            at: DateTime(2024, 2),
          );
        }

        // Set-union the two devices' logs, deduping by id — models the DB
        // (insertOnConflictUpdate). AgentEvent equality includes the per-device
        // envelope, so an *un-deduped* union would trip DuplicateEventIdException;
        // the dedupe is exactly what makes the content-addressed join converge.
        final messages = <String, AgentMessageEntity>{
          for (final m in [...a.repo.messages, ...c.repo.messages]) m.id: m,
        };
        final links = <String, AgentLink>{
          for (final l in [...a.repo.links, ...c.repo.links]) l.id: l,
        };

        expect(messages[joinId], isNotNull); // exactly one join node (by id)
        expect(
          links.values
              .whereType<MessagePrevLink>()
              .where((l) => l.fromId == joinId)
              .length,
          2, // exactly two join edges — no storm
        );
        expect(headsOfLog(messages.values, links.values), [joinId]);
      },
    );

    test(
      'completes the edge set + head on a retry after a partial commit',
      () async {
        // appendJoin commits node + edges + head atomically, so a true partial
        // commit can't occur — but a re-run must still be self-completing. Seed a
        // fork plus *only* the join node (no edges, head still on a parent), then
        // run appendJoin: the edges and the head advance are (re-)asserted.
        final b = makeForkBench();
        await seedForkInto(b.repo, head: 'a');
        final joinId = computeJoinId(['a', 'b']);
        b.repo.seed([
          makeTestMessage(
            id: joinId,
            agentId: 'agent-1',
            kind: AgentMessageKind.system,
          ),
        ]);
        // The parentless join node is itself a third head until its edges land.
        expect(headsOfLog(b.repo.messages, b.repo.links).toSet(), {
          'a',
          'b',
          joinId,
        });

        await b.service.appendJoin(
          agentId: 'agent-1',
          joinId: joinId,
          parentIds: ['a', 'b'],
          at: DateTime(2024, 2),
        );

        expect(
          b.repo.links
              .whereType<MessagePrevLink>()
              .where((l) => l.fromId == joinId)
              .map((l) => l.toId)
              .toSet(),
          {'a', 'b'},
        );
        expect(
          (await b.repo.getAgentState('agent-1'))!.recentHeadMessageId,
          joinId,
        );
        expect(headsOfLog(b.repo.messages, b.repo.links), [joinId]);
      },
    );
  });

  // ADR 0076, specs/tla/AgentMessageLog.tla (AppendsOffTips): the head pointer
  // is a field of the synced state row, so it can trail the messages that
  // synced in. An append used to chain off it although this device already
  // held its successor, forking the log.
  group('AgentSyncService.upsertEntity — a trailing head', () {
    AgentLink edge(String child, String parent) => AgentLink.messagePrev(
      id: 'msgprev-$child',
      fromId: child,
      toId: parent,
      createdAt: DateTime(2024, 3),
      updatedAt: DateTime(2024, 3),
      vectorClock: null,
    );

    test('an append chains off the tip past a head whose successors synced '
        'in ahead of the state row (TLC: AppendsOffTips)', () async {
      // The trace: the other device appended a1, a2; this device received
      // both messages and edges but only the state version naming a1.
      final bench = makeForkBench();
      bench.repo.seed([
        makeTestState(agentId: 'agent-1').copyWith(recentHeadMessageId: 'a1'),
        makeTestMessage(
          id: 'a1',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 2),
        ),
        makeTestMessage(
          id: 'a2',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 3),
          prevMessageId: 'a1',
        ),
      ]);
      await bench.repo.upsertLink(edge('a2', 'a1'));

      await bench.service.upsertEntity(
        makeTestMessage(
          id: 'b1',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 4),
        ),
      );

      expect(
        ((await bench.repo.getEntity('b1'))! as AgentMessageEntity)
            .prevMessageId,
        'a2',
      );
      expect((await bench.repo.getLinkById('msgprev-b1'))!.toId, 'a2');
      expect(headsOfLog(bench.repo.messages, bench.repo.links), ['b1']);
      expect(
        (await bench.repo.getAgentState('agent-1'))!.recentHeadMessageId,
        'b1',
      );
    });

    test('a head that is still the tip is chained off as it is', () async {
      final bench = makeForkBench();
      bench.repo.seed([
        makeTestState(agentId: 'agent-1').copyWith(recentHeadMessageId: 'a1'),
        makeTestMessage(
          id: 'a1',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 2),
        ),
      ]);

      await bench.service.upsertEntity(
        makeTestMessage(
          id: 'b1',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 4),
        ),
      );

      expect((await bench.repo.getLinkById('msgprev-b1'))!.toId, 'a1');
    });
  });

  // ADR 0071, specs/tla/AgentMessageLog.tla (AgentMessageLogStale): the head
  // pointer is a field of the last-writer-wins state row, so a synced version
  // written before its device saw any head can clear it on a device whose log
  // is already chained. The next append used to re-run the legacy spine over
  // that log, rewriting `msgprev-<id>` edges an append wrote.
  group('AgentSyncService.upsertEntity — head recovery', () {
    AgentLink edge(String child, String parent, {String? id}) =>
        AgentLink.messagePrev(
          id: id ?? 'msgprev-$child',
          fromId: child,
          toId: parent,
          createdAt: DateTime(2024, 3),
          updatedAt: DateTime(2024, 3),
          vectorClock: null,
        );

    AgentMessageEntity append(String id, {DateTime? at}) => makeTestMessage(
      id: id,
      agentId: 'agent-1',
      createdAt: at ?? DateTime(2024, 3, 20),
    );

    test('a cleared head over a chained log recovers the projected head and '
        'rewrites no edge (TLC: Acyclic)', () async {
      // The trace: b1 from the device whose clock runs ahead (createdAt
      // 03-10), a1 chained off it on this device (createdAt 03-05), then a
      // state version without a head wins last-writer-wins here.
      final bench = makeForkBench();
      bench.repo.seed([
        makeTestState(agentId: 'agent-1'),
        makeTestMessage(
          id: 'b1',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 10),
        ),
        makeTestMessage(
          id: 'a1',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 5),
          prevMessageId: 'b1',
        ),
      ]);
      await bench.repo.upsertLink(edge('a1', 'b1'));

      await bench.service.upsertEntity(append('a2'));

      // The spine would have written msgprev-b1 → a1, closing a1 ⇄ b1.
      expect(await bench.repo.getLinkById('msgprev-b1'), isNull);
      final a2 = await bench.repo.getEntity('a2');
      expect((a2! as AgentMessageEntity).prevMessageId, 'a1');
      expect(
        (await bench.repo.getLinkById('msgprev-a2'))!.toId,
        'a1',
      );
      expect(headsOfLog(bench.repo.messages, bench.repo.links), ['a2']);
      expect(
        (await bench.repo.getAgentState('agent-1'))!.recentHeadMessageId,
        'a2',
      );
    });

    test('a log holding only a join row and roots is not legacy: no spine '
        'edge is written', () async {
      // A join whose edges have not synced yet is DAG evidence too; chaining
      // the join into a createdAt spine would contradict its own edges.
      final joinId = computeJoinId(['r1', 'r2']);
      final bench = makeForkBench();
      bench.repo.seed([
        makeTestState(agentId: 'agent-1'),
        makeTestMessage(
          id: 'r1',
          agentId: 'agent-1',
          createdAt: DateTime(2024, 3, 2),
        ),
        makeTestMessage(
          id: joinId,
          agentId: 'agent-1',
          kind: AgentMessageKind.system,
          createdAt: DateTime(2024, 3),
        ),
      ]);

      await bench.service.upsertEntity(append('m1'));

      expect(
        bench.repo.links.map((l) => l.id),
        ['msgprev-m1'],
        reason: 'only the new message is chained',
      );
      // Both rows are heads; the canonical order's last one is taken.
      expect((await bench.repo.getLinkById('msgprev-m1'))!.toId, joinId);
    });

    test(
      'does not chain off a parent whose child synced ahead of its edge',
      () async {
        // `a-child` names `z-parent` but its edge has not arrived, so both
        // project as heads and `z-parent` sorts last. Chaining off it would
        // fork the log the moment the edge lands.
        final bench = makeForkBench();
        bench.repo.seed([
          makeTestState(agentId: 'agent-1'),
          makeTestMessage(id: 'z-parent', agentId: 'agent-1'),
          makeTestMessage(
            id: 'a-child',
            agentId: 'agent-1',
            prevMessageId: 'z-parent',
          ),
        ]);
        expect(headsOfLog(bench.repo.messages, bench.repo.links), [
          'a-child',
          'z-parent',
        ]);

        await bench.service.upsertEntity(append('m1'));

        expect((await bench.repo.getLinkById('msgprev-m1'))!.toId, 'a-child');
        await bench.repo.upsertLink(edge('a-child', 'z-parent'));
        expect(headsOfLog(bench.repo.messages, bench.repo.links), ['m1']);
      },
    );

    test(
      'falls back to the last head when every head is named as a parent',
      () async {
        // Two rows naming each other with no edge synced: no head qualifies
        // as a tip, so the canonical last head is taken.
        final bench = makeForkBench();
        bench.repo.seed([
          makeTestState(agentId: 'agent-1'),
          makeTestMessage(id: 'x', agentId: 'agent-1', prevMessageId: 'y'),
          makeTestMessage(id: 'y', agentId: 'agent-1', prevMessageId: 'x'),
        ]);

        await bench.service.upsertEntity(append('m1'));

        expect((await bench.repo.getLinkById('msgprev-m1'))!.toId, 'y');
      },
    );

    test('a corrupt log starts the message as a root and logs', () async {
      final logger = MockDomainLogger();
      getIt
        ..unregister<DomainLogger>()
        ..registerSingleton<DomainLogger>(logger);
      final bench = makeForkBench();
      bench.repo.seed([
        makeTestState(agentId: 'agent-1'),
        makeTestMessage(id: 'x', agentId: 'agent-1', prevMessageId: 'y'),
        makeTestMessage(id: 'y', agentId: 'agent-1', prevMessageId: 'x'),
      ]);
      await bench.repo.upsertLink(edge('x', 'y'));
      await bench.repo.upsertLink(edge('y', 'x'));

      await bench.service.upsertEntity(append('m1'));

      expect(await bench.repo.getLinkById('msgprev-m1'), isNull);
      expect(
        ((await bench.repo.getEntity('m1'))! as AgentMessageEntity)
            .prevMessageId,
        isNull,
      );
      expect(
        (await bench.repo.getAgentState('agent-1'))!.recentHeadMessageId,
        'm1',
      );
      verify(
        () => logger.error(
          any(),
          any(),
          message: any(named: 'message'),
          subDomain: 'agentSync.recoverHead',
          stackTrace: any(named: 'stackTrace'),
        ),
      ).called(1);
    });
  });

  group('AgentSyncService.upsertEntity — removals and re-creations succeed '
      'the stored version (AgentReplication.tla, the removal kind)', () {
    final at = DateTime(2026, 9, 25, 9);
    final planId = makeTestDayPlan().id;
    final itemId = makeTestParsedItem().id;
    late AgentTestDevice a;
    late AgentTestDevice b;

    setUp(() {
      a = AgentTestDevice('host-a');
      b = AgentTestDevice('host-b');
      addTearDown(a.close);
      addTearDown(b.close);
    });

    test(
      "a day plan drafted afresh over a peer's later-stamped removal is live "
      'on both devices (TLC: WriteSeesTombstones, RecreateKeepsFields)',
      () async {
        // A drafts the plan, and B, whose clock runs ahead, deletes it. A's
        // planner drafts the day again: `getEntity` reads no row, so the plan
        // is built afresh. The write path read the stored row the same way,
        // so the redraft held A's counter alone — concurrent with the
        // removal, which its later stamp made win on B while A kept the
        // plan. Resolved against the removal as if concurrent, A handed
        // itself the removal back.
        await a.sync.upsertEntity(makeTestDayPlan(updatedAt: at));
        await b.receiveEntity(a.sentEntities.last);
        final onB = (await b.repository.getEntity(planId))! as DayPlanEntity;
        final removedAt = at.add(const Duration(minutes: 70));
        await b.sync.upsertEntity(
          onB.copyWith(deletedAt: removedAt, updatedAt: removedAt),
        );
        await a.receiveEntity(b.sentEntities.last);
        expect(await a.repository.getEntity(planId), isNull);

        await a.sync.upsertEntity(
          makeTestDayPlan(
            capacityMinutes: 300,
            updatedAt: at.add(const Duration(minutes: 65)),
          ),
        );
        await b.receiveEntity(a.sentEntities.last);

        for (final device in [a, b]) {
          final stored =
              (await device.repository.getEntityIncludingDeleted(planId))!
                  as DayPlanEntity;
          expect(stored.deletedAt, isNull, reason: device.host);
          expect(stored.capacityMinutes, 300, reason: device.host);
          // It sorts after the removal it replaced.
          expect(stored.updatedAt, removedAt, reason: device.host);
        }
        expect(
          VectorClock.compare(
            a.sentEntities.last.vectorClock!,
            b.sentEntities.last.vectorClock!,
          ),
          VclockStatus.a_gt_b,
        );
      },
    );

    test(
      "a removal built on a snapshot from before a peer's edit succeeds "
      'that edit, append-only variants included',
      () async {
        // A re-parse reads the old parsed items, then removes them. B linked
        // one of them to a task meanwhile, and A received it. A parsed item
        // is append-only, and such writes were stamped on the clock they were
        // built on: the removal was concurrent with the edit it overwrote.
        await a.sync.upsertEntity(makeTestParsedItem(createdAt: at));
        await b.receiveEntity(a.sentEntities.last);
        final snapshot = (await a.repository.getEntity(itemId))!;
        final onB = (await b.repository.getEntity(itemId))! as ParsedItemEntity;
        await b.sync.upsertEntity(onB.copyWith(matchedTaskId: 'task-1'));
        await a.receiveEntity(b.sentEntities.last);

        await a.sync.upsertEntity(
          snapshot.copyWith(deletedAt: at.add(const Duration(hours: 1))),
        );
        await b.receiveEntity(a.sentEntities.last);

        expect(
          VectorClock.compare(
            a.sentEntities.last.vectorClock!,
            b.sentEntities.last.vectorClock!,
          ),
          VclockStatus.a_gt_b,
        );
        for (final device in [a, b]) {
          expect(
            (await device.repository.getEntityIncludingDeleted(
              itemId,
            ))!.deletedAt,
            at.add(const Duration(hours: 1)),
            reason: device.host,
          );
        }
      },
    );

    test(
      "removing an unparsed capture built on a snapshot succeeds a peer's edit "
      'that synced in meanwhile (ADR 0081, addendum)',
      () async {
        // An unparsed capture takes the capture-normalizing write path, which
        // stamped a removal on the snapshot's clock alone: concurrent with the
        // edit it overwrote.
        final capture = makeTestCapture();
        expect(capture.dayId, isEmpty);
        expect(capture.parseCompletedAt, isNull);
        await a.sync.upsertEntity(capture);
        await b.receiveEntity(a.sentEntities.last);
        final snapshot =
            (await a.repository.getEntity(capture.id))! as CaptureEntity;
        final onB =
            (await b.repository.getEntity(capture.id))! as CaptureEntity;
        await b.sync.upsertEntity(onB.copyWith(transcript: 'Edited on B'));
        await a.receiveEntity(b.sentEntities.last);

        final removedAt = DateTime(2026, 9, 25, 10);
        await a.sync.upsertEntity(snapshot.copyWith(deletedAt: removedAt));
        await b.receiveEntity(a.sentEntities.last);

        expect(
          VectorClock.compare(
            a.sentEntities.last.vectorClock!,
            b.sentEntities.last.vectorClock!,
          ),
          VclockStatus.a_gt_b,
        );
        for (final device in [a, b]) {
          expect(
            (await device.repository.getEntityIncludingDeleted(
              capture.id,
            ))!.deletedAt,
            removedAt,
            reason: device.host,
          );
        }
      },
    );
  });

  group('AgentSyncService.upsertLink — a write succeeds the stored version '
      '(AgentLinks.tla, ADR 0081)', () {
    const id = 'parsed_item_to_task:item:task';
    final at = DateTime(2026, 9, 24, 9);
    late AgentTestDevice a;
    late AgentTestDevice b;

    setUp(() {
      a = AgentTestDevice('host-a');
      b = AgentTestDevice('host-b');
      addTearDown(a.close);
      addTearDown(b.close);
    });

    /// `linkCaptureItem`: the link built afresh under its reused id.
    AgentLink fresh({DateTime? updatedAt}) => AgentLink.parsedItemToTask(
      id: id,
      fromId: 'item',
      toId: 'task',
      createdAt: at,
      updatedAt: updatedAt ?? at,
      vectorClock: null,
    );

    test(
      "a link written afresh over a peer's removal is the newer version on "
      'both devices (TLC: Converged, WriteSucceedsRow)',
      () async {
        // The trace: B links, A removes the link, B links it again. Built
        // without a clock, the relink held only B's counter: concurrent with
        // A's removal, which the canonical clock order preferred — A kept the
        // removal and B the link, for good.
        await b.sync.upsertLink(fresh());
        await a.receiveLink(b.sentLinks.last);
        final live = (await a.repository.getLinkById(id))!;
        await a.sync.upsertLink(live.softDeleted(at));
        await b.receiveLink(a.sentLinks.last);
        await b.sync.upsertLink(fresh());
        await a.receiveLink(b.sentLinks.last);

        for (final device in [a, b]) {
          final stored = await device.repository.getLinkByIdIncludingDeleted(
            id,
          );
          expect(stored!.deletedAt, isNull, reason: device.host);
        }
        expect(
          VectorClock.compare(
            b.sentLinks.last.vectorClock!,
            a.sentLinks.last.vectorClock!,
          ),
          VclockStatus.a_gt_b,
        );
      },
    );

    for (final firstCounter in [0, firstVectorClockCounter]) {
      test(
        "a host's first relink and first removal over a synced link win on "
        'every replica (first counter $firstCounter, ADR 0080)',
        () async {
          // A host an older build created starts at counter 0. Its first
          // write extends the stored clock by `host: 0`, which a compare
          // reading an absent host as 0 took for the stored version itself:
          // every receiver kept the predecessor.
          final c = AgentTestDevice('host-c', firstCounter: firstCounter);
          addTearDown(c.close);
          Future<void> expectEverywhere({required bool live}) async {
            for (final device in [a, b, c]) {
              final stored = await device.repository
                  .getLinkByIdIncludingDeleted(id);
              expect(
                stored!.deletedAt == null,
                live,
                reason: '${device.host} holds $stored',
              );
            }
          }

          // A removes the link B made; C holds both versions.
          await b.sync.upsertLink(fresh());
          await a.receiveLink(b.sentLinks.last);
          await c.receiveLink(b.sentLinks.last);
          final live = (await a.repository.getLinkById(id))!;
          await a.sync.upsertLink(live.softDeleted(at));
          await b.receiveLink(a.sentLinks.last);
          await c.receiveLink(a.sentLinks.last);

          // C's first write: the relink.
          await c.sync.upsertLink(fresh());
          await a.receiveLink(c.sentLinks.last);
          await b.receiveLink(c.sentLinks.last);
          await expectEverywhere(live: true);

          // And C's removal of it.
          final relinked = (await c.repository.getLinkById(id))!;
          await c.sync.upsertLink(relinked.softDeleted(at));
          await a.receiveLink(c.sentLinks.last);
          await b.receiveLink(c.sentLinks.last);
          await expectEverywhere(live: false);
        },
      );
    }

    test(
      "a write stamped before the version it replaces keeps that version's "
      'updatedAt (TLC: ClampTimestamp)',
      () async {
        final later = at.add(const Duration(minutes: 5));
        await a.sync.upsertLink(fresh(updatedAt: later));
        final live = (await a.repository.getLinkById(id))!;

        await a.sync.upsertLink(live.softDeleted(at));

        final stored = (await a.repository.getLinkByIdIncludingDeleted(id))!;
        expect(stored.deletedAt, at);
        expect(stored.updatedAt, later);
        expect(a.sentLinks.last.updatedAt, later);
      },
    );
  });
}
