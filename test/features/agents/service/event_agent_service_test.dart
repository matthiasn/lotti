import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/event_agent_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService mockAgentService;
  late MockAgentRepository mockRepository;
  late MockWakeOrchestrator mockOrchestrator;
  late MockAgentSyncService mockSyncService;
  late EventAgentService service;
  late List<String> notifiedAgentIds;

  const eventId = 'event-1';

  AgentIdentityEntity makeIdentity({
    String agentId = 'agent-1',
    String kind = AgentKinds.eventAgent,
    AgentLifecycle lifecycle = AgentLifecycle.active,
  }) {
    return makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: kind,
      displayName: 'Event Agent',
      lifecycle: lifecycle,
      currentStateId: 'state-$agentId',
    );
  }

  AgentStateEntity makeState({
    String agentId = 'agent-1',
    String? activeEventId,
    bool awaitingContent = false,
    DateTime? nextWakeAt,
  }) {
    return makeTestState(
      id: 'state-$agentId',
      agentId: agentId,
      revision: 0,
      slots: AgentSlots(activeEventId: activeEventId),
      awaitingContent: awaitingContent,
      nextWakeAt: nextWakeAt,
    );
  }

  void stubCreateFlow({
    required AgentIdentityEntity identity,
    AgentTemplateKind templateKind = AgentTemplateKind.eventAgent,
    AgentStateEntity? state,
    bool duplicateExists = false,
  }) {
    when(
      () => mockRepository.getLinksTo(eventId, type: AgentLinkTypes.agentEvent),
    ).thenAnswer(
      (_) async => duplicateExists
          ? [makeTestAgentEventLink(fromId: 'other-agent', toId: eventId)]
          : <AgentLink>[],
    );
    when(
      () => mockRepository.getEntity(kTestTemplateId),
    ).thenAnswer((_) async => makeTestTemplate(kind: templateKind));
    when(
      () => mockAgentService.createAgent(
        kind: any(named: 'kind'),
        displayName: any(named: 'displayName'),
        config: any(named: 'config'),
        allowedCategoryIds: any(named: 'allowedCategoryIds'),
      ),
    ).thenAnswer((_) async => identity);
    when(
      () => mockRepository.getAgentState(identity.agentId),
    ).thenAnswer((_) async => state ?? makeState(agentId: identity.agentId));
  }

  setUp(() {
    mockAgentService = MockAgentService();
    mockRepository = MockAgentRepository();
    mockOrchestrator = MockWakeOrchestrator();
    mockSyncService = MockAgentSyncService();
    notifiedAgentIds = [];

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});
    when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
    when(
      () => mockOrchestrator.setAwaitingContent(
        any(),
        awaiting: any(named: 'awaiting'),
      ),
    ).thenReturn(null);
    when(
      () => mockOrchestrator.enqueueManualWake(
        agentId: any(named: 'agentId'),
        reason: any(named: 'reason'),
        triggerTokens: any(named: 'triggerTokens'),
      ),
    ).thenReturn(null);
    when(
      () => mockOrchestrator.restorePendingWake(
        agentId: any(named: 'agentId'),
        dueAt: any(named: 'dueAt'),
      ),
    ).thenReturn(null);
    when(() => mockAgentService.cancelPendingWake(any())).thenReturn(null);

    service = EventAgentService(
      agentService: mockAgentService,
      repository: mockRepository,
      orchestrator: mockOrchestrator,
      syncService: mockSyncService,
      domainLogger: DomainLogger(loggingService: LoggingService())
        ..enabledDomains.add(LogDomain.agentRuntime),
      onPersistedStateChanged: notifiedAgentIds.add,
    );
  });

  group('createEventAgent', () {
    test('creates the agent, writes the slot + content gate, links, '
        'subscription, and enqueues the creation wake', () async {
      final identity = makeIdentity();
      stubCreateFlow(identity: identity);

      final result = await service.createEventAgent(
        eventId: eventId,
        templateId: kTestTemplateId,
        displayName: 'Event Agent',
        allowedCategoryIds: {'cat-1'},
      );

      expect(result.agentId, 'agent-1');

      // createAgent is invoked with the event_agent kind.
      final createArgs = verify(
        () => mockAgentService.createAgent(
          kind: captureAny(named: 'kind'),
          displayName: captureAny(named: 'displayName'),
          config: captureAny(named: 'config'),
          allowedCategoryIds: captureAny(named: 'allowedCategoryIds'),
        ),
      ).captured;
      expect(createArgs[0], AgentKinds.eventAgent);
      expect(createArgs[1], 'Event Agent');
      expect(createArgs[2], const AgentConfig());
      expect(createArgs[3], {'cat-1'});

      // State carries the active event slot and the awaiting-content flag.
      final updatedState =
          verify(
                () => mockSyncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(updatedState.slots.activeEventId, eventId);
      expect(updatedState.awaitingContent, isTrue);

      // Two links: agent → event and template → agent.
      final links = verify(
        () => mockSyncService.upsertLink(captureAny()),
      ).captured;
      expect(links, hasLength(2));
      final eventLink = links.whereType<AgentEventLink>().single;
      expect(eventLink.fromId, 'agent-1');
      expect(eventLink.toId, eventId);
      final templateLink = links.whereType<TemplateAssignmentLink>().single;
      expect(templateLink.fromId, kTestTemplateId);
      expect(templateLink.toId, 'agent-1');

      // Direct-edit subscription on the event update token.
      final subscription =
          verify(
                () => mockOrchestrator.addSubscription(captureAny()),
              ).captured.single
              as AgentSubscription;
      expect(subscription.agentId, 'agent-1');
      expect(
        subscription.matchEntityIds,
        {eventId},
      );

      // Content gate mirrored + creation wake enqueued.
      verify(
        () => mockOrchestrator.setAwaitingContent('agent-1', awaiting: true),
      ).called(1);
      verify(
        () => mockOrchestrator.enqueueManualWake(
          agentId: 'agent-1',
          reason: 'creation',
          triggerTokens: {eventId},
        ),
      ).called(1);
      expect(notifiedAgentIds, ['agent-1']);
    });

    test('awaitContent: false attaches without the content gate', () async {
      final identity = makeIdentity();
      stubCreateFlow(identity: identity);

      await service.createEventAgent(
        eventId: eventId,
        templateId: kTestTemplateId,
        displayName: 'Event Agent',
        allowedCategoryIds: const {},
        awaitContent: false,
      );

      final updatedState =
          verify(
                () => mockSyncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(updatedState.awaitingContent, isFalse);
      verify(
        () => mockOrchestrator.setAwaitingContent('agent-1', awaiting: false),
      ).called(1);
    });

    test('throws and writes nothing when an agent already exists', () async {
      stubCreateFlow(identity: makeIdentity(), duplicateExists: true);

      await expectLater(
        () => service.createEventAgent(
          eventId: eventId,
          templateId: kTestTemplateId,
          displayName: 'Event Agent',
          allowedCategoryIds: const {},
        ),
        throwsA(isA<StateError>()),
      );

      verifyNever(
        () => mockAgentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      );
      verifyNever(() => mockSyncService.upsertEntity(any()));
      verifyNever(() => mockSyncService.upsertLink(any()));
      expect(notifiedAgentIds, isEmpty);
    });

    test(
      'throws before creating the agent for a wrong-kind template',
      () async {
        stubCreateFlow(
          identity: makeIdentity(),
          templateKind: AgentTemplateKind.projectAgent,
        );

        await expectLater(
          () => service.createEventAgent(
            eventId: eventId,
            templateId: kTestTemplateId,
            displayName: 'Event Agent',
            allowedCategoryIds: const {},
          ),
          throwsA(isA<StateError>()),
        );

        verifyNever(
          () => mockAgentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        );
      },
    );

    test('throws when the freshly created agent has no state', () async {
      final identity = makeIdentity();
      stubCreateFlow(identity: identity);
      when(
        () => mockRepository.getAgentState('agent-1'),
      ).thenAnswer((_) async => null);

      await expectLater(
        () => service.createEventAgent(
          eventId: eventId,
          templateId: kTestTemplateId,
          displayName: 'Event Agent',
          allowedCategoryIds: const {},
        ),
        throwsA(isA<StateError>()),
      );

      verify(
        () => mockAgentService.createAgent(
          kind: any(named: 'kind'),
          displayName: any(named: 'displayName'),
          config: any(named: 'config'),
          allowedCategoryIds: any(named: 'allowedCategoryIds'),
        ),
      ).called(1);
    });
  });

  group('getEventAgentForEvent', () {
    test('resolves the agent from the primary agent-event link', () async {
      final identity = makeIdentity();
      when(
        () =>
            mockRepository.getLinksTo(eventId, type: AgentLinkTypes.agentEvent),
      ).thenAnswer(
        (_) async => [makeTestAgentEventLink(fromId: 'agent-1', toId: eventId)],
      );
      when(
        () => mockAgentService.getAgent('agent-1'),
      ).thenAnswer((_) async => identity);

      final result = await service.getEventAgentForEvent(eventId);

      expect(result, same(identity));
    });

    test('returns null when no agent-event link exists', () async {
      when(
        () =>
            mockRepository.getLinksTo(eventId, type: AgentLinkTypes.agentEvent),
      ).thenAnswer((_) async => <AgentLink>[]);

      final result = await service.getEventAgentForEvent(eventId);

      expect(result, isNull);
      verifyNever(() => mockAgentService.getAgent(any()));
    });
  });

  group('manual controls', () {
    test('triggerReanalysis enqueues a reanalysis wake', () {
      service.triggerReanalysis('agent-1');

      verify(
        () => mockOrchestrator.enqueueManualWake(
          agentId: 'agent-1',
          reason: 'reanalysis',
        ),
      ).called(1);
    });

    test('cancelScheduledWake cancels the pending wake', () {
      service.cancelScheduledWake('agent-1');

      verify(() => mockAgentService.cancelPendingWake('agent-1')).called(1);
    });
  });

  group('restoreSubscriptions', () {
    test('re-registers subscriptions, mirrors the gate, and rehydrates the '
        'throttle deadline for event agents only', () async {
      final eventAgent = makeIdentity(agentId: 'agent-event');
      final taskAgent = makeIdentity(agentId: 'agent-task', kind: 'task_agent');
      final deadline = DateTime(2026, 3, 21, 6);

      when(
        () => mockAgentService.listAgents(lifecycle: AgentLifecycle.active),
      ).thenAnswer((_) async => [eventAgent, taskAgent]);
      when(
        () => mockRepository.getLinksFrom(
          'agent-event',
          type: AgentLinkTypes.agentEvent,
        ),
      ).thenAnswer(
        (_) async => [
          makeTestAgentEventLink(fromId: 'agent-event', toId: eventId),
        ],
      );
      when(() => mockRepository.getAgentState('agent-event')).thenAnswer(
        (_) async => makeState(
          agentId: 'agent-event',
          awaitingContent: true,
          nextWakeAt: deadline,
        ),
      );

      await service.restoreSubscriptions();

      // The non-event agent is skipped entirely.
      verifyNever(
        () => mockRepository.getLinksFrom(
          'agent-task',
          type: any(named: 'type'),
        ),
      );

      // Throttle deadline rehydrated, content gate mirrored, subscription set.
      verify(
        () => mockOrchestrator.restorePendingWake(
          agentId: 'agent-event',
          dueAt: deadline,
        ),
      ).called(1);
      verify(
        () =>
            mockOrchestrator.setAwaitingContent('agent-event', awaiting: true),
      ).called(1);
      final subscription =
          verify(
                () => mockOrchestrator.addSubscription(captureAny()),
              ).captured.single
              as AgentSubscription;
      expect(subscription.agentId, 'agent-event');
      expect(
        subscription.matchEntityIds,
        {eventId},
      );
    });
  });
}
