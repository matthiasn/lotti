import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/agents/wake/wake_queue.dart';
import 'package:lotti/features/agents/wake/wake_runner.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
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
    service = GoalChatService(
      repository: repository,
      syncService: syncService,
      orchestrator: orchestrator,
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

      expect(upserts, hasLength(2));
      final payload = upserts.first as AgentMessagePayloadEntity;
      final message = upserts.last as AgentMessageEntity;
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

  test('startup recovery re-enqueues a durable unanswered turn once', () async {
    final orphan =
        AgentDomainEntity.agentMessage(
              id: 'message-orphan',
              agentId: 'goal-1',
              threadId: 'message-orphan',
              kind: AgentMessageKind.user,
              createdAt: DateTime(2026, 8, 18, 12),
              vectorClock: null,
              contentEntryId: 'payload-orphan',
              metadata: const AgentMessageMetadata(),
            )
            as AgentMessageEntity;
    when(
      () => repository.getMessagesByKind(
        'goal-1',
        AgentMessageKind.user,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [orphan]);
    when(
      () => repository.getMessagesByKind(
        'goal-1',
        AgentMessageKind.action,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => orchestrator.enqueueManualWake(
        agentId: 'goal-1',
        reason: WakeReason.userMessage.name,
        triggerTokens: any(named: 'triggerTokens'),
        supersede: false,
        initiator: WakeInitiator.user,
      ),
    ).thenReturn('recovery-run');

    expect(await service.restoreOldestPendingMessage('goal-1'), isTrue);
    expect(
      await service.restoreOldestPendingMessage('goal-1'),
      isFalse,
      reason: 'the same orphan must not be queued concurrently twice',
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
    expect(goalChatMessageIdFromTriggerTokens(tokens), orphan.id);

    completions.add(
      const WakeRunCompletion(
        runKey: 'recovery-run',
        status: WakeRunStatus.failed,
      ),
    );
    await pumpEventQueue();
    expect(
      await service.restoreOldestPendingMessage('goal-1'),
      isTrue,
      reason: 'a terminal failure releases the durable turn for a later scan',
    );
  });

  test('failed recovery enqueue releases the durable turn for retry', () async {
    final orphan =
        AgentDomainEntity.agentMessage(
              id: 'message-orphan',
              agentId: 'goal-1',
              threadId: 'message-orphan',
              kind: AgentMessageKind.user,
              createdAt: DateTime(2026, 8, 18, 12),
              vectorClock: null,
              contentEntryId: 'payload-orphan',
              metadata: const AgentMessageMetadata(),
            )
            as AgentMessageEntity;
    when(
      () => repository.getMessagesByKind(
        'goal-1',
        AgentMessageKind.user,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => [orphan]);
    when(
      () => repository.getMessagesByKind(
        'goal-1',
        AgentMessageKind.action,
        limit: any(named: 'limit'),
      ),
    ).thenAnswer((_) async => []);
    when(
      () => orchestrator.enqueueManualWake(
        agentId: 'goal-1',
        reason: WakeReason.userMessage.name,
        triggerTokens: any(named: 'triggerTokens'),
        supersede: false,
        initiator: WakeInitiator.user,
      ),
    ).thenThrow(StateError('queue unavailable'));

    await expectLater(
      service.restoreOldestPendingMessage('goal-1'),
      throwsA(isA<StateError>()),
    );
    await expectLater(
      service.restoreOldestPendingMessage('goal-1'),
      throwsA(isA<StateError>()),
    );
    verify(
      () => orchestrator.enqueueManualWake(
        agentId: 'goal-1',
        reason: WakeReason.userMessage.name,
        triggerTokens: any(named: 'triggerTokens'),
        supersede: false,
        initiator: WakeInitiator.user,
      ),
    ).called(2);
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
