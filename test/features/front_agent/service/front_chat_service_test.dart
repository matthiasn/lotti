import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/front_chat_tokens.dart';
import 'package:lotti/classes/vector_clock.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/workflow/wake_result.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/model/front_conversation.dart';
import 'package:lotti/features/front_agent/model/front_turn_failure.dart';
import 'package:lotti/features/front_agent/service/front_chat_history_service.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/features/front_agent/workflow/front_agent_contract.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
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
  late MockDomainLogger domainLogger;
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
    domainLogger = MockDomainLogger();
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
      domainLogger: domainLogger,
    );
  });

  /// Enqueues answer `run-1` and completes it with [status] once the
  /// service is listening.
  void stubWake(
    WakeRunStatus status, {
    Object? error,
    DateTime? startedAt,
    DateTime? finishedAt,
  }) {
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
            error: error ?? (status == WakeRunStatus.completed ? null : 'boom'),
            startedAt: startedAt,
            finishedAt: finishedAt,
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

    test(
      'a turn in a conversation in no category writes no categories: only '
      'one named in the question narrows it',
      () async {
        await service.appendMessage(
          text: 'How is the garden?',
          conversationId: 'c-1',
        );

        final payload = upserts.whereType<AgentMessagePayloadEntity>().single;
        expect(payload.content.containsKey(frontCategoriesKey), isFalse);
        expect(frontCategoriesOf(payload.content), isEmpty);
        // Nor, typed fresh, a turn it replaces.
        expect(payload.content.containsKey(frontTurnReplacesKey), isFalse);
      },
    );

    test(
      "a turn carries its conversation's category, in a stable order, so "
      'her answer is narrowed to it',
      () async {
        await service.appendMessage(
          text: 'How is the garden?',
          conversationId: 'c-1',
          categoryIds: {'cat-habitat', 'cat-garden'},
        );

        final payload = upserts.whereType<AgentMessagePayloadEntity>().single;
        expect(payload.content[frontCategoriesKey], [
          'cat-garden',
          'cat-habitat',
        ]);
        expect(frontCategoriesOf(payload.content), {
          'cat-garden',
          'cat-habitat',
        });
        expect(frontConversationOf(payload.content), 'c-1');
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

  /// A user turn written before, with its words in `<id>-payload`.
  AgentMessageEntity earlierTurn(String id) => makeTestMessage(
    id: id,
    agentId: frontAgentId,
    kind: AgentMessageKind.user,
    contentEntryId: '$id-payload',
  );

  AgentMessagePayloadEntity earlierTurnPayload(String conversationId) =>
      makeTestMessagePayload(
        id: 'u-stopped-payload',
        agentId: frontAgentId,
        content: {
          'text': 'Count the chicks',
          frontConversationKey: conversationId,
        },
      );

  test('an edit names only a turn of its own conversation: one from another, '
      'or none at all, is not replaced', () async {
    when(() => repository.getEntity(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      if (id == frontAgentId) return identity(AgentLifecycle.active);
      if (id == 'u-stopped') return earlierTurn('u-stopped');
      if (id == 'u-stopped-payload') return earlierTurnPayload('c-2');
      return null;
    });

    await service.appendMessage(
      text: 'Count the chicks',
      conversationId: 'c-1',
      replaces: 'u-stopped',
    );
    await service.appendMessage(
      text: 'Count the eggs',
      conversationId: 'c-1',
      replaces: 'u-gone',
    );

    for (final payload in upserts.whereType<AgentMessagePayloadEntity>()) {
      expect(frontTurnReplaces(payload.content), isNull);
    }
    expect(upserts.whereType<AgentMessagePayloadEntity>(), hasLength(2));
  });

  group('sendMessage and retryMessage', () {
    test('a completed wake consumes the pending recovery record', () async {
      stubWake(WakeRunStatus.completed);
      // The record the append wrote is what the consume re-reads.
      when(() => repository.getEntity(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        if (id == frontAgentId) return identity(AgentLifecycle.active);
        // The turn it was edited from, in the same conversation.
        if (id == 'u-stopped') return earlierTurn('u-stopped');
        if (id == 'u-stopped-payload') return earlierTurnPayload('c-1');
        for (final record in upserts.whereType<ScheduledWakeEntity>()) {
          if (record.id == id) return record;
        }
        return null;
      });

      await service.sendMessage(
        text: 'Hello',
        conversationId: 'c-1',
        categoryIds: {'cat-penguins'},
        replaces: 'u-stopped',
      );

      final message = upserts.whereType<AgentMessageEntity>().single;
      final record = recoveryOf(message.id);
      expect(record.status, ScheduledWakeStatus.consumed);
      expect(record.consumedAt, isNotNull);
      // The scope goes through to the turn the wake reads.
      expect(
        frontCategoriesOf(
          upserts.whereType<AgentMessagePayloadEntity>().single.content,
        ),
        {'cat-penguins'},
      );
      // So does the stopped turn it was edited from.
      expect(
        frontTurnReplaces(
          upserts.whereType<AgentMessagePayloadEntity>().single.content,
        ),
        'u-stopped',
      );
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
            .having((e) => e.toString(), 'detail', 'boom')
            .having((e) => e.failure, 'failure', FrontTurnFailure.unknown),
      );
      expect(recoveryOf(message.id).status, ScheduledWakeStatus.pending);
    });

    test("a failed wake's cause rides the turn exception, for the chat to "
        'say', () async {
      final cause = Exception('Insufficient credits');
      stubWake(
        WakeRunStatus.failed,
        error: WakeFailedException(
          kind: 'front',
          reason: FrontTurnFailure.outOfCredit.wakeError(),
          cause: cause,
        ),
      );

      await expectLater(
        service.retryMessage(messageId: 'm-1'),
        throwsA(
          isA<FrontChatTurnException>()
              .having(
                (e) => e.failure,
                'failure',
                FrontTurnFailure.outOfCredit,
              )
              // The provider's words travel in memory, never in the text.
              .having((e) => e.cause, 'cause', same(cause))
              .having(
                (e) => e.toString(),
                'detail',
                isNot(contains('Insufficient')),
              ),
        ),
      );
    });

    test('logs how long the turn queued for a wake slot and how long it '
        'ran', () async {
      final enqueuedAt = DateTime(2026, 11, 9, 10);
      stubWake(
        WakeRunStatus.completed,
        startedAt: enqueuedAt.add(const Duration(seconds: 2)),
        finishedAt: enqueuedAt.add(const Duration(seconds: 5)),
      );

      await withClock(
        Clock.fixed(enqueuedAt),
        () => service.retryMessage(messageId: 'm-1'),
      );

      verify(
        () => domainLogger.log(
          LogDomain.agentWorkflow,
          'front turn completed: queued=2000ms run=3000ms total=5000ms',
          subDomain: 'frontChat',
        ),
      ).called(1);
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

  group('stopMessage', () {
    // A turn this device is not waiting on still needs her unless a test
    // says otherwise.
    setUp(() {
      when(() => history.pendingMessageIds()).thenAnswer((_) async => ['m-1']);
    });

    /// Holds the stop's write of its payload until [gate] completes — or
    /// fails it when [gate] completes with an error.
    void gateStopWrite(String messageId, Completer<void> gate) {
      when(() => syncService.upsertEntity(any())).thenAnswer((
        invocation,
      ) async {
        final entity =
            invocation.positionalArguments.first as AgentDomainEntity;
        if (entity.id == frontChatStopPayloadId(messageId)) await gate.future;
        upserts.add(entity);
      });
    }

    /// Reads back what the service wrote, so a consume sees its record.
    void readBack() {
      when(() => repository.getEntity(any())).thenAnswer((invocation) async {
        final id = invocation.positionalArguments.first as String;
        if (id == frontAgentId) return identity(AgentLifecycle.active);
        for (final record in upserts.whereType<ScheduledWakeEntity>()) {
          if (record.id == id) return record;
        }
        return null;
      });
    }

    /// Enqueues `run-1`, which runs until it is cancelled.
    void stubLongWake() {
      when(
        () => orchestrator.enqueueManualWake(
          agentId: any(named: 'agentId'),
          reason: any(named: 'reason'),
          triggerTokens: any(named: 'triggerTokens'),
          supersede: any(named: 'supersede'),
          initiator: any(named: 'initiator'),
        ),
      ).thenReturn('run-1');
    }

    /// A cancel of [runKey] ends it aborted, as the orchestrator does.
    void stubCancel(String runKey) {
      when(() => orchestrator.cancelWake(frontAgentId, runKey)).thenAnswer((
        _,
      ) {
        scheduleMicrotask(
          () => completions.add(
            WakeRunCompletion(
              runKey: runKey,
              agentId: frontAgentId,
              status: WakeRunStatus.aborted,
              reason: WakeReason.userMessage.name,
              error: 'wake stopped by the user',
            ),
          ),
        );
        return true;
      });
    }

    AgentMessageEntity stopRecord() => upserts
        .whereType<AgentMessageEntity>()
        .singleWhere((m) => m.kind == AgentMessageKind.action);

    test('stopping a turn on its way cancels just its wake, and the send '
        'returns as one that went through', () async {
      readBack();
      stubLongWake();
      stubCancel('run-1');
      String? appended;
      final send = service.sendMessage(
        text: 'Count the hatchlings',
        conversationId: 'c-1',
        onAppended: (id) => appended = id,
      );
      await pumpEventQueue();
      expect(appended, isNotNull);

      await service.stopMessage(messageId: appended!);

      await expectLater(send, completes);
      verify(() => orchestrator.cancelWake(frontAgentId, 'run-1')).called(1);
      expect(recoveryOf(appended!).status, ScheduledWakeStatus.consumed);
    });

    test('the stop is recorded as an empty reply to the turn, marked '
        'stopped, which counts as her answer', () async {
      await service.stopMessage(messageId: 'm-1');

      final record = stopRecord();
      expect(record.id, frontChatStopMessageId('m-1'));
      expect(record.threadId, 'm-1');
      expect(record.metadata.operationId, 'm-1');
      expect(record.metadata.toolName, FrontAgentToolNames.replyToUser);
      expect(isFrontAnswerRow(record), isTrue);
      final payload = upserts.whereType<AgentMessagePayloadEntity>().single;
      expect(payload.id, frontChatStopPayloadId('m-1'));
      expect(record.contentEntryId, payload.id);
      expect(frontTurnStopped(payload.content), isTrue);
      expect(payload.content.containsKey('text'), isFalse);
      verify(
        () => notifications.notifyUiOnly({frontAgentId, agentNotification}),
      ).called(1);
    });

    test('a turn this device is not waiting on is stopped without cancelling '
        'any wake, and its pending recovery is consumed', () async {
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

      await withClock(Clock.fixed(now), () async {
        await service.stopMessage(messageId: 'm-1');
      });

      verifyNever(() => orchestrator.cancelWake(any(), any()));
      expect(recoveryOf('m-1').status, ScheduledWakeStatus.consumed);
      expect(recoveryOf('m-1').consumedAt, now);
      expect(stopRecord().metadata.operationId, 'm-1');
    });

    test('a Stop on a turn that no longer needs her — answered, or stopped '
        'already — stops nothing', () async {
      when(() => history.pendingMessageIds()).thenAnswer((_) async => []);

      await service.stopMessage(messageId: 'm-1');

      expect(upserts, isEmpty);
      verifyNever(() => notifications.notifyUiOnly(any()));
    });

    test('a stop that could not be written leaves the wake ending unfinished '
        'a failure', () async {
      readBack();
      stubLongWake();
      String? appended;
      final send = service.sendMessage(
        text: 'Count the hatchlings',
        conversationId: 'c-1',
        onAppended: (id) => appended = id,
      );
      await pumpEventQueue();
      final gate = Completer<void>();
      gateStopWrite(appended!, gate);

      final stop = service.stopMessage(messageId: appended!);
      gate.completeError(StateError('db closed'));
      await expectLater(stop, throwsStateError);
      verifyNever(() => orchestrator.cancelWake(any(), any()));
      completions.add(
        WakeRunCompletion(
          runKey: 'run-1',
          agentId: frontAgentId,
          status: WakeRunStatus.aborted,
          reason: WakeReason.userMessage.name,
          error: 'boom',
        ),
      );

      await expectLater(send, throwsA(isA<FrontChatTurnException>()));
    });

    test('a wake that ends while the stop is being written waits for it: '
        'recorded, the send went through', () async {
      readBack();
      stubLongWake();
      when(
        () => orchestrator.cancelWake(any(), any()),
      ).thenReturn(false);
      String? appended;
      final send = service.sendMessage(
        text: 'Count the hatchlings',
        conversationId: 'c-1',
        onAppended: (id) => appended = id,
      );
      await pumpEventQueue();
      final gate = Completer<void>();
      gateStopWrite(appended!, gate);

      final stop = service.stopMessage(messageId: appended!);
      await pumpEventQueue();
      completions.add(
        WakeRunCompletion(
          runKey: 'run-1',
          agentId: frontAgentId,
          status: WakeRunStatus.aborted,
          reason: WakeReason.userMessage.name,
          error: 'boom',
        ),
      );
      await pumpEventQueue();
      gate.complete();

      await stop;
      await expectLater(send, completes);
    });

    test('a recovery record that cannot be consumed still lets the wake be '
        'cancelled and the thread told', () async {
      readBack();
      stubLongWake();
      stubCancel('run-1');
      String? appended;
      final send = service.sendMessage(
        text: 'Count the hatchlings',
        conversationId: 'c-1',
        onAppended: (id) => appended = id,
      );
      await pumpEventQueue();
      when(
        () => repository.getEntity(
          frontChatRecoveryRecordId(frontAgentId, appended!),
        ),
      ).thenAnswer((_) async => throw StateError('db closed'));

      await expectLater(
        service.stopMessage(messageId: appended!),
        throwsStateError,
      );

      verify(() => orchestrator.cancelWake(frontAgentId, 'run-1')).called(1);
      verify(
        () => notifications.notifyUiOnly({frontAgentId, agentNotification}),
      ).called(greaterThanOrEqualTo(1));
      await expectLater(send, completes);
    });

    test(
      'an aborted wake of a turn nobody stopped is still a failure',
      () async {
        readBack();
        stubWake(WakeRunStatus.aborted);

        await expectLater(
          service.sendMessage(text: 'Hello', conversationId: 'c-1'),
          throwsA(isA<FrontChatTurnException>()),
        );
      },
    );

    test('once a stopped send has returned, a later wake of the same turn '
        'that aborts fails again', () async {
      readBack();
      stubLongWake();
      stubCancel('run-1');
      String? appended;
      final send = service.sendMessage(
        text: 'Hello',
        conversationId: 'c-1',
        onAppended: (id) => appended = id,
      );
      await pumpEventQueue();
      await service.stopMessage(messageId: appended!);
      await send;

      stubWake(WakeRunStatus.aborted);
      await expectLater(
        service.retryMessage(messageId: appended!),
        throwsA(isA<FrontChatTurnException>()),
      );
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
