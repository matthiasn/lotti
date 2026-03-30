import 'package:flutter_test/flutter_test.dart';
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
