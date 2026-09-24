import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/goal_trigger_tokens.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/sync/agent_concurrent_resolver.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  AgentIdentityEntity goalIdentity(AgentLifecycle lifecycle) =>
      AgentDomainEntity.agent(
            id: 'goal-1',
            agentId: 'goal-1',
            kind: AgentKinds.goalAgent,
            displayName: 'Goal',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: 'goal-1:state',
            config: const AgentConfig(),
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
            vectorClock: null,
          )
          as AgentIdentityEntity;

  late MockAgentSyncService syncService;
  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late StreamController<WakeRunCompletion> completions;
  late List<AgentDomainEntity> upserts;
  late GoalChatService service;
  late MockUpdateNotifications notifications;

  setUp(() {
    syncService = MockAgentSyncService();
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
    completions = StreamController<WakeRunCompletion>.broadcast();
    addTearDown(completions.close);
    upserts = [];
    when(
      () => orchestrator.runCompletions,
    ).thenAnswer((_) => completions.stream);
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      upserts.add(invocation.positionalArguments.first as AgentDomainEntity);
    });
    when(() => repository.getEntity(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      return id == 'goal-1' ? goalIdentity(AgentLifecycle.active) : null;
    });
    notifications = MockUpdateNotifications();
    service = GoalChatService(
      repository: repository,
      syncService: syncService,
      orchestrator: orchestrator,
      notifications: notifications,
    );
  });

  test('does not persist a turn for an inactive goal agent', () async {
    when(
      () => repository.getEntity('goal-1'),
    ).thenAnswer((_) async => goalIdentity(AgentLifecycle.dormant));

    await expectLater(
      service.sendMessage(agentId: 'goal-1', text: 'Can you hear me?'),
      throwsA(
        isA<GoalChatTurnException>()
            .having((error) => error.messageId, 'messageId', isNull)
            .having(
              (error) => error.detail,
              'detail',
              'goal agent is not active',
            ),
      ),
    );
    expect(upserts, isEmpty);
    verifyNever(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        supersede: any(named: 'supersede'),
        initiator: any(named: 'initiator'),
      ),
    );
  });

  // The user's own words appeared only once the reply was written: the
  // chat refreshes on the agent's notifications, and only the wake sent one.
  test('announces the stored turn before the wake runs, so the user sees '
      'their own words at once', () async {
    final events = <String>[];
    when(() => notifications.notifyUiOnly(any())).thenAnswer((invocation) {
      events.add(
        'notify ${invocation.positionalArguments.first as Set<String>} '
        'after ${upserts.length} writes',
      );
    });
    when(
      () => orchestrator.enqueueManualWake(
        agentId: 'goal-1',
        reason: WakeReason.userMessage.name,
        triggerTokens: any(named: 'triggerTokens'),
        supersede: false,
        initiator: WakeInitiator.user,
      ),
    ).thenAnswer((_) {
      events.add('wake');
      scheduleMicrotask(
        () => completions.add(
          const WakeRunCompletion(
            runKey: 'chat-run',
            status: WakeRunStatus.completed,
          ),
        ),
      );
      return 'chat-run';
    });

    await service.sendMessage(agentId: 'goal-1', text: 'How am I doing?');

    expect(events, [
      'notify {goal-1, $agentNotification} after 2 writes',
      'wake',
    ]);
  });

  test(
    'persists the source turn before enqueuing a user-message wake',
    () async {
      when(
        () => orchestrator.enqueueManualWake(
          agentId: 'goal-1',
          reason: WakeReason.userMessage.name,
          triggerTokens: any(named: 'triggerTokens'),
          supersede: false,
          initiator: WakeInitiator.user,
        ),
      ).thenAnswer((_) {
        scheduleMicrotask(
          () => completions.add(
            const WakeRunCompletion(
              runKey: 'chat-run',
              status: WakeRunStatus.completed,
            ),
          ),
        );
        return 'chat-run';
      });

      await service.sendMessage(agentId: 'goal-1', text: '  How am I doing?  ');

      final payload = upserts.first as AgentMessagePayloadEntity;
      final message = upserts.whereType<AgentMessageEntity>().single;
      expect(upserts.indexOf(message), 1);
      expect(payload.content['text'], 'How am I doing?');
      expect(message.kind, AgentMessageKind.user);
      expect(message.contentEntryId, payload.id);
      final tokens =
          verify(
                () => orchestrator.enqueueManualWake(
                  agentId: 'goal-1',
                  reason: WakeReason.userMessage.name,
                  triggerTokens: captureAny(named: 'triggerTokens'),
                  supersede: false,
                  initiator: WakeInitiator.user,
                ),
              ).captured.single
              as Set<String>;
      expect(goalChatMessageIdFromTriggerTokens(tokens), message.id);
    },
  );

  test('keeps the durable source turn when the wake fails', () async {
    when(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        supersede: any(named: 'supersede'),
        initiator: any(named: 'initiator'),
      ),
    ).thenAnswer((_) {
      scheduleMicrotask(
        () => completions.add(
          const WakeRunCompletion(
            runKey: 'failed-run',
            status: WakeRunStatus.failed,
            error: 'offline',
          ),
        ),
      );
      return 'failed-run';
    });

    await expectLater(
      service.sendMessage(agentId: 'goal-1', text: 'Try me'),
      throwsA(
        isA<GoalChatTurnException>().having(
          (error) => error.messageId,
          'durable message id',
          isNotNull,
        ),
      ),
    );
    expect(upserts.whereType<AgentMessageEntity>(), hasLength(1));
  });

  test(
    'continues a turn when the message committed before an outbox error',
    () async {
      AgentMessageEntity? committedMessage;
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.first as AgentDomainEntity;
        upserts.add(entity);
        if (entity is AgentMessageEntity) {
          committedMessage = entity;
          throw StateError('outbox flush failed');
        }
      });
      when(() => repository.getEntity(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        if (id == 'goal-1') {
          return goalIdentity(AgentLifecycle.active);
        }
        return committedMessage;
      });
      when(
        () => orchestrator.enqueueManualWake(
          agentId: 'goal-1',
          reason: WakeReason.userMessage.name,
          triggerTokens: any(named: 'triggerTokens'),
          supersede: false,
          initiator: WakeInitiator.user,
        ),
      ).thenAnswer((_) {
        scheduleMicrotask(
          () => completions.add(
            const WakeRunCompletion(
              runKey: 'reconciled-run',
              status: WakeRunStatus.completed,
            ),
          ),
        );
        return 'reconciled-run';
      });

      await service.sendMessage(agentId: 'goal-1', text: 'One durable turn');

      expect(upserts.whereType<AgentMessageEntity>(), hasLength(1));
      verify(() => repository.getEntity(committedMessage!.id)).called(1);
      verify(
        () => orchestrator.enqueueManualWake(
          agentId: 'goal-1',
          reason: WakeReason.userMessage.name,
          triggerTokens: any(named: 'triggerTokens'),
          supersede: false,
          initiator: WakeInitiator.user,
        ),
      ).called(1);
    },
  );

  test(
    'a cancelled queued wake completes its chat waiter as aborted',
    () async {
      final queue = WakeQueue();
      final runner = WakeRunner();
      await runner.tryAcquire('goal-1');
      addTearDown(() => runner.release('goal-1'));
      final realOrchestrator = WakeOrchestrator(
        repository: MockAgentRepository(),
        queue: queue,
        runner: runner,
      );
      addTearDown(realOrchestrator.stop);
      final waiting = GoalChatService(
        repository: repository,
        syncService: syncService,
        orchestrator: realOrchestrator,
        notifications: notifications,
      ).retryMessage(agentId: 'goal-1', messageId: 'message-1');
      await pumpEventQueue();
      expect(queue.length, 1);

      final removed = realOrchestrator.cancelPendingWakes(
        'goal-1',
        allWorkspaces: true,
      );

      expect(removed, hasLength(1));
      await expectLater(
        waiting,
        throwsA(
          isA<GoalChatTurnException>().having(
            (error) => error.messageId,
            'messageId',
            'message-1',
          ),
        ),
      );
    },
  );

  test('a superseding manual wake completes its queued chat waiter', () async {
    final queue = WakeQueue();
    final runner = WakeRunner();
    await runner.tryAcquire('goal-1');
    addTearDown(() => runner.release('goal-1'));
    final realOrchestrator = WakeOrchestrator(
      repository: MockAgentRepository(),
      queue: queue,
      runner: runner,
    );
    addTearDown(realOrchestrator.stop);
    final waiting = GoalChatService(
      repository: repository,
      syncService: syncService,
      orchestrator: realOrchestrator,
      notifications: notifications,
    ).retryMessage(agentId: 'goal-1', messageId: 'message-1');
    await pumpEventQueue();

    realOrchestrator.enqueueManualWake(
      agentId: 'goal-1',
      reason: 'replacement',
    );

    await expectLater(waiting, throwsA(isA<GoalChatTurnException>()));
    expect(queue.length, 1, reason: 'only the replacement remains queued');
  });

  test('retry reuses the existing durable source message', () async {
    when(
      () => orchestrator.enqueueManualWake(
        agentId: 'goal-1',
        reason: WakeReason.userMessage.name,
        triggerTokens: any(named: 'triggerTokens'),
        supersede: false,
        initiator: WakeInitiator.user,
      ),
    ).thenAnswer((_) {
      scheduleMicrotask(
        () => completions.add(
          const WakeRunCompletion(
            runKey: 'retry-run',
            status: WakeRunStatus.completed,
          ),
        ),
      );
      return 'retry-run';
    });

    await service.retryMessage(agentId: 'goal-1', messageId: 'message-1');

    expect(
      upserts,
      isEmpty,
      reason: 'retry must not duplicate the source turn',
    );
    final tokens =
        verify(
              () => orchestrator.enqueueManualWake(
                agentId: 'goal-1',
                reason: WakeReason.userMessage.name,
                triggerTokens: captureAny(named: 'triggerTokens'),
                supersede: false,
                initiator: WakeInitiator.user,
              ),
            ).captured.single
            as Set<String>;
    expect(goalChatMessageIdFromTriggerTokens(tokens), 'message-1');
  });

  // GoalChatReply.tla: recovery used to enqueue a wake for the oldest
  // unanswered message on every device that ran maintenance — at startup,
  // hourly and on identity sync — guarded by an in-memory set, so a peer
  // answered a message its author was still answering. Recovery now goes
  // through one lease-elected record per message.
  group('recovery (ADR 0069)', () {
    final now = DateTime(2026, 8, 18, 12);
    final recordId = goalChatRecoveryRecordId('goal-1', 'message-orphan');
    late Map<String, AgentDomainEntity> stored;

    final orphan =
        AgentDomainEntity.agentMessage(
              id: 'message-orphan',
              agentId: 'goal-1',
              threadId: 'message-orphan',
              kind: AgentMessageKind.user,
              createdAt: now,
              vectorClock: null,
              contentEntryId: 'payload-orphan',
              metadata: const AgentMessageMetadata(),
            )
            as AgentMessageEntity;

    ScheduledWakeEntity recovery({
      required ScheduledWakeStatus status,
      required DateTime scheduledAt,
      DateTime? leaseUntil,
    }) =>
        AgentDomainEntity.scheduledWake(
              id: recordId,
              agentId: 'goal-1',
              scheduledAt: scheduledAt,
              status: status,
              reason: WakeReason.userMessage.name,
              updatedAt: now,
              vectorClock: const VectorClock({'host-b': 4}),
              workspaceKey: goalChatRecoveryWorkspaceKey('message-orphan'),
              triggerTokens: const ['goal-chat-message:message-orphan'],
              leaseHostId: leaseUntil == null ? null : 'host-b',
              leaseUntil: leaseUntil,
            )
            as ScheduledWakeEntity;

    setUp(() {
      stored = {};
      // Writes land in `stored`, so a later read sees them.
      when(() => syncService.upsertEntity(any())).thenAnswer((inv) async {
        final entity = inv.positionalArguments.first as AgentDomainEntity;
        upserts.add(entity);
        stored[entity.id] = entity;
      });
      when(() => repository.getEntity(any())).thenAnswer((inv) async {
        final id = inv.positionalArguments.first as String;
        if (id == 'goal-1') return goalIdentity(AgentLifecycle.active);
        return stored[id];
      });
      when(
        () => repository.getMessagesByKind(
          'goal-1',
          AgentMessageKind.user,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => [orphan]);
      when(
        () => repository.getMessagesByKindAndToolName(
          'goal-1',
          AgentMessageKind.action,
          AgentConversationToolNames.replyToUser,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
    });

    ScheduledWakeEntity upsertedRecord() =>
        upserts.whereType<ScheduledWakeEntity>().single;

    void completeWakesWith(WakeRunStatus status) =>
        when(
          () => orchestrator.enqueueManualWake(
            agentId: 'goal-1',
            reason: WakeReason.userMessage.name,
            triggerTokens: any(named: 'triggerTokens'),
            supersede: false,
            initiator: WakeInitiator.user,
          ),
        ).thenAnswer((_) {
          scheduleMicrotask(
            () => completions.add(
              WakeRunCompletion(runKey: 'run', status: status),
            ),
          );
          return 'run';
        });

    test('a sent turn arms its recovery a grace out, before its wake, and '
        'the wake that answers it consumes it', () async {
      completeWakesWith(WakeRunStatus.completed);
      var recordsAtWake = 0;
      when(
        () => orchestrator.enqueueManualWake(
          agentId: 'goal-1',
          reason: WakeReason.userMessage.name,
          triggerTokens: any(named: 'triggerTokens'),
          supersede: false,
          initiator: WakeInitiator.user,
        ),
      ).thenAnswer((_) {
        recordsAtWake = upserts.whereType<ScheduledWakeEntity>().length;
        scheduleMicrotask(
          () => completions.add(
            const WakeRunCompletion(
              runKey: 'run',
              status: WakeRunStatus.completed,
            ),
          ),
        );
        return 'run';
      });

      await withClock(
        Clock.fixed(now),
        () => service.sendMessage(agentId: 'goal-1', text: 'How am I doing?'),
      );

      final message = upserts.whereType<AgentMessageEntity>().single;
      final records = upserts.whereType<ScheduledWakeEntity>().toList();
      expect(recordsAtWake, 1, reason: 'armed before the wake runs');
      final armed = records.first;
      expect(armed.id, goalChatRecoveryRecordId('goal-1', message.id));
      expect(armed.status, ScheduledWakeStatus.pending);
      expect(armed.scheduledAt, now.toUtc().add(goalChatRecoveryGrace));
      expect(armed.reason, WakeReason.userMessage.name);
      expect(armed.workspaceKey, goalChatRecoveryWorkspaceKey(message.id));
      expect(armed.triggerTokens, [goalChatMessageTriggerToken(message.id)]);
      expect(records.last.status, ScheduledWakeStatus.consumed);
      expect(records, hasLength(2));
    });

    test(
      'a recovery write that fails does not cost the turn its answer',
      () async {
        completeWakesWith(WakeRunStatus.completed);
        when(() => syncService.upsertEntity(any())).thenAnswer((inv) async {
          final entity = inv.positionalArguments.first as AgentDomainEntity;
          if (entity is ScheduledWakeEntity) {
            throw StateError('outbox flush failed');
          }
          upserts.add(entity);
          stored[entity.id] = entity;
        });

        await withClock(
          Clock.fixed(now),
          () => service.sendMessage(agentId: 'goal-1', text: 'Still answer me'),
        );

        final message = upserts.whereType<AgentMessageEntity>().single;
        final tokens =
            verify(
                  () => orchestrator.enqueueManualWake(
                    agentId: 'goal-1',
                    reason: WakeReason.userMessage.name,
                    triggerTokens: captureAny(named: 'triggerTokens'),
                    supersede: false,
                    initiator: WakeInitiator.user,
                  ),
                ).captured.single
                as Set<String>;
        expect(goalChatMessageIdFromTriggerTokens(tokens), message.id);
      },
    );

    test('over a tombstoned record, the new one carries its clock and so '
        'replaces it', () async {
      final tombstone = recovery(
        status: ScheduledWakeStatus.pending,
        scheduledAt: DateTime.utc(2026, 9),
      ).copyWith(deletedAt: DateTime(2026, 8, 18, 11));
      stored[recordId] = tombstone;

      expect(
        await withClock(
          Clock.fixed(now),
          () => service.restoreOldestPendingMessage('goal-1'),
        ),
        isTrue,
      );

      final written = upsertedRecord();
      expect(written.vectorClock, tombstone.vectorClock);
      // The local write path resolves it against the tombstone (ADR 0068):
      // it is the tombstone's successor, so the new record stands. From a
      // null clock the tombstone's later deadline would have kept it deleted.
      final persisted =
          resolveLocalAgentWrite(persisted: tombstone, write: written)
              as ScheduledWakeEntity;
      expect(persisted.deletedAt, isNull);
      expect(persisted.status, ScheduledWakeStatus.pending);
      expect(persisted.scheduledAt, now.toUtc().add(goalChatRecoveryGrace));
    });

    test('a failed wake leaves the recovery pending for the lease', () async {
      completeWakesWith(WakeRunStatus.failed);

      await expectLater(
        withClock(
          Clock.fixed(now),
          () => service.sendMessage(agentId: 'goal-1', text: 'Try me'),
        ),
        throwsA(isA<GoalChatTurnException>()),
      );

      expect(
        upserts.whereType<ScheduledWakeEntity>().single.status,
        ScheduledWakeStatus.pending,
      );
    });

    test('an unanswered turn without a record gets one, and no device '
        'enqueues a wake of its own', () async {
      final armed = await withClock(
        Clock.fixed(now),
        () => service.restoreOldestPendingMessage('goal-1'),
      );

      expect(armed, isTrue);
      final record = upserts.whereType<ScheduledWakeEntity>().single;
      expect(record.id, recordId);
      expect(record.status, ScheduledWakeStatus.pending);
      expect(record.scheduledAt, now.toUtc().add(goalChatRecoveryGrace));
      verifyNever(
        () => orchestrator.enqueueManualWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          triggerTokens: any(named: 'triggerTokens'),
          supersede: any(named: 'supersede'),
          initiator: any(named: 'initiator'),
        ),
      );

      // Every later scan, on any device, finds it pending and leaves it.
      expect(await service.restoreOldestPendingMessage('goal-1'), isFalse);
      expect(upserts.whereType<ScheduledWakeEntity>(), hasLength(1));
    });

    test('after a recovery that did not answer, the next window is due when '
        "the last one's lease lapses", () async {
      final lapse = DateTime.utc(2026, 8, 18, 13, 5);
      stored[recordId] = recovery(
        status: ScheduledWakeStatus.consumed,
        scheduledAt: DateTime.utc(2026, 8, 18, 12, 30),
        leaseUntil: lapse,
      );

      expect(
        await withClock(
          Clock.fixed(now),
          () => service.restoreOldestPendingMessage('goal-1'),
        ),
        isTrue,
      );

      final next = upserts.whereType<ScheduledWakeEntity>().single;
      expect(next.status, ScheduledWakeStatus.pending);
      expect(next.scheduledAt, lapse);
      expect(next.vectorClock, const VectorClock({'host-b': 4}));
      expect(next.leaseHostId, isNull);
      expect(next.leaseUntil, isNull);
      expect(next.consumedAt, isNull);
    });

    test(
      'a window the author consumed waits a grace past its deadline',
      () async {
        final deadline = DateTime.utc(2026, 8, 18, 12, 30);
        stored[recordId] = recovery(
          status: ScheduledWakeStatus.consumed,
          scheduledAt: deadline,
        );

        await withClock(
          Clock.fixed(now),
          () => service.restoreOldestPendingMessage('goal-1'),
        );

        expect(
          upserts.whereType<ScheduledWakeEntity>().single.scheduledAt,
          deadline.add(goalChatRecoveryGrace),
        );
      },
    );

    test('nothing to recover when every turn is answered', () async {
      when(
        () => repository.getMessagesByKind(
          'goal-1',
          AgentMessageKind.user,
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);

      expect(await service.restoreOldestPendingMessage('goal-1'), isFalse);
      expect(upserts, isEmpty);
    });
  });

  test('ignores blank turns and malformed trigger tokens', () async {
    await service.sendMessage(agentId: 'goal-1', text: '   ');

    expect(upserts, isEmpty);
    verifyNever(
      () => orchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        supersede: any(named: 'supersede'),
        initiator: any(named: 'initiator'),
      ),
    );
    expect(
      goalChatMessageIdFromTriggerTokens(const {
        'unrelated',
        'goal-chat-message:',
      }),
      isNull,
    );
  });

  test('turn failures retain a useful fallback description', () {
    expect(
      const GoalChatTurnException(null).toString(),
      'The goal-agent turn failed.',
    );
    expect(const GoalChatTurnException('offline').toString(), 'offline');
  });
}
