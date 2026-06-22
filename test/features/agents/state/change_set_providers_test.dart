import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_enums.dart';
import 'package:lotti/features/agents/model/change_set.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/journal/repository/journal_repository.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;

  setUp(() {
    mockRepository = MockAgentRepository();
  });

  /// Builds the standard project-agent container: projectAgent override,
  /// repository override, and (when [agent] + [updateController] are given)
  /// the agent-update stream override. Optionally keeps [listenTo] alive
  /// and registers all disposals via addTearDown.
  ProviderContainer createProjectAgentContainer({
    required String projectId,
    AgentDomainEntity? agent,
    StreamController<Set<String>>? updateController,
    ProviderListenable<Object?>? listenTo,
  }) {
    final container = ProviderContainer(
      overrides: [
        projectAgentProvider(projectId).overrideWith((ref) async => agent),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        if (agent != null && updateController != null)
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
      ],
    );
    addTearDown(container.dispose);
    if (listenTo != null) {
      final sub = container.listen(listenTo, (_, _) {});
      addTearDown(sub.close);
    }
    return container;
  }

  /// Mirror of [createProjectAgentContainer] for the event-scoped providers:
  /// overrides [eventAgentProvider], the repository, and — when [agent] +
  /// [updateController] are given — the agent-update stream.
  ProviderContainer createEventAgentContainer({
    required String eventId,
    AgentDomainEntity? agent,
    StreamController<Set<String>>? updateController,
    ProviderListenable<Object?>? listenTo,
  }) {
    final container = ProviderContainer(
      overrides: [
        eventAgentProvider(eventId).overrideWith((ref) async => agent),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        if (agent != null && updateController != null)
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
      ],
    );
    addTearDown(container.dispose);
    if (listenTo != null) {
      final sub = container.listen(listenTo, (_, _) {});
      addTearDown(sub.close);
    }
    return container;
  }

  group('projectPendingChangeSetsProvider', () {
    test('returns empty list when no agent exists for project', () async {
      final container = createProjectAgentContainer(
        projectId: 'project-001',
        listenTo: projectPendingChangeSetsProvider('project-001'),
      );

      final result = await container.read(
        projectPendingChangeSetsProvider('project-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('fetches change sets from repo when project agent exists', () async {
      final agent = makeTestIdentity();
      final changeSet = makeTestChangeSet(
        agentId: agent.agentId,
        taskId: 'project-001',
      );

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'project-001',
        ),
      ).thenAnswer((_) async => [changeSet]);

      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final container = createProjectAgentContainer(
        projectId: 'project-001',
        agent: agent,
        updateController: updateController,
        listenTo: projectPendingChangeSetsProvider('project-001'),
      );

      final result = await container.read(
        projectPendingChangeSetsProvider('project-001').future,
      );

      expect(result, hasLength(1));
      expect(result[0], isA<ChangeSetEntity>());

      verify(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'project-001',
        ),
      ).called(1);
    });
  });

  group('projectRecommendationsProvider', () {
    test('returns empty list when no project agent exists', () async {
      final container = createProjectAgentContainer(
        projectId: 'project-001',
        listenTo: projectRecommendationsProvider('project-001'),
      );

      final result = await container.read(
        projectRecommendationsProvider('project-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getEntitiesByAgentId(
          any(),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test(
      'returns empty list when project agent is not an identity entity',
      () async {
        final container = createProjectAgentContainer(
          projectId: 'project-001',
          agent: makeTestState(),
          listenTo: projectRecommendationsProvider('project-001'),
        );

        final result = await container.read(
          projectRecommendationsProvider('project-001').future,
        );

        expect(result, isEmpty);
        verifyNever(
          () => mockRepository.getEntitiesByAgentId(
            any(),
            type: any(named: 'type'),
            limit: any(named: 'limit'),
          ),
        );
      },
    );

    test(
      'returns active project recommendations ordered for display',
      () async {
        final agent = makeTestIdentity();
        final updateController = StreamController<Set<String>>.broadcast();
        addTearDown(updateController.close);

        final olderActive = makeTestProjectRecommendation(
          id: 'pr-older',
          agentId: agent.agentId,
          title: 'Older recommendation',
          createdAt: DateTime(2024, 3, 15, 9),
          updatedAt: DateTime(2024, 3, 15, 9),
        );
        final secondInBatch = makeTestProjectRecommendation(
          id: 'pr-second',
          agentId: agent.agentId,
          title: 'Second in latest batch',
          position: 1,
          createdAt: DateTime(2024, 3, 16, 9),
          updatedAt: DateTime(2024, 3, 16, 9),
          priority: null,
          rationale: null,
        );
        final firstInBatch = makeTestProjectRecommendation(
          id: 'pr-first',
          agentId: agent.agentId,
          title: 'First in latest batch',
          createdAt: DateTime(2024, 3, 16, 9),
          updatedAt: DateTime(2024, 3, 16, 9),
          priority: 'MEDIUM',
        );
        final resolved = makeTestProjectRecommendation(
          id: 'pr-resolved',
          agentId: agent.agentId,
          title: 'Resolved recommendation',
          status: ProjectRecommendationStatus.resolved,
        );
        final otherProject = makeTestProjectRecommendation(
          id: 'pr-other-project',
          agentId: agent.agentId,
          projectId: 'project-999',
          title: 'Other project recommendation',
        );

        when(
          () => mockRepository.getEntitiesByAgentId(
            agent.agentId,
            type: AgentEntityTypes.projectRecommendation,
          ),
        ).thenAnswer(
          (_) async => [
            olderActive,
            secondInBatch,
            firstInBatch,
            resolved,
            otherProject,
          ],
        );

        final container = createProjectAgentContainer(
          projectId: 'project-001',
          agent: agent,
          updateController: updateController,
          listenTo: projectRecommendationsProvider('project-001'),
        );

        final result = await container.read(
          projectRecommendationsProvider('project-001').future,
        );

        expect(result, hasLength(3));
        expect(result[0].id, 'pr-first');
        expect(result[1].id, 'pr-second');
        expect(result[2].id, 'pr-older');
      },
    );
  });

  group('projectRecommendationServiceProvider', () {
    test('creates the service when optional notifications are absent', () {
      final mockSyncService = MockAgentSyncService();
      final mockLogger = MockDomainLogger();
      final container = ProviderContainer(
        overrides: [
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          domainLoggerProvider.overrideWithValue(mockLogger),
          maybeUpdateNotificationsProvider.overrideWith((ref) => null),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(projectRecommendationServiceProvider);

      expect(service, isA<ProjectRecommendationService>());
    });
  });

  group('eventPendingChangeSetsProvider', () {
    test('returns empty list when no agent exists for event', () async {
      final container = createEventAgentContainer(
        eventId: 'event-001',
        listenTo: eventPendingChangeSetsProvider('event-001'),
      );

      final result = await container.read(
        eventPendingChangeSetsProvider('event-001').future,
      );

      expect(result, isEmpty);
      verifyNever(
        () => mockRepository.getPendingChangeSets(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test(
      'returns empty list when event agent is not an identity entity',
      () async {
        final container = createEventAgentContainer(
          eventId: 'event-001',
          agent: makeTestState(),
          listenTo: eventPendingChangeSetsProvider('event-001'),
        );

        final result = await container.read(
          eventPendingChangeSetsProvider('event-001').future,
        );

        expect(result, isEmpty);
        verifyNever(
          () => mockRepository.getPendingChangeSets(
            any(),
            taskId: any(named: 'taskId'),
          ),
        );
      },
    );

    test(
      'fetches event change sets keyed on the event id (the taskId field)',
      () async {
        final agent = makeTestIdentity();
        final changeSet = makeTestChangeSet(
          agentId: agent.agentId,
          taskId: 'event-001',
        );

        when(
          () => mockRepository.getPendingChangeSets(
            agent.agentId,
            taskId: 'event-001',
          ),
        ).thenAnswer((_) async => [changeSet]);

        final updateController = StreamController<Set<String>>.broadcast();
        addTearDown(updateController.close);

        final container = createEventAgentContainer(
          eventId: 'event-001',
          agent: agent,
          updateController: updateController,
          listenTo: eventPendingChangeSetsProvider('event-001'),
        );

        final result = await container.read(
          eventPendingChangeSetsProvider('event-001').future,
        );

        expect(result, hasLength(1));
        expect(result.single, isA<ChangeSetEntity>());
        expect((result.single as ChangeSetEntity).taskId, 'event-001');

        verify(
          () => mockRepository.getPendingChangeSets(
            agent.agentId,
            taskId: 'event-001',
          ),
        ).called(1);
      },
    );

    test(
      'deduplicates duplicate pending change sets, keeping the newest',
      () async {
        final agent = makeTestIdentity();
        // Same single pending item in both sets => identical fingerprint, so
        // the dedup must collapse them down to the newer of the two.
        const followUp = ChangeItem(
          toolName: 'suggest_follow_up_task',
          args: {'title': 'Send the recap'},
          humanSummary: 'Suggest follow-up task',
        );
        final older = makeTestChangeSet(
          id: 'cs-older',
          agentId: agent.agentId,
          taskId: 'event-001',
          items: const [followUp],
          createdAt: DateTime(2026, 3, 15, 9),
        );
        final newer = makeTestChangeSet(
          id: 'cs-newer',
          agentId: agent.agentId,
          taskId: 'event-001',
          items: const [followUp],
          createdAt: DateTime(2026, 3, 15, 10),
        );
        // A resolved set (no pending items) is keyed by its own id, so it must
        // survive dedup alongside the surviving duplicate.
        final resolved = makeTestChangeSet(
          id: 'cs-resolved',
          agentId: agent.agentId,
          taskId: 'event-001',
          status: ChangeSetStatus.resolved,
          items: const [
            ChangeItem(
              toolName: 'suggest_follow_up_task',
              args: {'title': 'Already handled'},
              humanSummary: 'Resolved follow-up',
              status: ChangeItemStatus.confirmed,
            ),
          ],
          createdAt: DateTime(2026, 3, 15, 8),
        );

        when(
          () => mockRepository.getPendingChangeSets(
            agent.agentId,
            taskId: 'event-001',
          ),
        ).thenAnswer((_) async => [older, newer, resolved]);

        final updateController = StreamController<Set<String>>.broadcast();
        addTearDown(updateController.close);

        final container = createEventAgentContainer(
          eventId: 'event-001',
          agent: agent,
          updateController: updateController,
          listenTo: eventPendingChangeSetsProvider('event-001'),
        );

        final result = await container.read(
          eventPendingChangeSetsProvider('event-001').future,
        );

        final ids = result.map((e) => e.id).toSet();
        expect(result, hasLength(2));
        expect(ids, containsAll(<String>['cs-newer', 'cs-resolved']));
        expect(ids, isNot(contains('cs-older')));
      },
    );

    test('keeps change sets with distinct fingerprints intact', () async {
      final agent = makeTestIdentity();
      final estimateSet = makeTestChangeSet(
        id: 'cs-estimate',
        agentId: agent.agentId,
        taskId: 'event-001',
        items: const [
          ChangeItem(
            toolName: 'update_task_estimate',
            args: {'minutes': 30},
            humanSummary: 'Set estimate',
          ),
        ],
      );
      final followUpSet = makeTestChangeSet(
        id: 'cs-follow-up',
        agentId: agent.agentId,
        taskId: 'event-001',
        items: const [
          ChangeItem(
            toolName: 'suggest_follow_up_task',
            args: {'title': 'Draft summary'},
            humanSummary: 'Suggest follow-up',
          ),
        ],
      );

      when(
        () => mockRepository.getPendingChangeSets(
          agent.agentId,
          taskId: 'event-001',
        ),
      ).thenAnswer((_) async => [estimateSet, followUpSet]);

      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);

      final container = createEventAgentContainer(
        eventId: 'event-001',
        agent: agent,
        updateController: updateController,
        listenTo: eventPendingChangeSetsProvider('event-001'),
      );

      final result = await container.read(
        eventPendingChangeSetsProvider('event-001').future,
      );

      // Distinct fingerprints => both sets survive dedup untouched.
      expect(result.map((e) => e.id).toSet(), <String>{
        'cs-estimate',
        'cs-follow-up',
      });
    });
  });

  group('deduplicateChangeSets', () {
    test('returns the input unchanged when it has 0 or 1 entries', () {
      expect(deduplicateChangeSets(const []), isEmpty);

      final single = [makeTestChangeSet(id: 'cs-only')];
      expect(deduplicateChangeSets(single), same(single));
    });

    test('keeps non-change-set entities keyed by id and passes them '
        'through', () {
      // The repository only ever yields ChangeSetEntity, but this function is
      // visibleForTesting and takes the broader AgentDomainEntity list, so the
      // non-change-set branch (entity is! ChangeSetEntity) is exercised here
      // directly rather than through the provider.
      final report = makeTestReport(id: 'report-keep');
      final otherReport = makeTestReport(id: 'report-keep-2');
      final changeSet = makeTestChangeSet(id: 'cs-keep');

      final result = deduplicateChangeSets(<AgentDomainEntity>[
        report,
        otherReport,
        changeSet,
      ]);

      expect(result.map((e) => e.id).toSet(), <String>{
        'report-keep',
        'report-keep-2',
        'cs-keep',
      });
    });
  });

  group('eventChangeSetConfirmationServiceProvider', () {
    setUp(() async {
      await setUpTestGetIt(
        additionalSetup: () {
          getIt
            ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
            ..registerSingleton<EntitiesCacheService>(
              MockEntitiesCacheService(),
            );
        },
      );
    });

    tearDown(tearDownTestGetIt);

    test('creates an event-scoped service with resolved dependencies', () {
      final container = ProviderContainer(
        overrides: [
          agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
          journalRepositoryProvider.overrideWithValue(MockJournalRepository()),
          labelsRepositoryProvider.overrideWithValue(MockLabelsRepository()),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(
        eventChangeSetConfirmationServiceProvider,
      );

      expect(service, isA<ChangeSetConfirmationService>());
    });

    test(
      'rejecting a follow-up suggestion records the decision via sync',
      () async {
        final mockSyncService = MockAgentSyncService();
        final changeSet = makeTestChangeSet(
          taskId: 'event-001',
          items: const [
            ChangeItem(
              toolName: 'suggest_follow_up_task',
              args: {'title': 'Send recap'},
              humanSummary: 'Suggest follow-up task',
            ),
          ],
        );

        when(() => mockSyncService.repository).thenReturn(mockRepository);
        when(
          () => mockRepository.getEntity(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockSyncService.upsertEntity(any()),
        ).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            agentSyncServiceProvider.overrideWithValue(mockSyncService),
            journalRepositoryProvider.overrideWithValue(
              MockJournalRepository(),
            ),
            labelsRepositoryProvider.overrideWithValue(MockLabelsRepository()),
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          ],
        );
        addTearDown(container.dispose);

        final service = container.read(
          eventChangeSetConfirmationServiceProvider,
        );
        final applied = await service.rejectItem(changeSet, 0);

        expect(applied, isTrue);
        verify(() => mockSyncService.upsertEntity(any())).called(
          greaterThanOrEqualTo(1),
        );
      },
    );
  });
}
