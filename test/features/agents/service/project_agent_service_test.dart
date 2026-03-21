import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/services/db_notification.dart';
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
  late ProjectAgentService service;

  AgentIdentityEntity makeIdentity({
    String agentId = 'agent-1',
    String kind = 'project_agent',
    String displayName = 'Project Agent',
    AgentLifecycle lifecycle = AgentLifecycle.active,
    Set<String> allowedCategoryIds = const {},
  }) {
    return makeTestIdentity(
      id: agentId,
      agentId: agentId,
      kind: kind,
      displayName: displayName,
      lifecycle: lifecycle,
      allowedCategoryIds: allowedCategoryIds,
      currentStateId: 'state-$agentId',
    );
  }

  AgentStateEntity makeState({
    String id = 'state-agent-1',
    String agentId = 'agent-1',
    String? activeProjectId,
  }) {
    return makeTestState(
      id: id,
      agentId: agentId,
      revision: 0,
      slots: AgentSlots(activeProjectId: activeProjectId),
    );
  }

  setUp(() {
    mockAgentService = MockAgentService();
    mockRepository = MockAgentRepository();
    mockOrchestrator = MockWakeOrchestrator();
    mockSyncService = MockAgentSyncService();

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});

    service = ProjectAgentService(
      agentService: mockAgentService,
      repository: mockRepository,
      orchestrator: mockOrchestrator,
      syncService: mockSyncService,
      domainLogger: DomainLogger(loggingService: LoggingService())
        ..enabledDomains.add(LogDomains.agentRuntime),
    );
  });

  group('ProjectAgentService', () {
    group('createProjectAgent', () {
      test('creates agent, updates state, creates link, and registers '
          'subscription', () async {
        final identity = makeIdentity();
        final template = makeTestTemplate(
          kind: AgentTemplateKind.projectAgent,
        );

        when(
          () => mockRepository.getLinksTo(
            'project-1',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getEntity(kTestTemplateId),
        ).thenAnswer((_) async => template);

        when(
          () => mockAgentService.createAgent(
            kind: 'project_agent',
            displayName: 'My Project Agent',
            config: const AgentConfig(),
            allowedCategoryIds: {'cat-1'},
          ),
        ).thenAnswer((_) async => identity);

        final state = makeState();
        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => state);

        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
        when(
          () => mockOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn(null);

        final result = await service.createProjectAgent(
          projectId: 'project-1',
          templateId: kTestTemplateId,
          allowedCategoryIds: {'cat-1'},
          displayName: 'My Project Agent',
        );

        expect(result, isA<AgentIdentityEntity>());
        expect(result.agentId, 'agent-1');

        // Verify state was updated with activeProjectId.
        final stateCalls = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured;
        final updatedState = stateCalls.first as AgentStateEntity;
        expect(updatedState.slots.activeProjectId, 'project-1');

        // Verify both links were created (project + template).
        final linkCalls = verify(
          () => mockSyncService.upsertLink(captureAny()),
        ).captured;
        expect(linkCalls, hasLength(2));
        final projectLink = linkCalls.whereType<AgentProjectLink>().single;
        expect(projectLink.fromId, 'agent-1');
        expect(projectLink.toId, 'project-1');

        // Verify subscription was registered.
        final subCalls = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured;
        final sub = subCalls.first as AgentSubscription;
        expect(sub.agentId, 'agent-1');
        expect(
          sub.matchEntityIds,
          equals({
            projectAgentProjectChangedToken('project-1'),
            projectAgentTaskStatusChangedToken('project-1'),
            projectAgentDayPlanAgreedToken('cat-1'),
          }),
        );
        expect(sub.id, 'agent-1_project_project-1');

        // Verify creation wake was enqueued.
        verify(
          () => mockOrchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'project-1'},
          ),
        ).called(1);
      });

      test(
        'initializes the next daily digest at 06:00 on the next day',
        () async {
          final identity = makeIdentity();
          final template = makeTestTemplate(
            kind: AgentTemplateKind.projectAgent,
          );
          final testDate = DateTime(2026, 3, 20, 14, 30);

          when(
            () => mockRepository.getLinksTo(
              'project-daily',
              type: 'agent_project',
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockRepository.getEntity(kTestTemplateId),
          ).thenAnswer((_) async => template);
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => makeState());
          when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
          when(
            () => mockOrchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          ).thenReturn(null);

          await withClock(Clock.fixed(testDate), () async {
            await service.createProjectAgent(
              projectId: 'project-daily',
              templateId: kTestTemplateId,
              displayName: 'Daily Digest Agent',
              allowedCategoryIds: const {},
            );
          });

          final stateCalls = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final updatedState = stateCalls.first as AgentStateEntity;
          expect(updatedState.scheduledWakeAt, DateTime(2026, 3, 21, 6));
        },
      );

      test(
        'initializes the weekly review when it is sooner than the next daily digest',
        () async {
          final identity = makeIdentity();
          final template = makeTestTemplate(
            kind: AgentTemplateKind.projectAgent,
          );
          final testDate = DateTime(2026, 3, 23, 8);

          when(
            () => mockRepository.getLinksTo(
              'project-weekly',
              type: 'agent_project',
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockRepository.getEntity(kTestTemplateId),
          ).thenAnswer((_) async => template);
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => makeState());
          when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
          when(
            () => mockOrchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          ).thenReturn(null);

          await withClock(Clock.fixed(testDate), () async {
            await service.createProjectAgent(
              projectId: 'project-weekly',
              templateId: kTestTemplateId,
              displayName: 'Weekly Review Agent',
              allowedCategoryIds: const {},
            );
          });

          final stateCalls = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured;
          final updatedState = stateCalls.first as AgentStateEntity;
          expect(updatedState.scheduledWakeAt, DateTime(2026, 3, 23, 10));
        },
      );

      test(
        'creates template_assignment link when templateId provided',
        () async {
          final identity = makeIdentity();
          final template = makeTestTemplate(
            kind: AgentTemplateKind.projectAgent,
          );

          when(
            () => mockRepository.getLinksTo(
              'project-tpl',
              type: 'agent_project',
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockRepository.getEntity(kTestTemplateId),
          ).thenAnswer((_) async => template);
          when(
            () => mockAgentService.createAgent(
              kind: any(named: 'kind'),
              displayName: any(named: 'displayName'),
              config: any(named: 'config'),
              allowedCategoryIds: any(named: 'allowedCategoryIds'),
            ),
          ).thenAnswer((_) async => identity);
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => makeState());
          when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
          when(
            () => mockOrchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          ).thenReturn(null);

          await service.createProjectAgent(
            projectId: 'project-tpl',
            templateId: kTestTemplateId,
            displayName: 'Project Agent',
            allowedCategoryIds: const {},
          );

          final linkCalls = verify(
            () => mockSyncService.upsertLink(captureAny()),
          ).captured;
          expect(linkCalls, hasLength(2));
          final projectLink = linkCalls.whereType<AgentProjectLink>().single;
          expect(projectLink.toId, 'project-tpl');
          final templateLink = linkCalls
              .whereType<TemplateAssignmentLink>()
              .single;
          expect(templateLink.fromId, kTestTemplateId);
          expect(templateLink.toId, 'agent-1');
        },
      );

      test('passes display name to agent service', () async {
        final identity = makeIdentity();
        final template = makeTestTemplate(
          kind: AgentTemplateKind.projectAgent,
        );

        when(
          () => mockRepository.getLinksTo(
            'project-2',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getEntity(kTestTemplateId),
        ).thenAnswer((_) async => template);
        when(
          () => mockAgentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer((_) async => identity);
        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => makeState());
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
        when(
          () => mockOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn(null);

        await service.createProjectAgent(
          projectId: 'project-2',
          templateId: kTestTemplateId,
          displayName: 'Custom Agent Name',
          allowedCategoryIds: const {},
        );

        verify(
          () => mockAgentService.createAgent(
            kind: 'project_agent',
            displayName: 'Custom Agent Name',
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).called(1);
      });

      test('throws StateError if agent already exists for project', () async {
        final existingLink = AgentLink.agentProject(
          id: 'link-1',
          fromId: 'existing-agent',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        when(
          () => mockRepository.getLinksTo(
            'project-1',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => [existingLink]);

        expect(
          () => service.createProjectAgent(
            projectId: 'project-1',
            templateId: kTestTemplateId,
            displayName: 'Project Agent',
            allowedCategoryIds: const {},
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('project-1'),
            ),
          ),
        );
      });

      test('throws StateError when agent state is null', () async {
        final identity = makeIdentity();
        final template = makeTestTemplate(
          kind: AgentTemplateKind.projectAgent,
        );

        when(
          () => mockRepository.getLinksTo(
            'project-3',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getEntity(kTestTemplateId),
        ).thenAnswer((_) async => template);
        when(
          () => mockAgentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer((_) async => identity);
        when(
          () => mockRepository.getAgentState('agent-1'),
        ).thenAnswer((_) async => null);

        expect(
          () => service.createProjectAgent(
            projectId: 'project-3',
            templateId: kTestTemplateId,
            displayName: 'Project Agent',
            allowedCategoryIds: const {},
          ),
          throwsStateError,
        );
      });

      test('throws StateError when templateId does not exist', () async {
        when(
          () => mockRepository.getLinksTo(
            'project-bad-tpl',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getEntity('nonexistent-template'),
        ).thenAnswer((_) async => null);

        expect(
          () => service.createProjectAgent(
            projectId: 'project-bad-tpl',
            templateId: 'nonexistent-template',
            displayName: 'Project Agent',
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

      test(
        'throws StateError when template is not a project-agent kind',
        () async {
          final taskTemplate = makeTestTemplate(
            id: 'task-template-1',
            // ignore: avoid_redundant_argument_values
            kind: AgentTemplateKind.taskAgent,
          );

          when(
            () => mockRepository.getLinksTo(
              'project-wrong-kind',
              type: 'agent_project',
            ),
          ).thenAnswer((_) async => []);
          when(
            () => mockRepository.getEntity('task-template-1'),
          ).thenAnswer((_) async => taskTemplate);

          expect(
            () => service.createProjectAgent(
              projectId: 'project-wrong-kind',
              templateId: 'task-template-1',
              displayName: 'Project Agent',
              allowedCategoryIds: const {},
            ),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('task-template-1'),
              ),
            ),
          );
        },
      );
    });

    group('getProjectAgentForProject', () {
      test('returns identity via link lookup', () async {
        final link = AgentLink.agentProject(
          id: 'link-1',
          fromId: 'agent-1',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final identity = makeIdentity();

        when(
          () => mockRepository.getLinksTo(
            'project-1',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => mockAgentService.getAgent('agent-1'),
        ).thenAnswer((_) async => identity);

        final result = await service.getProjectAgentForProject('project-1');

        expect(result, isNotNull);
        expect(result!.agentId, 'agent-1');
      });

      test('returns null when no link exists', () async {
        when(
          () => mockRepository.getLinksTo(
            'project-99',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => []);

        final result = await service.getProjectAgentForProject('project-99');

        expect(result, isNull);
        verifyNever(() => mockAgentService.getAgent(any()));
      });

      test('returns null when link exists but agent is not found', () async {
        final link = AgentLink.agentProject(
          id: 'link-1',
          fromId: 'ghost-agent',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        when(
          () => mockRepository.getLinksTo(
            'project-1',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => mockAgentService.getAgent('ghost-agent'),
        ).thenAnswer((_) async => null);

        final result = await service.getProjectAgentForProject('project-1');

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

    group('restoreSubscriptions', () {
      test('registers subscriptions for active project agents', () async {
        final projectAgent = makeIdentity(
          agentId: 'pa-1',
          allowedCategoryIds: {'cat-1'},
        );
        final otherAgent = makeIdentity(
          agentId: 'other-1',
          kind: 'task_agent',
        );

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [projectAgent, otherAgent]);

        final link = AgentLink.agentProject(
          id: 'link-1',
          fromId: 'pa-1',
          toId: 'project-10',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );

        when(
          () => mockRepository.getLinksFrom(
            'pa-1',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => mockRepository.getAgentState('pa-1'),
        ).thenAnswer((_) async => null);
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        await service.restoreSubscriptions();

        final captured = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured.cast<AgentSubscription>();

        expect(captured, hasLength(1));
        expect(captured.first.agentId, 'pa-1');
        expect(
          captured.first.matchEntityIds,
          equals({
            projectAgentProjectChangedToken('project-10'),
            projectAgentTaskStatusChangedToken('project-10'),
            projectAgentDayPlanAgreedToken('cat-1'),
          }),
        );
        expect(captured.first.id, 'pa-1_project_project-10');

        // Verify getLinksFrom was NOT called for the non-project agent.
        verifyNever(
          () => mockRepository.getLinksFrom(
            'other-1',
            type: 'agent_project',
          ),
        );
      });

      test('skips non-project_agent agents', () async {
        final taskAgent = makeIdentity(
          agentId: 'ta-1',
          kind: 'task_agent',
        );

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [taskAgent]);

        await service.restoreSubscriptions();

        verifyNever(
          () => mockRepository.getLinksFrom(
            any(),
            type: any(named: 'type'),
          ),
        );
        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });

      test('hydrates throttle deadline from persisted state', () async {
        final projectAgent = makeIdentity(agentId: 'pa-2');
        final futureDeadline = DateTime(2026, 3, 15, 12, 5);
        final stateWithDeadline = makeTestState(
          id: 'state-pa-2',
          agentId: 'pa-2',
        ).copyWith(nextWakeAt: futureDeadline);

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [projectAgent]);
        when(
          () => mockRepository.getLinksFrom(
            'pa-2',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => []);
        when(
          () => mockRepository.getAgentState('pa-2'),
        ).thenAnswer((_) async => stateWithDeadline);
        when(
          () => mockOrchestrator.setThrottleDeadline(any(), any()),
        ).thenReturn(null);

        await service.restoreSubscriptions();

        verify(
          () => mockOrchestrator.setThrottleDeadline(
            'pa-2',
            futureDeadline,
          ),
        ).called(1);
      });

      test('catches error and continues to next agent', () async {
        final failingAgent = makeIdentity(agentId: 'pa-fail');
        final okAgent = makeIdentity(agentId: 'pa-ok');

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [failingAgent, okAgent]);

        when(
          () => mockRepository.getLinksFrom(
            'pa-fail',
            type: 'agent_project',
          ),
        ).thenThrow(Exception('DB error'));

        final link = AgentLink.agentProject(
          id: 'link-ok',
          fromId: 'pa-ok',
          toId: 'project-ok',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        when(
          () => mockRepository.getLinksFrom(
            'pa-ok',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => [link]);
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
        when(
          () => mockRepository.getAgentState('pa-ok'),
        ).thenAnswer((_) async => null);

        await service.restoreSubscriptions();

        final captured = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final sub = captured.first as AgentSubscription;
        expect(sub.agentId, 'pa-ok');
      });

      test('restores only primary link when multiple links exist', () async {
        final projectAgent = makeIdentity(agentId: 'pa-multi');

        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [projectAgent]);

        final olderLink = AgentLink.agentProject(
          id: 'link-old',
          fromId: 'pa-multi',
          toId: 'project-old',
          createdAt: DateTime(2026, 1, 10),
          updatedAt: DateTime(2026, 1, 10),
          vectorClock: null,
        );
        final newerLink = AgentLink.agentProject(
          id: 'link-new',
          fromId: 'pa-multi',
          toId: 'project-new',
          createdAt: DateTime(2026, 3, 15),
          updatedAt: DateTime(2026, 3, 15),
          vectorClock: null,
        );

        when(
          () => mockRepository.getLinksFrom(
            'pa-multi',
            type: 'agent_project',
          ),
        ).thenAnswer((_) async => [olderLink, newerLink]);
        when(
          () => mockRepository.getAgentState('pa-multi'),
        ).thenAnswer((_) async => null);
        when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);

        await service.restoreSubscriptions();

        final captured = verify(
          () => mockOrchestrator.addSubscription(captureAny()),
        ).captured.cast<AgentSubscription>();

        // Only the primary (newest) link should be registered.
        expect(captured, hasLength(1));
        expect(
          captured.first.matchEntityIds,
          contains(projectAgentProjectChangedToken('project-new')),
        );
      });

      test('handles empty agent list gracefully', () async {
        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => []);

        await service.restoreSubscriptions();

        verifyNever(
          () => mockRepository.getLinksFrom(
            any(),
            type: any(named: 'type'),
          ),
        );
        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });
    });

    group('null domainLogger fallback', () {
      test(
        'restoreSubscriptions logs to developer.log when domainLogger is null',
        () async {
          final nullLoggerService = ProjectAgentService(
            agentService: mockAgentService,
            repository: mockRepository,
            orchestrator: mockOrchestrator,
            syncService: mockSyncService,
          );

          final failingAgent = makeIdentity(agentId: 'pa-fail');
          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [failingAgent]);
          when(
            () => mockRepository.getLinksFrom(
              'pa-fail',
              type: 'agent_project',
            ),
          ).thenThrow(Exception('DB error'));

          await nullLoggerService.restoreSubscriptions();

          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );
    });
  });
}
