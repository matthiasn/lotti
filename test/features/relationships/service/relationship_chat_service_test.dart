import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/relationships/service/relationship_chat_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  const agentId = 'relationship_agent:person-1';

  AgentIdentityEntity relationshipIdentity(AgentLifecycle lifecycle) =>
      AgentDomainEntity.agent(
            id: agentId,
            agentId: agentId,
            kind: AgentKinds.relationshipAgent,
            displayName: 'Anna',
            lifecycle: lifecycle,
            mode: AgentInteractionMode.autonomous,
            allowedCategoryIds: const {},
            currentStateId: '$agentId:state',
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
  late RelationshipChatService service;

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
      return id == agentId ? relationshipIdentity(AgentLifecycle.active) : null;
    });
    service = RelationshipChatService(
      repository: repository,
      syncService: syncService,
      orchestrator: orchestrator,
    );
  });

  test('does not persist a turn for an inactive relationship agent', () async {
    when(
      () => repository.getEntity(agentId),
    ).thenAnswer((_) async => relationshipIdentity(AgentLifecycle.destroyed));

    await expectLater(
      service.sendMessage(agentId: agentId, text: 'How is Anna?'),
      throwsA(
        isA<RelationshipChatTurnException>().having(
          (error) => error.detail,
          'detail',
          'relationship agent is not active',
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

  test('persists the durable source turn BEFORE enqueuing the user-message '
      'wake, with the chat token carrying the message id', () async {
    when(
      () => orchestrator.enqueueManualWake(
        agentId: agentId,
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

    await service.sendMessage(agentId: agentId, text: '  How is Anna?  ');

    expect(upserts, hasLength(2));
    final payload = upserts.first as AgentMessagePayloadEntity;
    final message = upserts.last as AgentMessageEntity;
    expect(payload.content['text'], 'How is Anna?');
    expect(message.kind, AgentMessageKind.user);
    expect(message.contentEntryId, payload.id);
    final tokens =
        verify(
              () => orchestrator.enqueueManualWake(
                agentId: agentId,
                reason: WakeReason.userMessage.name,
                triggerTokens: captureAny(named: 'triggerTokens'),
                supersede: false,
                initiator: WakeInitiator.user,
              ),
            ).captured.single
            as Set<String>;
    expect(relationshipChatMessageIdFromTriggerTokens(tokens), message.id);
  });

  test('a failed wake surfaces the message id so retry re-enqueues the '
      'already durable turn instead of duplicating it', () async {
    when(
      () => orchestrator.enqueueManualWake(
        agentId: agentId,
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
            status: WakeRunStatus.failed,
            error: 'provider down',
          ),
        ),
      );
      return 'chat-run';
    });

    await expectLater(
      service.sendMessage(agentId: agentId, text: 'How is Anna?'),
      throwsA(
        isA<RelationshipChatTurnException>().having(
          (error) => error.messageId,
          'messageId',
          isNotNull,
        ),
      ),
    );
    // The turn IS durable — only the wake failed.
    expect(upserts, hasLength(2));
  });

  test('an empty draft is a no-op', () async {
    await service.sendMessage(agentId: agentId, text: '   ');
    expect(upserts, isEmpty);
  });

  test('the chat token round-trips through the parser', () {
    expect(
      relationshipChatMessageIdFromTriggerTokens({
        relationshipChatMessageTriggerToken('msg-1'),
        'person-1',
      }),
      'msg-1',
    );
    expect(
      relationshipChatMessageIdFromTriggerTokens(const {'person-1'}),
      isNull,
    );
  });

  test('a message append whose outbox flush failed AFTER the commit is '
      'reconciled by id, not retried into a duplicate turn', () async {
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is AgentMessageEntity) {
        throw StateError('outbox flush failed');
      }
      upserts.add(entity);
    });
    // The re-read finds the committed turn under its id, matching payload
    // and owner — so the append is treated as durable.
    when(() => repository.getEntity(any())).thenAnswer((invocation) async {
      final id = invocation.positionalArguments.first as String;
      if (id == agentId) return relationshipIdentity(AgentLifecycle.active);
      final payload = upserts.whereType<AgentMessagePayloadEntity>().single;
      return AgentDomainEntity.agentMessage(
            id: id,
            agentId: agentId,
            threadId: id,
            kind: AgentMessageKind.user,
            createdAt: DateTime(2026),
            vectorClock: null,
            contentEntryId: payload.id,
            metadata: const AgentMessageMetadata(),
          )
          as AgentMessageEntity;
    });
    when(
      () => orchestrator.enqueueManualWake(
        agentId: agentId,
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

    await service.sendMessage(agentId: agentId, text: 'How is Anna?');
    expect(upserts.whereType<AgentMessagePayloadEntity>(), hasLength(1));
  });

  test('a failed append with NO committed row underneath rethrows — a '
      'phantom durable turn must not be enqueued', () async {
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
      if (entity is AgentMessageEntity) {
        throw StateError('append rejected');
      }
      upserts.add(entity);
    });
    await expectLater(
      service.sendMessage(agentId: agentId, text: 'How is Anna?'),
      throwsA(isA<StateError>()),
    );
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

  test('the exception reads as its detail, with a stable fallback', () {
    expect(
      const RelationshipChatTurnException('provider down').toString(),
      'provider down',
    );
    expect(
      const RelationshipChatTurnException(null).toString(),
      'The relationship-agent turn failed.',
    );
  });
}
