import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

class _MockHistory extends Mock implements FrontChatHistoryService {}

void main() {
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 10, 24, 9);
  late MockAgentSyncService syncService;
  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late MockUpdateNotifications notifications;
  late _MockHistory history;
  late StreamController<WakeRunCompletion> completions;
  late List<AgentDomainEntity> upserts;
  late FrontChatService service;

  AgentIdentityEntity identity(AgentLifecycle lifecycle) => makeTestIdentity(
    id: frontAgentId,
    agentId: frontAgentId,
    kind: AgentKinds.frontAgent,
    lifecycle: lifecycle,
  );

  /// The recovery record of [messageId] as the service writes it.
  ScheduledWakeEntity recoveryOf(String messageId) =>
      upserts.whereType<ScheduledWakeEntity>().lastWhere(
        (r) => r.workspaceKey == frontChatRecoveryWorkspaceKey(messageId),
      );

  setUp(() {
    syncService = MockAgentSyncService();
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
    notifications = MockUpdateNotifications();
    history = _MockHistory();
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
      return id == frontAgentId ? identity(AgentLifecycle.active) : null;
    });
    service = FrontChatService(
      repository: repository,
      syncService: syncService,
      orchestrator: orchestrator,
      notifications: notifications,
      historyService: history,
    );
  });

  /// Enqueues answer `run-1` and completes it with [status] once the
  /// service is listening.
  void stubWake(WakeRunStatus status) {
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
          WakeRunCompletion(
            runKey: 'run-1',
            agentId: frontAgentId,
            status: status,
            reason: WakeReason.userMessage.name,
            error: status == WakeRunStatus.completed ? null : 'boom',
          ),
        ),
      );
      return 'run-1';
    });
  }

  group('appendMessage', () {
    test('an empty message persists nothing and wakes nothing', () async {
      expect(
        await service.appendMessage(text: '   ', conversationId: 'c-1'),
        isNull,
      );
      await service.sendMessage(text: '   ', conversationId: 'c-1');
      expect(upserts, isEmpty);
      verifyNever(() => repository.getEntity(any()));
    });

    test('refuses a turn when the front agent is not active', () async {
      when(
        () => repository.getEntity(frontAgentId),
      ).thenAnswer((_) async => identity(AgentLifecycle.dormant));

      await expectLater(
        service.appendMessage(text: 'Hello', conversationId: 'c-1'),
        throwsA(isA<FrontChatTurnException>()),
      );
      expect(upserts, isEmpty);
    });

    test(
      'persists the payload and the user turn, shows it, and arms the '
      'lease-elected recovery record a grace later — waking nothing',
      () async {
        final messageId = await withClock(
          Clock.fixed(now),
          () => service.appendMessage(
            text: '  Buy the hose  ',
            conversationId: 'c-1',
          ),
        );

        final payload = upserts.whereType<AgentMessagePayloadEntity>().single;
        final message = upserts.whereType<AgentMessageEntity>().single;
        expect(messageId, message.id);
        expect(payload.content, {
          'text': 'Buy the hose',
          'conversationId': 'c-1',
        });
        expect(message.kind, AgentMessageKind.user);
        expect(message.contentEntryId, payload.id);
        // The source turn is its own thread; the wake links back by token.
        expect(message.threadId, message.id);
        expect(message.metadata.runKey, isNull);
        verify(
          () => notifications.notifyUiOnly({frontAgentId, agentNotification}),
        ).called(1);

        final record = recoveryOf(message.id);
        expect(record.id, frontChatRecoveryRecordId(frontAgentId, message.id));
        expect(record.status, ScheduledWakeStatus.pending);
        expect(record.scheduledAt, now.toUtc().add(frontChatRecoveryGrace));
        expect(record.reason, WakeReason.userMessage.name);
        expect(record.triggerTokens, [
          frontChatMessageTriggerToken(message.id),
        ]);
        verifyNever(
          () => orchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
            supersede: any(named: 'supersede'),
            initiator: any(named: 'initiator'),
          ),
        );
      },
    );

    test('a recovery record that fails to write does not cost the turn: '
        'the turn still returns', () async {
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.first as AgentDomainEntity;
        if (entity is ScheduledWakeEntity) throw StateError('outbox');
        upserts.add(entity);
      });

      final messageId = await service.appendMessage(
        text: 'Hello',
        conversationId: 'c-1',
      );

      expect(messageId, isNotNull);
      expect(upserts.whereType<ScheduledWakeEntity>(), isEmpty);
    });

    test('an append that committed but failed its outbox flush is '
        'reconciled, not retried into a duplicate', () async {
      AgentMessageEntity? persisted;
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.first as AgentDomainEntity;
        upserts.add(entity);
        if (entity is AgentMessageEntity) {
          persisted = entity;
          throw StateError('outbox flush failed');
        }
      });
      when(() => repository.getEntity(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        if (id == frontAgentId) return identity(AgentLifecycle.active);
        return persisted?.id == id ? persisted : null;
      });

      final messageId = await service.appendMessage(
        text: 'Hello',
        conversationId: 'c-1',
      );

      expect(messageId, persisted!.id);
      expect(upserts.whereType<AgentMessageEntity>(), hasLength(1));
    });
  });

  test('enqueueMessage wakes the front agent with the chat token and returns '
      'the run key without waiting', () {
    stubWake(WakeRunStatus.completed);

    expect(service.enqueueMessage(messageId: 'm-1'), 'run-1');

    verify(
      () => orchestrator.enqueueManualWake(
        agentId: frontAgentId,
        reason: WakeReason.userMessage.name,
        triggerTokens: {frontChatMessageTriggerToken('m-1')},
        supersede: false,
        initiator: WakeInitiator.user,
      ),
    ).called(1);
    verifyNever(() => orchestrator.runCompletions);
  });

  group('sendMessage and retryMessage', () {
    test('a completed wake consumes the pending recovery record', () async {
      stubWake(WakeRunStatus.completed);
      // The record the append wrote is what the consume re-reads.
      when(() => repository.getEntity(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        if (id == frontAgentId) return identity(AgentLifecycle.active);
        for (final record in upserts.whereType<ScheduledWakeEntity>()) {
          if (record.id == id) return record;
        }
        return null;
      });

      await service.sendMessage(text: 'Hello', conversationId: 'c-1');

      final message = upserts.whereType<AgentMessageEntity>().single;
      final record = recoveryOf(message.id);
      expect(record.status, ScheduledWakeStatus.consumed);
      expect(record.consumedAt, isNotNull);
    });

    test('a failed wake surfaces as a turn exception naming the message and '
        'leaves the recovery pending', () async {
      stubWake(WakeRunStatus.failed);

      Object? thrown;
      try {
        await service.sendMessage(text: 'Hello', conversationId: 'c-1');
      } on FrontChatTurnException catch (e) {
        thrown = e;
      }

      final message = upserts.whereType<AgentMessageEntity>().single;
      expect(
        thrown,
        isA<FrontChatTurnException>()
            .having((e) => e.messageId, 'messageId', message.id)
            .having((e) => e.toString(), 'detail', 'boom'),
      );
      expect(recoveryOf(message.id).status, ScheduledWakeStatus.pending);
    });

    test('a runtime that stops before the turn completes fails the turn '
        'instead of hanging the composer', () async {
      when(
        () => orchestrator.enqueueManualWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          triggerTokens: any(named: 'triggerTokens'),
          supersede: any(named: 'supersede'),
          initiator: any(named: 'initiator'),
        ),
      ).thenAnswer((_) {
        scheduleMicrotask(completions.close);
        return 'run-1';
      });

      await expectLater(
        service.retryMessage(messageId: 'm-1'),
        throwsA(
          isA<FrontChatTurnException>().having(
            (e) => e.toString(),
            'detail',
            contains('runtime stopped'),
          ),
        ),
      );
    });

    test('a retry whose record was already consumed leaves it alone', () async {
      stubWake(WakeRunStatus.completed);
      final consumed =
          AgentDomainEntity.scheduledWake(
                id: frontChatRecoveryRecordId(frontAgentId, 'm-1'),
                agentId: frontAgentId,
                scheduledAt: now.toUtc(),
                status: ScheduledWakeStatus.consumed,
                reason: WakeReason.userMessage.name,
                updatedAt: now,
                vectorClock: null,
                workspaceKey: frontChatRecoveryWorkspaceKey('m-1'),
              )
              as ScheduledWakeEntity;
      when(
        () => repository.getEntity(consumed.id),
      ).thenAnswer((_) async => consumed);

      await service.retryMessage(messageId: 'm-1');

      expect(upserts.whereType<ScheduledWakeEntity>(), isEmpty);
    });
  });

  group('restoreOldestPendingMessage', () {
    test('nothing pending arms nothing', () async {
      when(
        () => history.oldestPendingMessageId(),
      ).thenAnswer((_) async => null);
      expect(await service.restoreOldestPendingMessage(), isFalse);
      expect(upserts, isEmpty);
    });

    test('a turn with no record gets one, a grace from now', () async {
      when(
        () => history.oldestPendingMessageId(),
      ).thenAnswer((_) async => 'm-1');

      final armed = await withClock(
        Clock.fixed(now),
        service.restoreOldestPendingMessage,
      );

      expect(armed, isTrue);
      final record = recoveryOf('m-1');
      expect(record.status, ScheduledWakeStatus.pending);
      expect(record.scheduledAt, now.toUtc().add(frontChatRecoveryGrace));
      expect(record.vectorClock, isNull);
    });

    test(
      "over a tombstone, the new record carries the tombstone's clock",
      () async {
        when(
          () => history.oldestPendingMessageId(),
        ).thenAnswer((_) async => 'm-1');
        final tombstone =
            AgentDomainEntity.scheduledWake(
                  id: frontChatRecoveryRecordId(frontAgentId, 'm-1'),
                  agentId: frontAgentId,
                  scheduledAt: now.toUtc(),
                  status: ScheduledWakeStatus.pending,
                  reason: WakeReason.userMessage.name,
                  updatedAt: now,
                  vectorClock: const VectorClock({'a': 3}),
                  workspaceKey: frontChatRecoveryWorkspaceKey('m-1'),
                  deletedAt: now,
                )
                as ScheduledWakeEntity;
        when(
          () => repository.getEntity(tombstone.id),
        ).thenAnswer((_) async => tombstone);

        await service.restoreOldestPendingMessage();

        expect(recoveryOf('m-1').vectorClock, const VectorClock({'a': 3}));
        expect(recoveryOf('m-1').deletedAt, isNull);
      },
    );

    test('a pending record is left alone', () async {
      when(
        () => history.oldestPendingMessageId(),
      ).thenAnswer((_) async => 'm-1');
      final pending =
          AgentDomainEntity.scheduledWake(
                id: frontChatRecoveryRecordId(frontAgentId, 'm-1'),
                agentId: frontAgentId,
                scheduledAt: now.toUtc(),
                status: ScheduledWakeStatus.pending,
                reason: WakeReason.userMessage.name,
                updatedAt: now,
                vectorClock: null,
                workspaceKey: frontChatRecoveryWorkspaceKey('m-1'),
              )
              as ScheduledWakeEntity;
      when(
        () => repository.getEntity(pending.id),
      ).thenAnswer((_) async => pending);

      expect(await service.restoreOldestPendingMessage(), isFalse);
      expect(upserts, isEmpty);
    });

    test(
      'a consumed record that did not answer is re-armed for the next '
      'window: when its lease lapses, else a grace past its deadline',
      () async {
        when(
          () => history.oldestPendingMessageId(),
        ).thenAnswer((_) async => 'm-1');
        final leaseUntil = now.toUtc().add(const Duration(minutes: 12));
        final consumed =
            AgentDomainEntity.scheduledWake(
                  id: frontChatRecoveryRecordId(frontAgentId, 'm-1'),
                  agentId: frontAgentId,
                  scheduledAt: now.toUtc(),
                  status: ScheduledWakeStatus.consumed,
                  reason: WakeReason.userMessage.name,
                  updatedAt: now,
                  vectorClock: null,
                  workspaceKey: frontChatRecoveryWorkspaceKey('m-1'),
                  consumedAt: now,
                  leaseHostId: 'other-device',
                  leaseUntil: leaseUntil,
                )
                as ScheduledWakeEntity;
        when(
          () => repository.getEntity(consumed.id),
        ).thenAnswer((_) async => consumed);

        expect(await service.restoreOldestPendingMessage(), isTrue);
        final rearmed = recoveryOf('m-1');
        expect(rearmed.status, ScheduledWakeStatus.pending);
        expect(rearmed.scheduledAt, leaseUntil);
        expect(rearmed.consumedAt, isNull);
        expect(rearmed.leaseHostId, isNull);
        expect(rearmed.leaseUntil, isNull);

        // The author's own consume carries no lease: a grace past the deadline.
        upserts.clear();
        when(
          () => repository.getEntity(consumed.id),
        ).thenAnswer((_) async => consumed.copyWith(leaseUntil: null));
        await service.restoreOldestPendingMessage();
        expect(
          recoveryOf('m-1').scheduledAt,
          now.toUtc().add(frontChatRecoveryGrace),
        );
      },
    );
  });
}
