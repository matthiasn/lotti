import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../test_utils.dart';
import 'project_recommendation_service_test_helpers.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentSyncService mockSyncService;
  late MockAgentRepository mockRepository;
  late MockUpdateNotifications mockNotifications;
  late MockDomainLogger mockDomainLogger;
  late ProjectRecommendationService service;

  setUp(() {
    mockSyncService = MockAgentSyncService();
    mockRepository = MockAgentRepository();
    mockNotifications = MockUpdateNotifications();
    mockDomainLogger = MockDomainLogger();

    when(() => mockSyncService.repository).thenReturn(mockRepository);
    when(() => mockSyncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => mockNotifications.notify(any(), fromSync: any(named: 'fromSync')),
    ).thenReturn(null);
    when(
      () => mockDomainLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    service = ProjectRecommendationService(
      syncService: mockSyncService,
      notifications: mockNotifications,
      domainLogger: mockDomainLogger,
    );
  });

  glados.Glados(
    glados.any.recommendationRecordScenario,
    glados.ExploreConfig(numRuns: 180),
  ).test('matches generated recommendation recording semantics', (
    scenario,
  ) async {
    final generatedSyncService = MockAgentSyncService();
    final generatedRepository = MockAgentRepository();
    final generatedNotifications = MockUpdateNotifications();
    final generatedLogger = MockDomainLogger();
    final writtenEntities = <AgentDomainEntity>[];
    final uiNotifications = <Set<String>>[];

    when(() => generatedSyncService.repository).thenReturn(
      generatedRepository,
    );
    when(
      () => generatedRepository.getEntitiesByAgentId(
        'generated-agent',
        type: AgentEntityTypes.projectRecommendation,
      ),
    ).thenAnswer((_) async => scenario.existingEntities);
    when(() => generatedSyncService.upsertEntity(any())).thenAnswer((
      invocation,
    ) async {
      writtenEntities.add(
        invocation.positionalArguments.single as AgentDomainEntity,
      );
    });
    when(() => generatedNotifications.notifyUiOnly(any())).thenAnswer((
      invocation,
    ) {
      uiNotifications.add(
        Set<String>.from(invocation.positionalArguments.single as Set<String>),
      );
    });
    when(
      () => generatedLogger.log(
        any(),
        any(),
        subDomain: any(named: 'subDomain'),
      ),
    ).thenReturn(null);

    final generatedService = ProjectRecommendationService(
      syncService: generatedSyncService,
      notifications: generatedNotifications,
      domainLogger: generatedLogger,
    );
    final changeSet = makeTestChangeSet(
      id: 'generated-change-set',
      agentId: 'generated-agent',
      taskId: 'generated-project',
    );
    final decision = makeTestChangeDecision(
      id: 'generated-decision',
      agentId: 'generated-agent',
      changeSetId: changeSet.id,
      toolName: 'recommend_next_steps',
      taskId: 'generated-project',
      args: scenario.decisionArgs,
    );

    await withClock(Clock.fixed(hGeneratedRecommendationNow), () async {
      if (scenario.validDrafts.isEmpty) {
        await expectLater(
          () => generatedService.recordConfirmedRecommendations(
            changeSet: changeSet,
            decision: decision,
          ),
          throwsA(isA<ArgumentError>()),
        );
        verifyNever(
          () => generatedRepository.getEntitiesByAgentId(
            any(),
            type: any(named: 'type'),
            limit: any(named: 'limit'),
          ),
        );
        expect(writtenEntities, isEmpty);
        expect(uiNotifications, isEmpty);
        return;
      }

      await generatedService.recordConfirmedRecommendations(
        changeSet: changeSet,
        decision: decision,
      );
    });

    if (scenario.validDrafts.isEmpty) return;

    final superseded = writtenEntities
        .take(scenario.supersededRecommendations.length)
        .cast<ProjectRecommendationEntity>()
        .toList();
    expect(
      superseded.map((entity) => entity.id).toList(),
      scenario.supersededRecommendations.map((entity) => entity.id).toList(),
      reason: '$scenario',
    );
    for (final entity in superseded) {
      expect(entity.status, ProjectRecommendationStatus.superseded);
      expect(entity.updatedAt, hGeneratedRecommendationNow);
      expect(entity.supersededAt, hGeneratedRecommendationNow);
    }

    final created = writtenEntities
        .skip(scenario.supersededRecommendations.length)
        .cast<ProjectRecommendationEntity>()
        .toList();
    expect(created, hasLength(scenario.validDrafts.length));
    for (final (index, draft) in scenario.validDrafts.indexed) {
      final entity = created[index];
      expect(entity.agentId, 'generated-agent');
      expect(entity.projectId, 'generated-project');
      expect(entity.title, draft.title);
      expect(entity.position, index);
      expect(entity.status, ProjectRecommendationStatus.active);
      expect(entity.createdAt, hGeneratedRecommendationNow);
      expect(entity.updatedAt, hGeneratedRecommendationNow);
      expect(entity.sourceChangeSetId, changeSet.id);
      expect(entity.sourceDecisionId, decision.id);
      expect(entity.rationale, draft.rationale);
      expect(entity.priority, draft.priority);
    }

    expect(uiNotifications, [
      {'generated-agent', 'generated-project', agentNotification},
    ]);
  }, tags: 'glados');

  glados.Glados(
    glados.any.recommendationTransitionScenario,
    glados.ExploreConfig(numRuns: 120),
  ).test('matches generated active-only transition semantics', (
    scenario,
  ) async {
    final generatedSyncService = MockAgentSyncService();
    final generatedRepository = MockAgentRepository();
    final generatedNotifications = MockUpdateNotifications();
    final writtenEntities = <AgentDomainEntity>[];
    final uiNotifications = <Set<String>>[];

    when(() => generatedSyncService.repository).thenReturn(
      generatedRepository,
    );
    when(() => generatedRepository.getEntity('generated-rec')).thenAnswer(
      (_) async => scenario.lookupEntity,
    );
    when(() => generatedSyncService.upsertEntity(any())).thenAnswer((
      invocation,
    ) async {
      writtenEntities.add(
        invocation.positionalArguments.single as AgentDomainEntity,
      );
    });
    when(() => generatedNotifications.notifyUiOnly(any())).thenAnswer((
      invocation,
    ) {
      uiNotifications.add(
        Set<String>.from(invocation.positionalArguments.single as Set<String>),
      );
    });

    final generatedService = ProjectRecommendationService(
      syncService: generatedSyncService,
      notifications: generatedNotifications,
    );

    final result = await withClock(
      Clock.fixed(hGeneratedRecommendationNow),
      () => scenario.run(generatedService),
    );

    expect(result, scenario.expectsTransition, reason: '$scenario');
    if (!scenario.expectsTransition) {
      expect(writtenEntities, isEmpty);
      expect(uiNotifications, isEmpty);
      return;
    }

    final updated = writtenEntities.single as ProjectRecommendationEntity;
    expect(updated.status, scenario.expectedStatus);
    expect(updated.updatedAt, hGeneratedRecommendationNow);
    expect(
      updated.resolvedAt,
      scenario.expectedStatus == ProjectRecommendationStatus.resolved
          ? hGeneratedRecommendationNow
          : isNull,
    );
    expect(
      updated.dismissedAt,
      scenario.expectedStatus == ProjectRecommendationStatus.dismissed
          ? hGeneratedRecommendationNow
          : isNull,
    );
    expect(uiNotifications, [
      {'generated-agent', 'generated-project', agentNotification},
    ]);
  }, tags: 'glados');

  test(
    'records active recommendations and supersedes previous active ones',
    () async {
      final changeSet = makeTestChangeSet(
        agentId: 'agent-1',
        taskId: 'project-1',
        items: const [
          ChangeItem(
            toolName: 'recommend_next_steps',
            args: {
              'steps': [
                {'title': 'Verify sync stability with George'},
                {'title': 'Close the project', 'priority': 'high'},
              ],
            },
            humanSummary: 'Recommend next steps',
          ),
        ],
      );
      final decision = makeTestChangeDecision(
        id: 'decision-1',
        agentId: 'agent-1',
        changeSetId: changeSet.id,
        toolName: 'recommend_next_steps',
        taskId: 'project-1',
        args: const {
          'steps': [
            {
              'title': 'Verify sync stability with George',
              'rationale': 'Confirm the fix with the user',
            },
            {'title': 'Close the project', 'priority': 'high'},
          ],
        },
      );
      final existing = makeTestProjectRecommendation(
        id: 'existing',
        agentId: 'agent-1',
        projectId: 'project-1',
        title: 'Old recommendation',
      );

      when(
        () => mockRepository.getEntitiesByAgentId(
          'agent-1',
          type: AgentEntityTypes.projectRecommendation,
        ),
      ).thenAnswer((_) async => [existing]);

      await service.recordConfirmedRecommendations(
        changeSet: changeSet,
        decision: decision,
      );

      final captured = verify(
        () => mockSyncService.upsertEntity(captureAny()),
      ).captured;

      expect(captured, hasLength(3));
      final superseded = captured[0] as ProjectRecommendationEntity;
      final firstActive = captured[1] as ProjectRecommendationEntity;
      final secondActive = captured[2] as ProjectRecommendationEntity;

      expect(superseded.id, 'existing');
      expect(superseded.status, ProjectRecommendationStatus.superseded);
      expect(firstActive.status, ProjectRecommendationStatus.active);
      expect(firstActive.title, 'Verify sync stability with George');
      expect(firstActive.position, 0);
      expect(firstActive.rationale, 'Confirm the fix with the user');
      expect(secondActive.title, 'Close the project');
      expect(secondActive.priority, 'HIGH');
      expect(secondActive.position, 1);

      verify(
        () => mockNotifications.notifyUiOnly(
          {'agent-1', 'project-1', agentNotification},
        ),
      ).called(1);
    },
  );

  test('markResolved updates an active recommendation and notifies', () async {
    final recommendation = makeTestProjectRecommendation(
      id: 'rec-1',
      agentId: 'agent-1',
      projectId: 'project-1',
    );
    when(() => mockRepository.getEntity('rec-1')).thenAnswer(
      (_) async => recommendation,
    );

    final success = await service.markResolved('rec-1');

    expect(success, isTrue);
    final updated =
        verify(
              () => mockSyncService.upsertEntity(captureAny()),
            ).captured.single
            as ProjectRecommendationEntity;
    expect(updated.status, ProjectRecommendationStatus.resolved);
    expect(updated.resolvedAt, isNotNull);
    verify(
      () => mockNotifications.notifyUiOnly(
        {'agent-1', 'project-1', agentNotification},
      ),
    ).called(1);
  });

  test(
    'dismissRecommendation returns false for non-active recommendations',
    () async {
      final dismissed = makeTestProjectRecommendation(
        id: 'rec-1',
        agentId: 'agent-1',
        projectId: 'project-1',
        status: ProjectRecommendationStatus.dismissed,
      );
      when(() => mockRepository.getEntity('rec-1')).thenAnswer(
        (_) async => dismissed,
      );

      final success = await service.dismissRecommendation('rec-1');

      expect(success, isFalse);
      verifyNever(() => mockSyncService.upsertEntity(any()));
      verifyNever(
        () => mockNotifications.notifyUiOnly(any()),
      );
    },
  );

  test(
    'dismissRecommendation updates an active recommendation and notifies',
    () async {
      final recommendation = makeTestProjectRecommendation(
        id: 'rec-2',
        agentId: 'agent-1',
        projectId: 'project-1',
      );
      when(() => mockRepository.getEntity('rec-2')).thenAnswer(
        (_) async => recommendation,
      );

      final success = await service.dismissRecommendation('rec-2');

      expect(success, isTrue);
      final updated =
          verify(
                () => mockSyncService.upsertEntity(captureAny()),
              ).captured.single
              as ProjectRecommendationEntity;
      expect(updated.status, ProjectRecommendationStatus.dismissed);
      expect(updated.dismissedAt, isNotNull);
      verify(
        () => mockNotifications.notifyUiOnly(
          {'agent-1', 'project-1', agentNotification},
        ),
      ).called(1);
    },
  );

  test(
    'recordConfirmedRecommendations throws when no valid steps are provided',
    () async {
      final changeSet = makeTestChangeSet(
        agentId: 'agent-1',
        taskId: 'project-1',
      );
      final decision = makeTestChangeDecision(
        id: 'decision-invalid',
        agentId: 'agent-1',
        changeSetId: changeSet.id,
        toolName: 'recommend_next_steps',
        taskId: 'project-1',
        args: const {
          'steps': [
            {'title': '   '},
            {'rationale': 'missing title'},
            'invalid',
          ],
        },
      );

      await expectLater(
        () => service.recordConfirmedRecommendations(
          changeSet: changeSet,
          decision: decision,
        ),
        throwsA(isA<ArgumentError>()),
      );
      verifyNever(
        () => mockRepository.getEntitiesByAgentId(
          any(),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      );
    },
  );
}
