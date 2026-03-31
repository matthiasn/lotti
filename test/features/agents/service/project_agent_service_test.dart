import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
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
  late List<String> notifiedAgentIds;

  AgentIdentityEntity makeIdentity({
    String agentId = 'agent-1',
    String kind = 'project_agent',
    String displayName = 'Project Agent',
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
    notifiedAgentIds = [];

    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockSyncService.upsertLink(any())).thenAnswer((_) async {});
    when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
    when(
      () => mockOrchestrator.setThrottleDeadline(any(), any()),
    ).thenReturn(null);

    service = ProjectAgentService(
      agentService: mockAgentService,
      repository: mockRepository,
      orchestrator: mockOrchestrator,
      syncService: mockSyncService,
      domainLogger: DomainLogger(loggingService: LoggingService())
        ..enabledDomains.add(LogDomains.agentRuntime),
      onPersistedStateChanged: notifiedAgentIds.add,
    );
  });

  group('ProjectAgentService', () {
    group('createProjectAgent', () {
      test('creates agent, updates state, creates links, and enqueues '
          'creation wake', () async {
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

        final subscription =
            verify(
                  () => mockOrchestrator.addSubscription(captureAny()),
                ).captured.single
                as AgentSubscription;
        expect(subscription.agentId, 'agent-1');
        expect(
          subscription.matchEntityIds,
          {projectEntityUpdateNotification('project-1')},
        );

        // Verify creation wake was enqueued.
        verify(
          () => mockOrchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'project-1'},
          ),
        ).called(1);
        expect(notifiedAgentIds, ['agent-1']);
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
          () => mockRepository.getLinksFrom(any(), type: any(named: 'type')),
        );
        verifyNever(() => mockOrchestrator.addSubscription(any()));
      });

      test(
        're-registers direct project subscriptions for project agents',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-1');
          final otherAgent = makeIdentity(
            agentId: 'other-1',
            kind: 'task_agent',
          );
          final link = AgentLink.agentProject(
            id: 'link-1',
            fromId: 'pa-1',
            toId: 'project-1',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final nextWakeAt = DateTime(2026, 3, 23, 8);

          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent, otherAgent]);
          when(
            () => mockRepository.getLinksFrom(
              'pa-1',
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer((_) async => [link]);
          when(
            () => mockRepository.getAgentState('pa-1'),
          ).thenAnswer(
            (_) async => makeState(agentId: 'pa-1').copyWith(
              nextWakeAt: nextWakeAt,
            ),
          );

          await service.restoreSubscriptions();

          final subscription =
              verify(
                    () => mockOrchestrator.addSubscription(captureAny()),
                  ).captured.single
                  as AgentSubscription;
          expect(subscription.agentId, 'pa-1');
          expect(
            subscription.matchEntityIds,
            {projectEntityUpdateNotification('project-1')},
          );
          verify(
            () => mockOrchestrator.setThrottleDeadline('pa-1', nextWakeAt),
          ).called(1);
          verifyNever(
            () => mockRepository.getLinksFrom(
              'other-1',
              type: any(named: 'type'),
            ),
          );
        },
      );

      test('handles empty agent list gracefully', () async {
        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => []);

        await service.restoreSubscriptions();

        verifyNever(
          () => mockRepository.getLinksFrom(any(), type: any(named: 'type')),
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

          await nullLoggerService.restoreSubscriptions();

          verifyNever(() => mockOrchestrator.addSubscription(any()));
        },
      );
    });
  });
}
