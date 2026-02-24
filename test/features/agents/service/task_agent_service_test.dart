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
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentService mockAgentService;
  late MockAgentRepository mockRepository;
  late MockWakeOrchestrator mockOrchestrator;
  late MockAgentSyncService mockSyncService;
  late TaskAgentService service;

  AgentIdentityEntity makeIdentity({
    String agentId = 'agent-1',
    String kind = 'task_agent',
    String displayName = 'Task Agent',
    AgentLifecycle lifecycle = AgentLifecycle.active,
  }) {
    return makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: kind,
      displayName: displayName,
      lifecycle: lifecycle,
      currentStateId: 'state-$agentId',
    );
  }

  AgentStateEntity makeState({
    String id = 'state-agent-1',
    String agentId = 'agent-1',
    String? activeTaskId,
  }) {
    return makeTestState(
      id: id,
      agentId: agentId,
      revision: 0,
      slots: AgentSlots(activeTaskId: activeTaskId),
    );
  }

  setUp(() {
    mockAgentService = MockAgentService();
    mockRepository = MockAgentRepository();
    mockOrchestrator = MockWakeOrchestrator();
    mockSyncService = MockAgentSyncService();

    // Stub syncService write methods
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});

    // Stub template existence for all tests that provide kTestTemplateId.
    when(() => mockRepository.getEntity(kTestTemplateId))
        .thenAnswer((_) async => makeTestTemplate());

    service = TaskAgentService(
      agentService: mockAgentService,
      repository: mockRepository,
      orchestrator: mockOrchestrator,
      syncService: mockSyncService,
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

        // syncService stubs set up in setUp
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
        when(
          () => mockOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn(null);

        final result = await service.createTaskAgent(
          taskId: 'task-1',
          templateId: kTestTemplateId,
          allowedCategoryIds: {'cat-1'},
          displayName: 'My Task Agent',
        );

        expect(result, isA<AgentIdentityEntity>());
        expect(result.agentId, 'agent-1');

        // Verify state was updated with activeTaskId
        final stateCalls = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updatedState = stateCalls.first as AgentStateEntity;
        expect(updatedState.slots.activeTaskId, 'task-1');

        // Verify agent_task and template_assignment links were created
        final linkCalls = verify(
          () => mockSyncService.upsertLink(captureAny()),
        ).captured;
        expect(linkCalls, hasLength(2));
        final taskLink = linkCalls.whereType<AgentTaskLink>().single;
        expect(taskLink.fromId, 'agent-1');
        expect(taskLink.toId, 'task-1');
        final templateLink =
            linkCalls.whereType<TemplateAssignmentLink>().single;
        expect(templateLink.fromId, kTestTemplateId);
        expect(templateLink.toId, 'agent-1');

        // Verify subscription was registered
        final subCalls = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured;
        final sub = subCalls.first as AgentSubscription;
        expect(sub.agentId, 'agent-1');
        expect(sub.matchEntityIds, contains('task-1'));
        expect(sub.id, 'agent-1_task_task-1');

        // Verify initial wake was enqueued
        verify(
          () => mockOrchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'task-1'},
          ),
        ).called(1);
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
        // syncService stubs set up in setUp
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
        when(
          () => mockOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn(null);

        await service.createTaskAgent(
          taskId: 'task-2',
          templateId: kTestTemplateId,
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
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        // The in-transaction duplicate check finds an existing link.
        when(() => mockRepository.getLinksTo('task-1', type: 'agent_task'))
            .thenAnswer((_) async => [existingLink]);

        expect(
          () => service.createTaskAgent(
            taskId: 'task-1',
            templateId: kTestTemplateId,
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

      test('throws StateError from in-transaction check when duplicate exists',
          () async {
        final concurrentLink = AgentLink.agentTask(
          id: 'link-race',
          fromId: 'racing-agent',
          toId: 'task-race',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        // The in-transaction check finds a duplicate link.
        when(() => mockRepository.getLinksTo('task-race', type: 'agent_task'))
            .thenAnswer((_) async => [concurrentLink]);

        expect(
          () => service.createTaskAgent(
            taskId: 'task-race',
            templateId: kTestTemplateId,
            allowedCategoryIds: const {},
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('task-race'), contains('racing-agent')),
            ),
          ),
        );
      });

      test('throws StateError when agent state is null', () async {
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

        expect(
          () => service.createTaskAgent(
            taskId: 'task-3',
            templateId: kTestTemplateId,
            allowedCategoryIds: const {},
          ),
          throwsStateError,
        );
      });
    });

    group('getTaskAgentForTask', () {
      test('returns identity via link lookup', () async {
        final link = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'task-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
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
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
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
      test('enqueues a manual wake with reason reanalysis', () {
        when(
          () => mockOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn(null);

        service.triggerReanalysis('agent-1');

        verify(
          () => mockOrchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'reanalysis',
          ),
        ).called(1);
      });
    });

    group('restoreSubscriptionsForAgent', () {
      test('registers subscriptions for a single agent', () async {
        final link1 = AgentLink.agentTask(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'task-10',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final link2 = AgentLink.agentTask(
          id: 'link-2',
          fromId: 'agent-1',
          toId: 'task-20',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        when(
          () => mockRepository.getLinksFrom('agent-1', type: 'agent_task'),
        ).thenAnswer((_) async => [link1, link2]);
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        await service.restoreSubscriptionsForAgent('agent-1');

        final captured = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured.cast<AgentSubscription>();

        expect(captured, hasLength(2));
        expect(captured[0].matchEntityIds, contains('task-10'));
        expect(captured[1].matchEntityIds, contains('task-20'));
      });

      test('handles no links gracefully', () async {
        when(
          () => mockRepository.getLinksFrom('agent-1', type: 'agent_task'),
        ).thenAnswer((_) async => []);
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        await service.restoreSubscriptionsForAgent('agent-1');

        verifyNever(() => mockOrchestrator.addSubscription(any()));
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
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final link2 = AgentLink.agentTask(
          id: 'link-2',
          fromId: 'ta-1',
          toId: 'task-20',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
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

      test('catches getLinksFrom error and continues to next agent', () async {
        final failingAgent = makeIdentity(agentId: 'ta-fail');
        final okAgent = makeIdentity(agentId: 'ta-ok');

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [failingAgent, okAgent]);

        // First agent's link lookup throws.
        when(() => mockRepository.getLinksFrom('ta-fail', type: 'agent_task'))
            .thenThrow(Exception('DB error'));

        // Second agent's link lookup succeeds.
        final link = AgentLink.agentTask(
          id: 'link-ok',
          fromId: 'ta-ok',
          toId: 'task-ok',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        when(() => mockRepository.getLinksFrom('ta-ok', type: 'agent_task'))
            .thenAnswer((_) async => [link]);
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        // Should not throw — error is caught internally.
        await service.restoreSubscriptions();

        // The second agent's subscription should still be registered.
        final captured = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final sub = captured.first as AgentSubscription;
        expect(sub.agentId, 'ta-ok');
        expect(sub.matchEntityIds, contains('task-ok'));
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

    group('syncService routing', () {
      test('routes entity and link writes through syncService', () async {
        final identity = makeIdentity();

        when(() => mockRepository.getLinksTo('task-sync', type: 'agent_task'))
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
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
        when(
          () => mockOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn(null);

        await service.createTaskAgent(
          taskId: 'task-sync',
          templateId: kTestTemplateId,
          allowedCategoryIds: {'cat-1'},
        );

        // Entity and link writes go through syncService, not repository.
        // 1 entity (state update) + 2 links (agent_task + template_assignment).
        verify(() => mockSyncService.upsertEntity(any())).called(1);
        verify(() => mockSyncService.upsertLink(any())).called(2);
        verifyNever(() => mockRepository.upsertEntity(any()));
        verifyNever(() => mockRepository.upsertLink(any()));
      });
    });

    group('default template resolution', () {
      test('resolves first available template when templateId is null',
          () async {
        final identity = makeIdentity();
        final template = makeTestTemplate();

        when(() => mockRepository.getLinksTo('task-dt', type: 'agent_task'))
            .thenAnswer((_) async => []);
        when(() => mockRepository.getAllTemplates())
            .thenAnswer((_) async => [template]);
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
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
        when(
          () => mockOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn(null);

        final result = await service.createTaskAgent(
          taskId: 'task-dt',
          allowedCategoryIds: const {},
        );

        expect(result, isA<AgentIdentityEntity>());

        // Verify the template_assignment link uses the resolved template ID.
        final linkCalls = verify(
          () => mockSyncService.upsertLink(captureAny()),
        ).captured;
        final templateLink =
            linkCalls.whereType<TemplateAssignmentLink>().single;
        expect(templateLink.fromId, kTestTemplateId);
      });

      test('throws StateError when provided templateId does not exist',
          () async {
        when(() => mockRepository.getEntity('nonexistent-template'))
            .thenAnswer((_) async => null);

        expect(
          () => service.createTaskAgent(
            taskId: 'task-bad-tpl',
            templateId: 'nonexistent-template',
            allowedCategoryIds: const {},
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('nonexistent-template'),
            ),
          ),
        );
      });

      test('throws StateError when templateId points to non-template entity',
          () async {
        // Return a version entity instead of a template entity.
        when(() => mockRepository.getEntity('version-entity')).thenAnswer(
            (_) async => makeTestTemplateVersion(id: 'version-entity'));

        expect(
          () => service.createTaskAgent(
            taskId: 'task-wrong-type',
            templateId: 'version-entity',
            allowedCategoryIds: const {},
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('version-entity'),
            ),
          ),
        );
      });

      test('throws StateError when no templates available and none provided',
          () async {
        when(() => mockRepository.getLinksTo('task-nt', type: 'agent_task'))
            .thenAnswer((_) async => []);
        when(() => mockAgentService.getAgent(any()))
            .thenAnswer((_) async => null);
        when(() => mockRepository.getAllTemplates())
            .thenAnswer((_) async => []);

        expect(
          () => service.createTaskAgent(
            taskId: 'task-nt',
            allowedCategoryIds: const {},
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('No template available'),
            ),
          ),
        );
      });
    });
  });
}
