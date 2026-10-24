import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/front_agent/model/front_agent_identity.dart';
import 'package:lotti/features/front_agent/service/front_chat_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../agents/test_data/entity_factories.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService syncService;
  late MockAgentRepository repository;
  late MockWakeOrchestrator orchestrator;
  late MockUpdateNotifications notifications;
  late StreamController<WakeRunCompletion> completions;
  late List<AgentDomainEntity> upserts;
  late FrontChatService service;

  AgentIdentityEntity identity(AgentLifecycle lifecycle) => makeTestIdentity(
    id: frontAgentId,
    agentId: frontAgentId,
    kind: AgentKinds.frontAgent,
    lifecycle: lifecycle,
  );

  setUp(() {
    syncService = MockAgentSyncService();
    repository = MockAgentRepository();
    orchestrator = MockWakeOrchestrator();
    notifications = MockUpdateNotifications();
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

  test('an empty message persists nothing and wakes nothing', () async {
    await service.sendMessage(text: '   ');
    expect(upserts, isEmpty);
    verifyNever(() => repository.getEntity(any()));
  });

  test('refuses a turn when the front agent is not active', () async {
    when(
      () => repository.getEntity(frontAgentId),
    ).thenAnswer((_) async => identity(AgentLifecycle.dormant));

    await expectLater(
      service.sendMessage(text: 'Hello'),
      throwsA(isA<FrontChatTurnException>()),
    );
    expect(upserts, isEmpty);
  });

  test('persists the payload and the user turn, shows it, then runs the '
      'routing wake with the chat token', () async {
    stubWake(WakeRunStatus.completed);

    await service.sendMessage(text: '  Buy the hose  ');

    final payload = upserts.whereType<AgentMessagePayloadEntity>().single;
    final message = upserts.whereType<AgentMessageEntity>().single;
    expect(payload.content, {'text': 'Buy the hose'});
    expect(payload.agentId, frontAgentId);
    expect(message.kind, AgentMessageKind.user);
    expect(message.contentEntryId, payload.id);
    // The source turn is its own thread; the wake links back by token.
    expect(message.threadId, message.id);
    expect(message.metadata.runKey, isNull);
    verify(
      () => notifications.notifyUiOnly({frontAgentId, agentNotification}),
    ).called(1);
    verify(
      () => orchestrator.enqueueManualWake(
        agentId: frontAgentId,
        reason: WakeReason.userMessage.name,
        triggerTokens: {frontChatMessageTriggerToken(message.id)},
        supersede: false,
        initiator: WakeInitiator.user,
      ),
    ).called(1);
  });

  test(
    'a failed wake surfaces as a turn exception that names the message',
    () async {
      stubWake(WakeRunStatus.failed);

      Object? thrown;
      try {
        await service.sendMessage(text: 'Hello');
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
    },
  );

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

  test('an append that committed but failed its outbox flush is reconciled, '
      'not retried into a duplicate', () async {
    AgentMessageEntity? persisted;
    when(() => syncService.upsertEntity(any())).thenAnswer((invocation) async {
      final entity = invocation.positionalArguments.first as AgentDomainEntity;
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
    stubWake(WakeRunStatus.completed);

    await service.sendMessage(text: 'Hello');

    expect(upserts.whereType<AgentMessageEntity>(), hasLength(1));
    verify(
      () => orchestrator.enqueueManualWake(
        agentId: frontAgentId,
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
        supersede: any(named: 'supersede'),
        initiator: any(named: 'initiator'),
      ),
    ).called(1);
  });
}
