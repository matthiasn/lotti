import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/task_agent_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';

void main() {
  setUpAll(() {
    registerAllFallbackValues();
    registerFallbackValue(
      AgentSubscription(
        id: 'fallback-sub',
        agentId: 'fallback-agent',
        matchEntityIds: const {},
      ),
    );
    registerFallbackValue(const AgentConfig());
    registerFallbackValue(<String>{});
  });

  late MockAgentService mockAgentService;
  late MockAgentRepository mockRepository;
  late MockWakeOrchestrator mockOrchestrator;
  late TaskAgentService service;

  final testDate = DateTime(2024, 3, 15);

  AgentIdentityEntity makeIdentity({
    String agentId = 'agent-1',
    String kind = 'task_agent',
    String displayName = 'Task Agent',
    AgentLifecycle lifecycle = AgentLifecycle.active,
  }) {
    return AgentDomainEntity.agent(
      id: agentId,
      agentId: agentId,
      kind: kind,
      displayName: displayName,
      lifecycle: lifecycle,
      mode: AgentInteractionMode.autonomous,
      allowedCategoryIds: const {},
      currentStateId: 'state-$agentId',
      config: const AgentConfig(),
      createdAt: testDate,
      updatedAt: testDate,
      vectorClock: null,
    ) as AgentIdentityEntity;
  }

  AgentStateEntity makeState({
    String id = 'state-agent-1',
    String agentId = 'agent-1',
    String? activeTaskId,
  }) {
    return AgentDomainEntity.agentState(
      id: id,
      agentId: agentId,
      revision: 0,
      slots: AgentSlots(activeTaskId: activeTaskId),
      updatedAt: testDate,
      vectorClock: null,
    ) as AgentStateEntity;
  }

  setUp(() {
    mockAgentService = MockAgentService();
    mockRepository = MockAgentRepository();
    mockOrchestrator = MockWakeOrchestrator();
    service = TaskAgentService(
      agentService: mockAgentService,
      repository: mockRepository,
      orchestrator: mockOrchestrator,
    );
  });

  group('TaskAgentService', () {
    group('createTaskAgent', () {
      test(
          'creates agent via service, updates state, creates link, '
          'and registers subscription', () async {
        final identity = makeIdentity();

        // No existing agent for this task
        when(() => mockRepository.getLinksTo('task-1', type: 'agent_task'))
            .thenAnswer((_) async => []);

        // Agent creation
        when(
          () => mockAgentService.createAgent(
            kind: 'task_agent',
            displayName: 'My Task Agent',
            config: const AgentConfig(),
            allowedCategoryIds: {'cat-1'},
          ),
        ).thenAnswer((_) async => identity);

        // State fetch
        final state = makeState();
        when(() => mockRepository.getAgentState('agent-1'))
            .thenAnswer((_) async => state);

        // State and link upsert
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
        when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        final result = await service.createTaskAgent(
          taskId: 'task-1',
          allowedCategoryIds: {'cat-1'},
          displayName: 'My Task Agent',
        );

        expect(result, isA<AgentIdentityEntity>());
        expect(result.agentId, 'agent-1');

        // Verify state was updated with activeTaskId
        final stateCalls = verify(
          () => mockRepository.upsertEntity(captureAny()),
        ).captured;
        final updatedState = stateCalls.first as AgentStateEntity;
        expect(updatedState.slots.activeTaskId, 'task-1');

        // Verify agent_task link was created
        final linkCalls = verify(
          () => mockRepository.upsertLink(captureAny()),
        ).captured;
        final link = linkCalls.first as AgentTaskLink;
        expect(link.fromId, 'agent-1');
        expect(link.toId, 'task-1');

        // Verify subscription was registered
        final subCalls = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured;
        final sub = subCalls.first as AgentSubscription;
        expect(sub.agentId, 'agent-1');
        expect(sub.matchEntityIds, contains('task-1'));
        expect(sub.id, 'agent-1_task_task-1');
      });

      test('uses default display name when none provided', () async {
        final identity = makeIdentity();

        when(() => mockRepository.getLinksTo('task-2', type: 'agent_task'))
            .thenAnswer((_) async => []);
        when(
          () => mockAgentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer((_) async => identity);
        when(() => mockRepository.getAgentState('agent-1'))
            .thenAnswer((_) async => makeState());
        when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
        when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        await service.createTaskAgent(
          taskId: 'task-2',
          allowedCategoryIds: const {},
        );

        verify(
          () => mockAgentService.createAgent(
            kind: 'task_agent',
            displayName: 'Task Agent',
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).called(1);
      });

      test('throws StateError if agent already exists for task', () async {
        final existingLink = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'existing-agent',
          toId: 'task-1',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(() => mockRepository.getLinksTo('task-1', type: 'agent_task'))
            .thenAnswer((_) async => [existingLink]);
        when(() => mockAgentService.getAgent('existing-agent'))
            .thenAnswer((_) async => makeIdentity(agentId: 'existing-agent'));

        expect(
          () => service.createTaskAgent(
            taskId: 'task-1',
            allowedCategoryIds: const {},
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('task-1'),
            ),
          ),
        );
      });

      test('handles null state gracefully (skips state update)', () async {
        final identity = makeIdentity();

        when(() => mockRepository.getLinksTo('task-3', type: 'agent_task'))
            .thenAnswer((_) async => []);
        when(
          () => mockAgentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer((_) async => identity);
        when(() => mockRepository.getAgentState('agent-1'))
            .thenAnswer((_) async => null);
        when(() => mockRepository.upsertLink(any())).thenAnswer((_) async {});
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        final result = await service.createTaskAgent(
          taskId: 'task-3',
          allowedCategoryIds: const {},
        );

        expect(result.agentId, 'agent-1');

        // State upsert should NOT be called when state is null
        verifyNever(() => mockRepository.upsertEntity(any()));

        // Link should still be created
        verify(() => mockRepository.upsertLink(any())).called(1);
      });
    });

    group('getTaskAgentForTask', () {
      test('returns identity via link lookup', () async {
        final link = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'task-1',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        final identity = makeIdentity();

        when(() => mockRepository.getLinksTo('task-1', type: 'agent_task'))
            .thenAnswer((_) async => [link]);
        when(() => mockAgentService.getAgent('agent-1'))
            .thenAnswer((_) async => identity);

        final result = await service.getTaskAgentForTask('task-1');

        expect(result, isNotNull);
        expect(result!.agentId, 'agent-1');
        verify(() => mockRepository.getLinksTo('task-1', type: 'agent_task'))
            .called(1);
        verify(() => mockAgentService.getAgent('agent-1')).called(1);
      });

      test('returns null when no link exists', () async {
        when(() => mockRepository.getLinksTo('task-99', type: 'agent_task'))
            .thenAnswer((_) async => []);

        final result = await service.getTaskAgentForTask('task-99');

        expect(result, isNull);
        verifyNever(() => mockAgentService.getAgent(any()));
      });

      test('returns null when link exists but agent is not found', () async {
        final link = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'ghost-agent',
          toId: 'task-1',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(() => mockRepository.getLinksTo('task-1', type: 'agent_task'))
            .thenAnswer((_) async => [link]);
        when(() => mockAgentService.getAgent('ghost-agent'))
            .thenAnswer((_) async => null);

        final result = await service.getTaskAgentForTask('task-1');

        expect(result, isNull);
      });
    });

    group('triggerReanalysis', () {
      test('completes without throwing (MVP stub)', () {
        // Should not throw or crash
        expect(
          () => service.triggerReanalysis('agent-1'),
          returnsNormally,
        );
      });
    });

    group('restoreSubscriptions', () {
      test('registers subscriptions for active task agents', () async {
        final taskAgent = makeIdentity(agentId: 'ta-1');
        final otherAgent = makeIdentity(
          agentId: 'other-1',
          kind: 'summary_agent',
        );

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [taskAgent, otherAgent]);

        final link1 = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'ta-1',
          toId: 'task-10',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );
        final link2 = AgentLink.agentTask(
          id: 'link-2',
          fromId: 'ta-1',
          toId: 'task-20',
          createdAt: testDate,
          updatedAt: testDate,
          vectorClock: null,
        );

        when(() => mockRepository.getLinksFrom('ta-1', type: 'agent_task'))
            .thenAnswer((_) async => [link1, link2]);

        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        await service.restoreSubscriptions();

        // Verify addSubscription called twice (once per link)
        final captured = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured;

        expect(captured, hasLength(2));

        final sub1 = captured[0] as AgentSubscription;
        expect(sub1.agentId, 'ta-1');
        expect(sub1.matchEntityIds, contains('task-10'));
        expect(sub1.id, 'ta-1_task_task-10');

        final sub2 = captured[1] as AgentSubscription;
        expect(sub2.agentId, 'ta-1');
        expect(sub2.matchEntityIds, contains('task-20'));
        expect(sub2.id, 'ta-1_task_task-20');

        // Verify getLinksFrom was NOT called for the non-task agent
        verifyNever(
          () => mockRepository.getLinksFrom('other-1', type: 'agent_task'),
        );
      });

      test('skips non-task_agent agents', () async {
        final summaryAgent = makeIdentity(
          agentId: 'summary-1',
          kind: 'summary_agent',
        );
        final reviewAgent = makeIdentity(
          agentId: 'review-1',
          kind: 'review_agent',
        );

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [summaryAgent, reviewAgent]);

        await service.restoreSubscriptions();

        // No links should be fetched for non-task agents
        verifyNever(
            () => mockRepository.getLinksFrom(any(), type: any(named: 'type')));
        // No subscriptions should be registered
        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });

      test('handles empty agent list gracefully', () async {
        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => []);

        await service.restoreSubscriptions();

        verifyNever(
            () => mockRepository.getLinksFrom(any(), type: any(named: 'type')));
        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });
    });
  });
}
