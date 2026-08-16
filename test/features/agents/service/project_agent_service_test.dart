import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/features/agents/wake/wake_orchestrator.dart';
import 'package:lotti/features/sync/vector_clock.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/domain_logging.dart';
import 'package:lotti/services/logging_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';

enum _GeneratedProjectTemplateSlot {
  valid,
  deleted,
  missing,
  wrongType,
  wrongKind,
}

enum _GeneratedProjectStateSlot { present, missing }

enum _GeneratedProjectProfileSlot { none, profile }

enum _GeneratedProjectCategorySlot { empty, single, pair }

class _PostCommitFailingAgentSyncService extends MockAgentSyncService {
  @override
  Future<T> runInTransaction<T>(Future<T> Function() action) async {
    await action();
    throw StateError('outbox flush failed');
  }
}

class _GeneratedProjectAgentCreateScenario {
  const _GeneratedProjectAgentCreateScenario({
    required this.templateSlot,
    required this.duplicateExists,
    required this.stateSlot,
    required this.profileSlot,
    required this.categorySlot,
  });

  final _GeneratedProjectTemplateSlot templateSlot;
  final bool duplicateExists;
  final _GeneratedProjectStateSlot stateSlot;
  final _GeneratedProjectProfileSlot profileSlot;
  final _GeneratedProjectCategorySlot categorySlot;

  bool get templateIsValid =>
      templateSlot == _GeneratedProjectTemplateSlot.valid;

  bool get stateExists => stateSlot == _GeneratedProjectStateSlot.present;

  bool get shouldCreateAgent => templateIsValid && !duplicateExists;

  bool get shouldSucceed => shouldCreateAgent && stateExists;

  String get templateId {
    return switch (templateSlot) {
      _GeneratedProjectTemplateSlot.valid => kTestTemplateId,
      _GeneratedProjectTemplateSlot.deleted => 'generated-deleted-template',
      _GeneratedProjectTemplateSlot.missing => 'generated-missing-template',
      _GeneratedProjectTemplateSlot.wrongType => 'generated-version-template',
      _GeneratedProjectTemplateSlot.wrongKind => 'generated-task-template',
    };
  }

  String? get profileId {
    return switch (profileSlot) {
      _GeneratedProjectProfileSlot.none => null,
      _GeneratedProjectProfileSlot.profile => 'generated-profile',
    };
  }

  Set<String> get allowedCategoryIds {
    return switch (categorySlot) {
      _GeneratedProjectCategorySlot.empty => const <String>{},
      _GeneratedProjectCategorySlot.single => {'generated-cat-1'},
      _GeneratedProjectCategorySlot.pair => {
        'generated-cat-1',
        'generated-cat-2',
      },
    };
  }

  @override
  String toString() {
    return '_GeneratedProjectAgentCreateScenario('
        'templateSlot: $templateSlot, duplicateExists: $duplicateExists, '
        'stateSlot: $stateSlot, profileSlot: $profileSlot, '
        'categorySlot: $categorySlot)';
  }
}

extension _AnyGeneratedProjectAgentServiceScenario on glados.Any {
  glados.Generator<_GeneratedProjectTemplateSlot> get projectTemplateSlot =>
      glados.any.choose(_GeneratedProjectTemplateSlot.values);

  glados.Generator<_GeneratedProjectStateSlot> get projectStateSlot =>
      glados.any.choose(_GeneratedProjectStateSlot.values);

  glados.Generator<_GeneratedProjectProfileSlot> get projectProfileSlot =>
      glados.any.choose(_GeneratedProjectProfileSlot.values);

  glados.Generator<_GeneratedProjectCategorySlot> get projectCategorySlot =>
      glados.any.choose(_GeneratedProjectCategorySlot.values);

