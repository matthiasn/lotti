import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/goals/service/goal_chat_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService syncService;
  late MockWakeOrchestrator orchestrator;
  late StreamController<WakeRunCompletion> completions;
  late List<AgentDomainEntity> upserts;
  late GoalChatService service;

  setUp(() {
    syncService = MockAgentSyncService();
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
    service = GoalChatService(syncService, orchestrator);
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