  glados.Generator<_GeneratedProjectAgentCreateScenario>
  get projectAgentCreateScenario => glados.any.combine5(
    projectTemplateSlot,
    glados.any.bool,
    projectStateSlot,
    projectProfileSlot,
    projectCategorySlot,
    (
      _GeneratedProjectTemplateSlot templateSlot,
      bool duplicateExists,
      _GeneratedProjectStateSlot stateSlot,
      _GeneratedProjectProfileSlot profileSlot,
      _GeneratedProjectCategorySlot categorySlot,
    ) => _GeneratedProjectAgentCreateScenario(
      templateSlot: templateSlot,
      duplicateExists: duplicateExists,
      stateSlot: stateSlot,
      profileSlot: profileSlot,
      categorySlot: categorySlot,
    ),
  );
}

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
    when(() => mockRepository.upsertEntity(any())).thenAnswer((_) async {});
    when(() => mockOrchestrator.addSubscription(any())).thenReturn(null);
    when(
      () => mockOrchestrator.cancelPendingWakes(
        any(),
        allWorkspaces: any(named: 'allWorkspaces'),
      ),
    ).thenReturn(const []);
    when(
      () => mockRepository.getAgentStatesByAgentIds(any()),
    ).thenAnswer((_) async => const {});
    when(
      () => mockRepository.getAgentState(any()),
    ).thenAnswer((_) async => null);
    when(() => mockRepository.getEntity(any())).thenAnswer((invocation) async {
      return makeIdentity(
        agentId: invocation.positionalArguments.single as String,
      );
    });

    service = ProjectAgentService(
      agentService: mockAgentService,
      repository: mockRepository,
      orchestrator: mockOrchestrator,
      syncService: mockSyncService,
      projectScopeIsCurrent: (_, _) async => true,
      mutationCoordinator: ProjectAgentMutationCoordinator(),
      domainLogger: DomainLogger(loggingService: LoggingService())
        ..enabledDomains.add(LogDomain.agentRuntime),
      onPersistedStateChanged: notifiedAgentIds.add,
    );
  });

  group('ProjectAgentService', () {
    group('createProjectAgent', () {
      test(
        'rejects a stale project category before creating an agent',
        () async {
          final scopedService = ProjectAgentService(
            agentService: mockAgentService,
            repository: mockRepository,
            orchestrator: mockOrchestrator,
            syncService: mockSyncService,
            projectScopeIsCurrent: (_, categoryIds) async =>
                categoryIds.contains('current-category'),
            mutationCoordinator: ProjectAgentMutationCoordinator(),
          );

          await expectLater(
            () => scopedService.createProjectAgent(
              projectId: 'project-with-new-category',
              templateId: kTestTemplateId,
              displayName: 'Stale scope',
              allowedCategoryIds: const {'old-category'},
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

      glados.Glados(
        glados.any.projectAgentCreateScenario,
        glados.ExploreConfig(numRuns: 180),
      ).test('matches generated create-flow invariants', (scenario) async {
        final generatedAgentService = MockAgentService();
        final generatedRepository = MockAgentRepository();
        final generatedOrchestrator = MockWakeOrchestrator();
        final generatedSyncService = MockAgentSyncService();
        final generatedNotifiedAgentIds = <String>[];
        final generatedService = ProjectAgentService(
          agentService: generatedAgentService,
          repository: generatedRepository,
          orchestrator: generatedOrchestrator,
          syncService: generatedSyncService,
          projectScopeIsCurrent: (_, _) async => true,
          mutationCoordinator: ProjectAgentMutationCoordinator(),
          onPersistedStateChanged: generatedNotifiedAgentIds.add,
        );
        const projectId = 'generated-project';
        const agentId = 'generated-agent';
        const displayName = 'Generated Project Agent';
        final identity = makeIdentity(agentId: agentId);
        final initialState = makeState(
          id: 'state-$agentId',
          agentId: agentId,
          activeProjectId: 'previous-project',
        );
        final validTemplate = makeTestTemplate(
          kind: AgentTemplateKind.projectAgent,
        );
        final deletedTemplate = makeTestTemplate(
          id: 'generated-deleted-template',
          agentId: 'generated-deleted-template',
          kind: AgentTemplateKind.projectAgent,
        ).copyWith(deletedAt: kAgentTestDate);
        final wrongKindTemplate = makeTestTemplate(
          id: 'generated-task-template',
          agentId: 'generated-task-template',
          // ignore: avoid_redundant_argument_values
          kind: AgentTemplateKind.taskAgent,
        );
        final duplicateLink = AgentLink.agentProject(
          id: 'generated-duplicate-link',
          fromId: 'duplicate-agent',
          toId: projectId,
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final testDate = DateTime(2026, 3, 20, 14, 30);

        when(
          () => generatedSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});
        when(
          () => generatedSyncService.upsertLink(any()),
        ).thenAnswer((_) async {});
        when(
          () => generatedOrchestrator.addSubscription(any()),
        ).thenReturn(null);
        when(
          () => generatedOrchestrator.enqueueManualWake(
            agentId: any(named: 'agentId'),
            reason: any(named: 'reason'),
            triggerTokens: any(named: 'triggerTokens'),
          ),
        ).thenReturn('run-key-stub');
        when(
          () => generatedRepository.getLinksTo(
            projectId,
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer(
          (_) async => scenario.duplicateExists ? [duplicateLink] : [],
        );
        when(
          () => generatedRepository.getEntity(kTestTemplateId),
        ).thenAnswer((_) async => validTemplate);
        when(
          () => generatedRepository.getEntity('generated-deleted-template'),
        ).thenAnswer((_) async => deletedTemplate);
        when(
          () => generatedRepository.getEntity('generated-missing-template'),
        ).thenAnswer((_) async => null);
        when(
          () => generatedRepository.getEntity('generated-version-template'),
        ).thenAnswer(
          (_) async =>
              makeTestTemplateVersion(id: 'generated-version-template'),
        );
        when(
          () => generatedRepository.getEntity('generated-task-template'),
        ).thenAnswer((_) async => wrongKindTemplate);
        when(
          () => generatedAgentService.createAgent(
            kind: any(named: 'kind'),
            displayName: any(named: 'displayName'),
            config: any(named: 'config'),
            allowedCategoryIds: any(named: 'allowedCategoryIds'),
          ),
        ).thenAnswer((_) async => identity);
        when(
          () => generatedRepository.getAgentState(agentId),
        ).thenAnswer(
          (_) async => scenario.stateExists ? initialState : null,
        );

        Future<AgentIdentityEntity> create() {
          return withClock(Clock.fixed(testDate), () {
            return generatedService.createProjectAgent(
              projectId: projectId,
              templateId: scenario.templateId,
              displayName: displayName,
              profileId: scenario.profileId,
              allowedCategoryIds: scenario.allowedCategoryIds,
            );
          });
        }

        if (!scenario.shouldSucceed) {
          await expectLater(
            create,
            throwsA(isA<StateError>()),
            reason: '$scenario',
          );

          if (scenario.shouldCreateAgent) {
            verify(
              () => generatedAgentService.createAgent(
                kind: any(named: 'kind'),
                displayName: any(named: 'displayName'),
                config: any(named: 'config'),
                allowedCategoryIds: any(named: 'allowedCategoryIds'),
              ),
            ).called(1);
          } else {
            verifyNever(
              () => generatedAgentService.createAgent(
                kind: any(named: 'kind'),
                displayName: any(named: 'displayName'),
                config: any(named: 'config'),
                allowedCategoryIds: any(named: 'allowedCategoryIds'),
              ),
            );
          }
          verifyNever(() => generatedSyncService.upsertEntity(any()));
          verifyNever(() => generatedSyncService.upsertLink(any()));
          verifyNever(() => generatedOrchestrator.addSubscription(any()));
          verifyNever(
            () => generatedOrchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          );
          expect(generatedNotifiedAgentIds, isEmpty, reason: '$scenario');
          return;
        }

        final result = await create();

        expect(result, same(identity), reason: '$scenario');
        final createCall = verify(
          () => generatedAgentService.createAgent(
            kind: captureAny(named: 'kind'),
            displayName: captureAny(named: 'displayName'),
            config: captureAny(named: 'config'),
            allowedCategoryIds: captureAny(named: 'allowedCategoryIds'),
          ),
        ).captured;
        expect(createCall[0], AgentKinds.projectAgent, reason: '$scenario');
        expect(createCall[1], displayName, reason: '$scenario');
        final config = createCall[2] as AgentConfig;
        expect(
          config,
          AgentConfig(profileId: scenario.profileId),
          reason: '$scenario',
        );
        expect(
          createCall[3],
          scenario.allowedCategoryIds,
          reason: '$scenario',
        );

        final entityWrites = verify(
          () => generatedSyncService.upsertEntity(captureAny()),
        ).captured;
        expect(entityWrites, hasLength(1), reason: '$scenario');
        final updatedState = entityWrites.single as AgentStateEntity;
        expect(updatedState.agentId, agentId, reason: '$scenario');
        expect(
          updatedState.slots.activeProjectId,
          projectId,
          reason: '$scenario',
        );
        expect(
          updatedState.scheduledWakeAt,
          DateTime(2026, 3, 21, 6),
          reason: '$scenario',
        );
        expect(
          updatedState.slots.pendingProjectActivityAt,
          testDate,
          reason: '$scenario',
        );

        final linkWrites = verify(
          () => generatedSyncService.upsertLink(captureAny()),
        ).captured;
        expect(linkWrites, hasLength(2), reason: '$scenario');
        final projectLink = linkWrites.whereType<AgentProjectLink>().single;
        expect(projectLink.fromId, agentId, reason: '$scenario');
        expect(projectLink.toId, projectId, reason: '$scenario');
        final templateLink = linkWrites
            .whereType<TemplateAssignmentLink>()
            .single;
        expect(templateLink.fromId, kTestTemplateId, reason: '$scenario');
        expect(templateLink.toId, agentId, reason: '$scenario');

        final subscriptions = verify(
          () => generatedOrchestrator.addSubscription(captureAny()),
        ).captured.cast<AgentSubscription>();
        expect(subscriptions, hasLength(1), reason: '$scenario');
        expect(subscriptions.single.agentId, agentId, reason: '$scenario');
        expect(
          subscriptions.single.matchEntityIds,
          {projectEntityUpdateNotification(projectId)},
          reason: '$scenario',
        );
        expect(
          subscriptions.single.deferPropagatedMatches,
          isTrue,
          reason: '$scenario',
        );
        verify(
          () => generatedOrchestrator.enqueueManualWake(
            agentId: agentId,
            reason: WakeReason.creation.name,
            triggerTokens: {projectId},
          ),
        ).called(1);
        // Both ids: the agent's own, and the project id `projectAgentProvider`
        // keys its refresh on.
        expect(
          generatedNotifiedAgentIds,
          [agentId, projectId],
          reason: '$scenario',
        );
      }, tags: 'glados');

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
        ).thenReturn('run-key-stub');

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
        expect(subscription.deferPropagatedMatches, isTrue);

        // Verify creation wake was enqueued.
        verify(
          () => mockOrchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'creation',
            triggerTokens: {'project-1'},
          ),
        ).called(1);
        // `projectAgentProvider` refreshes on the *project* id and nothing in
        // the agent write path emits it, so the announcement carries both.
        expect(notifiedAgentIds, ['agent-1', 'project-1']);
      });

      test(
        'deletes a newly created agent when the project is tombstoned',
        () async {
          final identity = makeIdentity();
          final template = makeTestTemplate(
            kind: AgentTemplateKind.projectAgent,
          );
          var existenceChecks = 0;
          final compensatingService = ProjectAgentService(
            agentService: mockAgentService,
            repository: mockRepository,
            orchestrator: mockOrchestrator,
            syncService: mockSyncService,
            projectScopeIsCurrent: (_, _) async => existenceChecks++ == 0,
            mutationCoordinator: ProjectAgentMutationCoordinator(),
            onPersistedStateChanged: notifiedAgentIds.add,
          );
          when(
            () => mockRepository.getLinksTo(
              'project-deleted-by-sync',
              type: AgentLinkTypes.agentProject,
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
            () => mockRepository.getAgentState(identity.agentId),
          ).thenAnswer((_) async => makeState());
          when(
            () => mockAgentService.deleteAgent(identity.agentId),
          ).thenAnswer((_) async {});

          await expectLater(
            () => compensatingService.createProjectAgent(
              projectId: 'project-deleted-by-sync',
              templateId: kTestTemplateId,
              displayName: 'Orphan prevention',
              allowedCategoryIds: const {},
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                contains('project-deleted-by-sync'),
              ),
            ),
          );

          expect(existenceChecks, 2);
          verify(
            () => mockAgentService.deleteAgent(identity.agentId),
          ).called(1);
          verifyNever(() => mockOrchestrator.addSubscription(any()));
          verifyNever(
            () => mockOrchestrator.enqueueManualWake(
              agentId: any(named: 'agentId'),
              reason: any(named: 'reason'),
              triggerTokens: any(named: 'triggerTokens'),
            ),
          );
          expect(notifiedAgentIds, isEmpty);
        },
      );

      test(
        'persists a one-shot fallback for the explicit creation wake',
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
          ).thenReturn('run-key-stub');

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
          expect(updatedState.slots.pendingProjectActivityAt, testDate);
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
          ).thenReturn('run-key-stub');

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
        ).thenReturn('run-key-stub');

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

    test(
      'serializes same-project mutations without blocking other projects',
      () async {
        final coordinator = ProjectAgentMutationCoordinator();
        final firstStarted = Completer<void>();
        final releaseFirst = Completer<void>();
        final order = <String>[];

        final first = coordinator.run('project-1', () async {
          order.add('first-start');
          firstStarted.complete();
          await releaseFirst.future;
          order.add('first-end');
        });
        await firstStarted.future;
        final second = coordinator.run('project-1', () async {
          order.add('second');
        });
        await coordinator.run('project-2', () async {
          order.add('other-project');
        });

        expect(order, ['first-start', 'other-project']);
        releaseFirst.complete();
        await Future.wait([first, second]);
        expect(order, ['first-start', 'other-project', 'first-end', 'second']);
      },
    );

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

    group('getProjectAgentsForProject', () {
      test('returns every unique live linked project agent', () async {
        final olderDate = kAgentTestDate.subtract(const Duration(days: 1));
        final links = [
          AgentLink.agentProject(
            id: 'link-new',
            fromId: 'agent-new',
            toId: 'project-1',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          ),
          AgentLink.agentProject(
            id: 'link-old',
            fromId: 'agent-old',
            toId: 'project-1',
            createdAt: olderDate,
            updatedAt: olderDate,
            vectorClock: null,
          ),
          AgentLink.agentProject(
            id: 'link-old-duplicate',
            fromId: 'agent-old',
            toId: 'project-1',
            createdAt: olderDate,
            updatedAt: olderDate,
            vectorClock: null,
          ),
          AgentLink.agentProject(
            id: 'link-destroyed',
            fromId: 'agent-destroyed',
            toId: 'project-1',
            createdAt: olderDate,
            updatedAt: olderDate,
            vectorClock: null,
          ),
        ];
        final newer = makeIdentity(agentId: 'agent-new');
        final older = makeIdentity(
          agentId: 'agent-old',
          lifecycle: AgentLifecycle.dormant,
        );
        final destroyed = makeIdentity(
          agentId: 'agent-destroyed',
          lifecycle: AgentLifecycle.destroyed,
        );
        when(
          () => mockRepository.getLinksTo(
            'project-1',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async => links);
        when(
          () => mockRepository.getEntitiesByIds([
            'agent-new',
            'agent-old',
            'agent-destroyed',
          ]),
        ).thenAnswer(
          (_) async => {
            newer.id: newer,
            older.id: older,
            destroyed.id: destroyed,
          },
        );

        final result = await service.getProjectAgentsForProject('project-1');

        expect(result.map((identity) => identity.agentId), [
          'agent-new',
          'agent-old',
        ]);
      });
    });

    group('project category scopes', () {
      test(
        'updates every live project-agent scope and returns prior scopes',
        () async {
          final first = makeIdentity().copyWith(
            allowedCategoryIds: const {'old-1'},
          );
          final second = makeIdentity(agentId: 'agent-2').copyWith(
            allowedCategoryIds: const {'old-2'},
          );
          final links = [
            AgentLink.agentProject(
              id: 'link-1',
              fromId: first.agentId,
              toId: 'project-1',
              createdAt: kAgentTestDate,
              updatedAt: kAgentTestDate,
              vectorClock: null,
            ),
            AgentLink.agentProject(
              id: 'link-2',
              fromId: second.agentId,
              toId: 'project-1',
              createdAt: kAgentTestDate,
              updatedAt: kAgentTestDate,
              vectorClock: null,
            ),
          ];
          when(
            () => mockRepository.getLinksTo(
              'project-1',
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer((_) async => links);
          when(
            () => mockRepository.getEntitiesByIds(any()),
          ).thenAnswer(
            (_) async => {first.agentId: first, second.agentId: second},
          );

          final previous = await service.updateProjectAgentScopes(
            projectId: 'project-1',
            allowedCategoryIds: const {'new-category'},
          );

          expect(previous, {
            first.agentId: {'old-1'},
            second.agentId: {'old-2'},
          });
          final writes = verify(
            () => mockSyncService.upsertEntity(captureAny()),
          ).captured.whereType<AgentIdentityEntity>().toList();
          expect(writes, hasLength(2));
          expect(
            writes.map((identity) => identity.allowedCategoryIds),
            everyElement(const {'new-category'}),
          );
          expect(notifiedAgentIds.first, 'project-1');
          expect(notifiedAgentIds.skip(1).toSet(), {
            first.agentId,
            second.agentId,
          });
        },
      );

      test('restores the captured scope for each surviving identity', () async {
        final first = makeIdentity().copyWith(
          allowedCategoryIds: const {'new-category'},
        );
        final second = makeIdentity(agentId: 'agent-2').copyWith(
          allowedCategoryIds: const {'new-category'},
        );
        when(
          () => mockRepository.getLinksTo(
            'project-1',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.agentProject(
              id: 'link-1',
              fromId: first.agentId,
              toId: 'project-1',
              createdAt: kAgentTestDate,
              updatedAt: kAgentTestDate,
              vectorClock: null,
            ),
            AgentLink.agentProject(
              id: 'link-2',
              fromId: second.agentId,
              toId: 'project-1',
              createdAt: kAgentTestDate,
              updatedAt: kAgentTestDate,
              vectorClock: null,
            ),
          ],
        );
        when(
          () => mockRepository.getEntitiesByIds(any()),
        ).thenAnswer(
          (_) async => {first.agentId: first, second.agentId: second},
        );

        await service.restoreProjectAgentScopes(
          projectId: 'project-1',
          scopesByAgentId: {
            first.agentId: const {'old-1'},
            second.agentId: const {'old-2'},
          },
        );

        final writes = verify(
          () => mockSyncService.upsertEntity(captureAny()),
        ).captured.whereType<AgentIdentityEntity>().toList();
        expect(writes, hasLength(2));
        final scopesByAgentId = {
          for (final identity in writes)
            identity.agentId: identity.allowedCategoryIds,
        };
        expect(scopesByAgentId, {
          first.agentId: {'old-1'},
          second.agentId: {'old-2'},
        });
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
        ).thenReturn('run-key-stub');

        service.triggerReanalysis('agent-1');

        verify(
          () => mockOrchestrator.enqueueManualWake(
            agentId: 'agent-1',
            reason: 'reanalysis',
          ),
        ).called(1);
      });
    });

    group('cancelScheduledWake', () {
      test(
        'atomically clears both deadlines before dropping queued work',
        () async {
          final state = makeState().copyWith(
            slots: AgentSlots(
              activeProjectId: 'project-1',
              pendingProjectActivityAt: kAgentTestDate,
            ),
            nextWakeAt: DateTime(2026, 3, 20, 12, 2),
            scheduledWakeAt: DateTime(2026, 3, 21, 6),
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);

          await service.cancelScheduledWake('agent-1');

          final persisted =
              verify(
                    () => mockSyncService.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(persisted.nextWakeAt, isNull);
          expect(persisted.scheduledWakeAt, isNull);
          expect(persisted.slots.pendingProjectActivityAt, isNull);
          verify(() => mockOrchestrator.clearThrottle('agent-1')).called(1);
          verify(
            () => mockOrchestrator.cancelPendingWakes(
              'agent-1',
              allWorkspaces: true,
            ),
          ).called(1);
        },
      );

      test(
        'keeps queued work intact when persisted cancellation fails',
        () async {
          final state = makeState().copyWith(
            nextWakeAt: DateTime(2026, 3, 20, 12, 2),
            scheduledWakeAt: DateTime(2026, 3, 21, 6),
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);
          when(
            () => mockSyncService.upsertEntity(any()),
          ).thenThrow(StateError('write failed'));

          await expectLater(
            service.cancelScheduledWake('agent-1'),
            throwsA(isA<StateError>()),
          );

          verifyNever(() => mockOrchestrator.clearThrottle(any()));
          verifyNever(
            () => mockOrchestrator.cancelPendingWakes(
              any(),
              allWorkspaces: any(named: 'allWorkspaces'),
            ),
          );
        },
      );

      test(
        'drops queued work when cancellation commits before sync flush fails',
        () async {
          final failingSyncService = _PostCommitFailingAgentSyncService();
          final cancellationCoordinator =
              ProjectActivityCancellationCoordinator();
          final observedSequence = cancellationCoordinator.captureActivity();
          when(
            () => failingSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});
          service = ProjectAgentService(
            agentService: mockAgentService,
            repository: mockRepository,
            orchestrator: mockOrchestrator,
            syncService: failingSyncService,
            projectScopeIsCurrent: (_, _) async => true,
            mutationCoordinator: ProjectAgentMutationCoordinator(),
            onPersistedStateChanged: notifiedAgentIds.add,
            cancellationCoordinator: cancellationCoordinator,
          );
          final state = makeState().copyWith(
            slots: AgentSlots(
              activeProjectId: 'project-1',
              pendingProjectActivityAt: kAgentTestDate,
            ),
            scheduledWakeAt: DateTime(2026, 3, 21, 6),
          );
          var stateReads = 0;
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async {
            stateReads++;
            return stateReads == 1
                ? state
                : state.copyWith(
                    slots: state.slots.copyWith(
                      pendingProjectActivityAt: null,
                    ),
                    nextWakeAt: null,
                    scheduledWakeAt: null,
                  );
          });

          await expectLater(
            service.cancelScheduledWake('agent-1'),
            throwsA(isA<StateError>()),
          );

          verify(
            () => failingSyncService.upsertEntity(any()),
          ).called(1);
          verify(() => mockOrchestrator.clearThrottle('agent-1')).called(1);
          verify(
            () => mockOrchestrator.cancelPendingWakes(
              'agent-1',
              allWorkspaces: true,
            ),
          ).called(1);
          expect(notifiedAgentIds, ['agent-1']);

          var activityPersisted = false;
          final accepted = await cancellationCoordinator.runActivityWrite(
            agentId: 'agent-1',
            observedSequence: observedSequence,
            action: () async => activityPersisted = true,
          );
          expect(accepted, isFalse);
          expect(activityPersisted, isFalse);
        },
      );

      test(
        'keeps queued work when the transaction fails after its action',
        () async {
          final failingSyncService = _PostCommitFailingAgentSyncService();
          when(
            () => failingSyncService.upsertEntity(any()),
          ).thenAnswer((_) async {});
          service = ProjectAgentService(
            agentService: mockAgentService,
            repository: mockRepository,
            orchestrator: mockOrchestrator,
            syncService: failingSyncService,
            projectScopeIsCurrent: (_, _) async => true,
            mutationCoordinator: ProjectAgentMutationCoordinator(),
            onPersistedStateChanged: notifiedAgentIds.add,
          );
          final state = makeState().copyWith(
            slots: AgentSlots(
              activeProjectId: 'project-1',
              pendingProjectActivityAt: kAgentTestDate,
            ),
            scheduledWakeAt: DateTime(2026, 3, 21, 6),
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);

          await expectLater(
            service.cancelScheduledWake('agent-1'),
            throwsA(isA<StateError>()),
          );

          verifyNever(() => mockOrchestrator.clearThrottle(any()));
          verifyNever(
            () => mockOrchestrator.cancelPendingWakes(
              any(),
              allWorkspaces: any(named: 'allWorkspaces'),
            ),
          );
          expect(notifiedAgentIds, isEmpty);
        },
      );

      test(
        'clears pending activity even when no wake deadline exists',
        () async {
          final state = makeState().copyWith(
            slots: AgentSlots(
              activeProjectId: 'project-1',
              pendingProjectActivityAt: kAgentTestDate,
            ),
          );
          when(
            () => mockRepository.getAgentState('agent-1'),
          ).thenAnswer((_) async => state);

          await service.cancelScheduledWake('agent-1');

          final persisted =
              verify(
                    () => mockSyncService.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(persisted.slots.pendingProjectActivityAt, isNull);
          verify(() => mockOrchestrator.clearThrottle('agent-1')).called(1);
          verify(
            () => mockOrchestrator.cancelPendingWakes(
              'agent-1',
              allWorkspaces: true,
            ),
          ).called(1);
        },
      );
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
          final state = makeState(agentId: 'pa-1').copyWith(
            slots: AgentSlots(
              pendingProjectActivityAt: DateTime(2026, 3, 22, 9),
            ),
            nextWakeAt: nextWakeAt,
          );

          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent, otherAgent]);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-1'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-1': [link],
            },
          );
          when(
            () => mockRepository.getAgentStatesByAgentIds(any()),
          ).thenAnswer(
            (_) async => {'pa-1': state},
          );
          when(
            () => mockRepository.getAgentState('pa-1'),
          ).thenAnswer((_) async => state);

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
            () => mockOrchestrator.restorePendingWake(
              agentId: 'pa-1',
              dueAt: nextWakeAt,
            ),
          ).called(1);
          verifyNever(
            () => mockRepository.getLinksFrom(
              any(),
              type: any(named: 'type'),
            ),
          );
          verify(
            () => mockRepository.getLinksFromMultiple(
              ['pa-1'],
              type: AgentLinkTypes.agentProject,
            ),
          ).called(1);
          final requestedAgentIds =
              verify(
                    () => mockRepository.getAgentStatesByAgentIds(captureAny()),
                  ).captured.single
                  as List<String>;
          expect(requestedAgentIds, ['pa-1']);
          verify(() => mockRepository.getAgentState('pa-1')).called(1);
        },
      );

      test(
        'does not hydrate a startup batch consumed after the bulk snapshot',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-consumed-race');
          final nextWakeAt = DateTime(2026, 3, 23, 8);
          final snapshot =
              makeState(
                agentId: 'pa-consumed-race',
                activeProjectId: 'project-consumed-race',
              ).copyWith(
                slots: AgentSlots(
                  activeProjectId: 'project-consumed-race',
                  pendingProjectActivityAt: DateTime(2026, 3, 22, 9),
                ),
                nextWakeAt: nextWakeAt,
                scheduledWakeAt: DateTime(2026, 3, 23, 6),
              );
          final current = snapshot.copyWith(
            slots: snapshot.slots.copyWith(pendingProjectActivityAt: null),
            nextWakeAt: null,
            scheduledWakeAt: null,
            updatedAt: DateTime(2026, 3, 22, 10),
          );
          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getAgentStatesByAgentIds([
              'pa-consumed-race',
            ]),
          ).thenAnswer((_) async => {'pa-consumed-race': snapshot});
          when(
            () => mockRepository.getAgentState('pa-consumed-race'),
          ).thenAnswer((_) async => current);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-consumed-race'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer((_) async => const {});

          await service.restoreSubscriptions();

          verifyNever(
            () => mockOrchestrator.restorePendingWake(
              agentId: any(named: 'agentId'),
              dueAt: any(named: 'dueAt'),
            ),
          );
          verifyNever(() => mockRepository.upsertEntity(any()));
        },
      );

      test(
        'keeps observation but suppresses countdown hydration when automation '
        'is off',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-manual').copyWith(
            config: const AgentConfig(automaticUpdatesEnabled: false),
          );
          final link = AgentLink.agentProject(
            id: 'link-manual',
            fromId: 'pa-manual',
            toId: 'project-manual',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final state = makeState(agentId: 'pa-manual').copyWith(
            nextWakeAt: DateTime(2026, 3, 22, 12),
          );
          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getEntity('pa-manual'),
          ).thenAnswer((_) async => projectAgent);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-manual']),
          ).thenAnswer((_) async => {'pa-manual': state});
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-manual'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-manual': [link],
            },
          );

          await service.restoreSubscriptions();

          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime('pa-manual'),
          ).called(1);
          verify(() => mockOrchestrator.addSubscription(any())).called(1);
          verifyNever(
            () => mockOrchestrator.restorePendingWake(
              agentId: any(named: 'agentId'),
              dueAt: any(named: 'dueAt'),
            ),
          );
        },
      );

      test(
        'clears a markerless fallback for an already opted-out agent',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-opted-out').copyWith(
            config: const AgentConfig(
              automaticUpdatesEnabled: false,
              inferenceSetup: AgentInferenceSetup(
                mode: AgentInferenceSetupMode.configured,
                origin: AgentInferenceSetupOrigin.user,
                baseProfileId: 'profile-1',
              ),
            ),
          );
          final state =
              makeState(
                id: 'state-pa-opted-out',
                agentId: 'pa-opted-out',
                activeProjectId: 'project-opted-out',
              ).copyWith(
                scheduledWakeAt: DateTime(2026, 8, 15, 6),
                updatedAt: DateTime(2026, 8, 14, 9),
                vectorClock: const VectorClock({'peer-a': 4}),
              );
          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getEntity('pa-opted-out'),
          ).thenAnswer((_) async => projectAgent);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-opted-out']),
          ).thenAnswer((_) async => {'pa-opted-out': state});
          when(
            () => mockRepository.getAgentState('pa-opted-out'),
          ).thenAnswer((_) async => state);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-opted-out'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer((_) async => const {});

          await service.restoreSubscriptions();

          final persisted =
              verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(persisted.scheduledWakeAt, isNull);
          expect(persisted.updatedAt, state.updatedAt);
          expect(persisted.vectorClock, state.vectorClock);
          verifyNever(() => mockSyncService.upsertEntity(any()));
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'pa-opted-out',
            ),
          ).called(1);
        },
      );

      test(
        'clears a legacy daily schedule when no project activity is pending',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-dormant');
          final link = AgentLink.agentProject(
            id: 'link-dormant',
            fromId: 'pa-dormant',
            toId: 'project-dormant',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final legacySchedule = DateTime(2026, 3, 23, 6);
          final state =
              makeState(
                id: 'state-pa-dormant',
                agentId: 'pa-dormant',
                activeProjectId: 'project-dormant',
              ).copyWith(
                lastWakeAt: DateTime(2026, 3, 20, 6),
                scheduledWakeAt: legacySchedule,
                updatedAt: DateTime(2026, 3, 20, 7),
                vectorClock: const VectorClock({'peer-a': 4}),
              );

          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-dormant']),
          ).thenAnswer((_) async => {'pa-dormant': state});
          when(
            () => mockRepository.getAgentState('pa-dormant'),
          ).thenAnswer((_) async => state);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-dormant'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-dormant': [link],
            },
          );

          await withClock(Clock.fixed(DateTime(2026, 3, 22, 10)), () {
            return service.restoreSubscriptions();
          });

          final repaired =
              verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(repaired.scheduledWakeAt, isNull);
          expect(repaired.slots.pendingProjectActivityAt, isNull);
          expect(repaired.updatedAt, state.updatedAt);
          expect(repaired.vectorClock, state.vectorClock);
          verifyNever(() => mockSyncService.upsertEntity(any()));
          expect(notifiedAgentIds, ['pa-dormant']);
          verifyNever(
            () => mockOrchestrator.restorePendingWake(
              agentId: any(named: 'agentId'),
              dueAt: any(named: 'dueAt'),
            ),
          );
        },
      );

      test(
        'does not clear activity that arrives after the startup snapshot',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-racing');
          final link = AgentLink.agentProject(
            id: 'link-racing',
            fromId: 'pa-racing',
            toId: 'project-racing',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final scheduledAt = DateTime(2026, 3, 23, 6);
          final snapshot =
              makeState(
                id: 'state-pa-racing',
                agentId: 'pa-racing',
                activeProjectId: 'project-racing',
              ).copyWith(
                lastWakeAt: DateTime(2026, 3, 20, 6),
                scheduledWakeAt: scheduledAt,
              );
          final current = snapshot.copyWith(
            slots: snapshot.slots.copyWith(
              pendingProjectActivityAt: DateTime(2026, 3, 22, 9, 59),
            ),
            updatedAt: DateTime(2026, 3, 22, 9, 59),
          );

          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-racing']),
          ).thenAnswer((_) async => {'pa-racing': snapshot});
          when(
            () => mockRepository.getAgentState('pa-racing'),
          ).thenAnswer((_) async => current);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-racing'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-racing': [link],
            },
          );

          await service.restoreSubscriptions();

          verifyNever(() => mockSyncService.upsertEntity(any()));
          verifyNever(() => mockRepository.upsertEntity(any()));
          verify(
            () => mockRepository.getAgentState('pa-racing'),
          ).called(2);
        },
      );

      test(
        'does not clear a newer manual schedule after the startup snapshot',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-manual-race');
          final link = AgentLink.agentProject(
            id: 'link-manual-race',
            fromId: 'pa-manual-race',
            toId: 'project-manual-race',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final snapshot =
              makeState(
                id: 'state-pa-manual-race',
                agentId: 'pa-manual-race',
                activeProjectId: 'project-manual-race',
              ).copyWith(
                lastWakeAt: DateTime(2026, 3, 20, 6),
                scheduledWakeAt: DateTime(2026, 3, 23, 6),
                updatedAt: DateTime(2026, 3, 22, 9),
              );
          final current = snapshot.copyWith(
            scheduledWakeAt: DateTime(2026, 3, 23, 7),
            updatedAt: DateTime(2026, 3, 22, 9, 59),
          );

          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-manual-race']),
          ).thenAnswer((_) async => {'pa-manual-race': snapshot});
          when(
            () => mockRepository.getAgentState('pa-manual-race'),
          ).thenAnswer((_) async => current);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-manual-race'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-manual-race': [link],
            },
          );

          await service.restoreSubscriptions();

          verifyNever(() => mockSyncService.upsertEntity(any()));
          verifyNever(() => mockRepository.upsertEntity(any()));
          verify(
            () => mockRepository.getAgentState('pa-manual-race'),
          ).called(2);
        },
      );

      test(
        'retains a legacy schedule while project activity is pending',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-active');
          final link = AgentLink.agentProject(
            id: 'link-active',
            fromId: 'pa-active',
            toId: 'project-active',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final pendingAt = DateTime(2026, 3, 22, 9);
          final state =
              makeState(
                id: 'state-pa-active',
                agentId: 'pa-active',
                activeProjectId: 'project-active',
              ).copyWith(
                slots: AgentSlots(
                  activeProjectId: 'project-active',
                  pendingProjectActivityAt: pendingAt,
                ),
                scheduledWakeAt: DateTime(2026, 3, 23, 6),
              );

          when(
            () => mockAgentService.listAgents(lifecycle: AgentLifecycle.active),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-active']),
          ).thenAnswer((_) async => {'pa-active': state});
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-active'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-active': [link],
            },
          );

          await service.restoreSubscriptions();

          verifyNever(() => mockSyncService.upsertEntity(any()));
          verify(() => mockOrchestrator.addSubscription(any())).called(1);
        },
      );

      test(
        'arms pending activity that has no local fallback after restart',
        () async {
          final projectAgent = makeIdentity(agentId: 'pa-pending');
          final link = AgentLink.agentProject(
            id: 'link-pending',
            fromId: 'pa-pending',
            toId: 'project-pending',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final pendingState =
              makeState(
                id: 'state-pa-pending',
                agentId: 'pa-pending',
                activeProjectId: 'project-pending',
              ).copyWith(
                slots: AgentSlots(
                  activeProjectId: 'project-pending',
                  pendingProjectActivityAt: DateTime(2026, 3, 22, 9),
                ),
              );
          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [projectAgent]);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-pending']),
          ).thenAnswer((_) async => {'pa-pending': pendingState});
          when(
            () => mockRepository.getAgentState('pa-pending'),
          ).thenAnswer((_) async => pendingState);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-pending'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-pending': [link],
            },
          );

          await withClock(Clock.fixed(DateTime(2026, 3, 22, 10)), () {
            return service.restoreSubscriptions();
          });

          final persisted =
              verify(
                    () => mockRepository.upsertEntity(captureAny()),
                  ).captured.single
                  as AgentStateEntity;
          expect(persisted.scheduledWakeAt, DateTime(2026, 3, 23, 6));
          expect(
            persisted.slots.pendingProjectActivityAt,
            DateTime(2026, 3, 22, 9),
          );
          expect(
            persisted.updatedAt,
            pendingState.updatedAt,
            reason: 'A local-only deadline must not affect synced LWW data.',
          );
          verifyNever(() => mockSyncService.upsertEntity(any()));
          expect(notifiedAgentIds, ['pa-pending']);
        },
      );

      test(
        'startup reconciliation honors a concurrent lifecycle change',
        () async {
          final snapshotIdentity = makeIdentity(agentId: 'pa-paused-race');
          final currentIdentity = snapshotIdentity.copyWith(
            lifecycle: AgentLifecycle.dormant,
            updatedAt: DateTime(2026, 3, 22, 10),
          );
          final link = AgentLink.agentProject(
            id: 'link-paused-race',
            fromId: 'pa-paused-race',
            toId: 'project-paused-race',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          final pendingState =
              makeState(
                id: 'state-pa-paused-race',
                agentId: 'pa-paused-race',
                activeProjectId: 'project-paused-race',
              ).copyWith(
                slots: AgentSlots(
                  activeProjectId: 'project-paused-race',
                  pendingProjectActivityAt: DateTime(2026, 3, 22, 9),
                ),
              );
          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [snapshotIdentity]);
          when(
            () => mockRepository.getEntity('pa-paused-race'),
          ).thenAnswer((_) async => currentIdentity);
          when(
            () => mockRepository.getAgentStatesByAgentIds(['pa-paused-race']),
          ).thenAnswer((_) async => {'pa-paused-race': pendingState});
          when(
            () => mockRepository.getAgentState('pa-paused-race'),
          ).thenAnswer((_) async => pendingState);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-paused-race'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-paused-race': [link],
            },
          );

          await service.restoreSubscriptions();

          verifyNever(() => mockRepository.upsertEntity(any()));
          verify(
            () => mockOrchestrator.removeSubscriptions('pa-paused-race'),
          ).called(1);
          verify(
            () => mockOrchestrator.disableAutomaticUpdatesRuntime(
              'pa-paused-race',
            ),
          ).called(1);
          verifyNever(
            () => mockOrchestrator.enableAutomaticUpdatesRuntime(
              'pa-paused-race',
            ),
          );
        },
      );

      test('aborts before per-agent work when state preload fails', () async {
        final first = makeIdentity(agentId: 'pa-1');
        final second = makeIdentity(agentId: 'pa-2');
        when(
          () => mockAgentService.listAgents(
            lifecycle: AgentLifecycle.active,
          ),
        ).thenAnswer((_) async => [first, second]);
        when(
          () => mockRepository.getAgentStatesByAgentIds(['pa-1', 'pa-2']),
        ).thenThrow(StateError('database connection closed'));

        await expectLater(
          service.restoreSubscriptions(),
          throwsA(isA<StateError>()),
        );

        verifyNever(
          () => mockRepository.getLinksFromMultiple(
            any(),
            type: any(named: 'type'),
          ),
        );
        verifyNever(() => mockRepository.getLinksFrom(any()));
        verifyNever(() => mockRepository.getAgentState(any()));
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
            projectScopeIsCurrent: (_, _) async => true,
            mutationCoordinator: ProjectAgentMutationCoordinator(),
          );

          final failingAgent = makeIdentity(agentId: 'pa-fail');
          final failingLink = AgentLink.agentProject(
            id: 'link-fail',
            fromId: 'pa-fail',
            toId: 'project-fail',
            createdAt: kAgentTestDate,
            updatedAt: kAgentTestDate,
            vectorClock: null,
          );
          when(
            () => mockAgentService.listAgents(
              lifecycle: AgentLifecycle.active,
            ),
          ).thenAnswer((_) async => [failingAgent]);
          when(
            () => mockRepository.getLinksFromMultiple(
              ['pa-fail'],
              type: AgentLinkTypes.agentProject,
            ),
          ).thenAnswer(
            (_) async => {
              'pa-fail': [failingLink],
            },
          );
          when(
            () => mockOrchestrator.addSubscription(any()),
          ).thenThrow(StateError('runtime registration failed'));

          await nullLoggerService.restoreSubscriptions();

          verify(() => mockOrchestrator.addSubscription(any())).called(1);
        },
      );
    });
  });
}
