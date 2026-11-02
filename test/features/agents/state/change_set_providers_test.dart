import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lotti/classes/agents/agent_constants.dart';
import 'package:lotti/classes/agents/agent_domain_entity.dart';
import 'package:lotti/classes/agents/agent_enums.dart';
import 'package:lotti/classes/agents/change_set.dart';
import 'package:lotti/classes/agents/proposal_ledger.dart';
import 'package:lotti/features/agents/service/change_set_confirmation_service.dart';
import 'package:lotti/features/agents/service/project_proposal_service.dart';
import 'package:lotti/features/agents/service/project_recommendation_service.dart';
import 'package:lotti/features/agents/state/agent_providers.dart';
import 'package:lotti/features/agents/state/change_set_providers.dart';
import 'package:lotti/features/agents/state/event_agent_providers.dart';
import 'package:lotti/features/agents/state/project_agent_providers.dart';
import 'package:lotti/features/agents/state/task_agent_providers.dart';
import 'package:lotti/features/labels/repository/labels_repository.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/logic/repositories/journal_repository.dart';
import 'package:lotti/logic/repositories/project_repository.dart';
import 'package:lotti/providers/agent_repository_providers.dart';
import 'package:lotti/providers/service_providers.dart'
    show domainLoggerProvider, journalDbProvider;
import 'package:lotti/providers/update_notifications_providers.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:lotti/services/entities_cache_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../helpers/service_overrides.dart';
import '../../../mocks/mocks.dart';
import '../../../widget_test_utils.dart';
import '../../projects/test_utils.dart';
import '../../relationships/helpers/test_people.dart';
import '../test_utils.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  late MockAgentRepository mockRepository;
  late MockProjectRecommendationService recommendations;

  setUp(() {
    mockRepository = MockAgentRepository();
    recommendations = MockProjectRecommendationService();
    when(
      () => recommendations.currentRunSnapshot(any(), any()),
    ).thenAnswer((_) async => const ProjectNextStepsSnapshot.empty());
    when(
      () => recommendations.migratePendingBatches(any(), any()),
    ).thenAnswer((_) async {});
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
      overrides: withServiceOverrides([
        projectAgentProvider(projectId).overrideWith((ref) async => agent),
        projectRecommendationServiceProvider.overrideWithValue(recommendations),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        if (agent != null && updateController != null)
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
      ]),
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
    MockJournalRepository? journal,
    StreamController<Set<String>>? notifications,
  }) {
    final updates = MockUpdateNotifications();
    when(() => updates.updateStream).thenAnswer(
      (_) => notifications?.stream ?? const Stream<Set<String>>.empty(),
    );
    final container = ProviderContainer(
      overrides: withServiceOverrides([
        eventAgentProvider(eventId).overrideWith((ref) async => agent),
        agentRepositoryProvider.overrideWithValue(mockRepository),
        updateNotificationsProvider.overrideWithValue(updates),
        journalRepositoryProvider.overrideWithValue(
          journal ?? MockJournalRepository(),
        ),
        if (agent != null && updateController != null)
          agentUpdateStreamProvider(agent.agentId).overrideWith(
            (ref) => updateController.stream,
          ),
      ]),
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

  group('projectNextStepsProvider', () {
    test('returns an empty snapshot when no project agent exists', () async {
      final container = createProjectAgentContainer(
        projectId: 'project-001',
        listenTo: projectNextStepsProvider('project-001'),
      );

      final result = await container.read(
        projectNextStepsProvider('project-001').future,
      );

      expect(result.isEmpty, isTrue);
      verifyNever(
        () => mockRepository.getEntitiesByAgentId(
          any(),
          type: any(named: 'type'),
          limit: any(named: 'limit'),
        ),
      );
    });

    test(
      'returns an empty snapshot when project agent is not an identity entity',
      () async {
        final container = createProjectAgentContainer(
          projectId: 'project-001',
          agent: makeTestState(),
          listenTo: projectNextStepsProvider('project-001'),
        );

        final result = await container.read(
          projectNextStepsProvider('project-001').future,
        );

        expect(result.isEmpty, isTrue);
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
      'passes the newest run snapshot through for display',
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
        when(
          () => recommendations.currentRunSnapshot(
            agent.agentId,
            'project-001',
          ),
        ).thenAnswer(
          (_) async => ProjectNextStepsSnapshot(
            steps: [firstInBatch, secondInBatch, olderActive],
            runCreatedAt: DateTime(2024, 3, 16, 9),
          ),
        );

        final container = createProjectAgentContainer(
          projectId: 'project-001',
          agent: agent,
          updateController: updateController,
          listenTo: projectNextStepsProvider('project-001'),
        );

        final result = await container.read(
          projectNextStepsProvider('project-001').future,
        );

        expect(
          result.steps.map((step) => step.id),
          ['pr-first', 'pr-second', 'pr-older'],
          reason: 'The service owns the order; the provider passes it through.',
        );
        expect(result.runCreatedAt, DateTime(2024, 3, 16, 9));
        expect(result.pending.map((step) => step.id), contains('pr-older'));
      },
    );
  });

  group('projectProposalServiceProvider', () {
    ProviderContainer build({
      MockJournalRepository? journal,
      MockJournalDb? journalDb,
    }) {
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          journalDbProvider.overrideWithValue(journalDb ?? MockJournalDb()),
          journalRepositoryProvider.overrideWithValue(
            journal ?? MockJournalRepository(),
          ),
          projectRepositoryProvider.overrideWithValue(MockProjectRepository()),
          projectChangeSetConfirmationServiceProvider.overrideWithValue(
            MockChangeSetConfirmationService(),
          ),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ]),
      );
      addTearDown(container.dispose);
      return container;
    }

    test('wires the project confirmation service and repository', () {
      final container = build();

      final service = container.read(projectProposalServiceProvider);

      expect(service, isA<ProjectProposalService>());
      expect(
        service.confirmation,
        same(container.read(projectChangeSetConfirmationServiceProvider)),
      );
      expect(
        service.projectRepository,
        same(container.read(projectRepositoryProvider)),
      );
      expect(
        container.read(projectProposalServiceProvider),
        same(service),
        reason: 'kept alive, so undo memos survive page rebuilds',
      );
    });

    // The delete reports whether its tombstone landed; a task that was gone
    // before the call is gone too, which keeps an Undo's retry safe after a
    // failed reopen (ADR 0097).
    for (final (deleted, stillThere, gone) in [
      (true, false, true),
      (false, false, true),
      (false, true, false),
    ]) {
      test(
        'removes a task through the journal: delete '
        '${deleted ? 'stored' : 'not stored'}, task '
        '${stillThere ? 'still there' : 'gone'} — reports ${gone ? 'success' : 'failure'}',
        () async {
          final journal = MockJournalRepository();
          final journalDb = MockJournalDb();
          when(
            () => journal.deleteJournalEntity('task-1'),
          ).thenAnswer((_) async => deleted);
          when(() => journalDb.journalEntityById('task-1')).thenAnswer(
            (_) async => stillThere ? makeTestTask(id: 'task-1') : null,
          );
          final container = build(journal: journal, journalDb: journalDb);

          final service = container.read(projectProposalServiceProvider);

          expect(await service.taskRemover('task-1'), gone);
          verify(() => journal.deleteJournalEntity('task-1')).called(1);
        },
      );
    }
  });

  group('projectRecommendationServiceProvider', () {
    test(
      'task creation dispatches to the owning project and reports lookup failure',
      () async {
        final sync = MockAgentSyncService();
        final projects = MockProjectRepository();
        var row = makeTestProjectRecommendation(
          id: 'step-1',
          projectId: 'project-1',
        );
        when(() => sync.repository).thenReturn(mockRepository);
        when(
          () => mockRepository.getEntity('step-1'),
        ).thenAnswer((_) async => row);
        when(
          () => mockRepository.getLatestReport(any(), any()),
        ).thenAnswer((_) async => null);
        when(
          () => mockRepository.getEntitiesByAgentId(
            any(),
            type: AgentEntityTypes.projectRecommendationRun,
          ),
        ).thenAnswer((_) async => []);
        when(() => sync.upsertEntity(any())).thenAnswer((call) async {
          row = call.positionalArguments.first as ProjectRecommendationEntity;
        });
        when(
          () => projects.getProjectById('project-1'),
        ).thenAnswer((_) async => null);
        await setUpTestGetIt(
          additionalSetup: () {
            getIt
              ..registerSingleton<PersistenceLogic>(MockPersistenceLogic())
              ..registerSingleton<EntitiesCacheService>(
                MockEntitiesCacheService(),
              );
          },
        );
        addTearDown(tearDownTestGetIt);
        final container = ProviderContainer(
          overrides: withServiceOverrides([
            agentSyncServiceProvider.overrideWithValue(sync),
            journalDbProvider.overrideWithValue(MockJournalDb()),
            projectRepositoryProvider.overrideWithValue(projects),
            taskAgentServiceProvider.overrideWithValue(MockTaskAgentService()),
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
            maybeUpdateNotificationsProvider.overrideWith((ref) => null),
          ]),
        );
        addTearDown(container.dispose);
        final result = await container
            .read(projectRecommendationServiceProvider)
            .createTask('step-1');
        expect(result.success, isFalse);
        expect(result.errorMessage, 'Project lookup failed');
        expect(row.status, ProjectRecommendationStatus.active);
        verify(() => projects.getProjectById('project-1')).called(1);
      },
    );

    test('creates the service when optional notifications are absent', () {
      final mockSyncService = MockAgentSyncService();
      final mockLogger = MockDomainLogger();
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          agentSyncServiceProvider.overrideWithValue(mockSyncService),
          domainLoggerProvider.overrideWithValue(mockLogger),
          maybeUpdateNotificationsProvider.overrideWith((ref) => null),
        ]),
      );
      addTearDown(container.dispose);

      final service = container.read(projectRecommendationServiceProvider);

      expect(service, isA<ProjectRecommendationService>());
    });

    // The delete reports whether its tombstone landed; a task that was gone
    // before the call is gone too, which keeps an Undo's retry safe after a
    // failed reopen (ADR 0097).
    for (final (deleted, stillThere, gone) in [
      (true, false, true),
      (false, false, true),
      (false, true, false),
    ]) {
      test(
        'undoing a created task deletes it through the journal: delete '
        '${deleted ? 'stored' : 'not stored'}, task '
        '${stillThere ? 'still there' : 'gone'} — reports ${gone ? 'success' : 'failure'}',
        () async {
          final journal = MockJournalRepository();
          final journalDb = MockJournalDb();
          when(
            () => journal.deleteJournalEntity('task-1'),
          ).thenAnswer((_) async => deleted);
          when(() => journalDb.journalEntityById('task-1')).thenAnswer(
            (_) async => stillThere ? makeTestTask(id: 'task-1') : null,
          );
          final container = ProviderContainer(
            overrides: withServiceOverrides([
              agentSyncServiceProvider.overrideWithValue(
                MockAgentSyncService(),
              ),
              domainLoggerProvider.overrideWithValue(MockDomainLogger()),
              maybeUpdateNotificationsProvider.overrideWith((ref) => null),
              journalRepositoryProvider.overrideWithValue(journal),
              journalDbProvider.overrideWithValue(journalDb),
            ]),
          );
          addTearDown(container.dispose);

          final service = container.read(projectRecommendationServiceProvider);

          expect(await service.taskRemover!('task-1'), gone);
          verify(() => journal.deleteJournalEntity('task-1')).called(1);
        },
      );
    }
  });

  group('eventSuggestionListProvider', () {
    test('is empty, reading no ledger, when the event has no agent', () async {
      final container = createEventAgentContainer(
        eventId: 'event-001',
        listenTo: eventSuggestionListProvider('event-001'),
      );

      final result = await container.read(
        eventSuggestionListProvider('event-001').future,
      );

      expect(result.open, isEmpty);
      expect(result.activity, isEmpty);
      verifyNever(
        () => mockRepository.getProposalLedger(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('is empty when the event agent is not an identity entity', () async {
      final container = createEventAgentContainer(
        eventId: 'event-001',
        agent: makeTestState(),
        listenTo: eventSuggestionListProvider('event-001'),
      );

      final result = await container.read(
        eventSuggestionListProvider('event-001').future,
      );

      expect(result.open, isEmpty);
      verifyNever(
        () => mockRepository.getProposalLedger(
          any(),
          taskId: any(named: 'taskId'),
        ),
      );
    });

    test('reads the ledger keyed on the event id: pending items become rows, '
        'a repeat shows once, the resolved ones are the history', () async {
      final agent = makeTestIdentity(displayName: 'Gala recap');
      const person = ChangeItem(
        toolName: 'suggest_person',
        args: {'personId': 'pip', 'personName': 'Pip Penguin'},
        humanSummary: 'Add Pip Penguin to the event',
      );
      final first = makeTestChangeSet(
        id: 'cs-1',
        agentId: agent.agentId,
        taskId: 'event-001',
        items: const [
          person,
          ChangeItem(
            toolName: 'suggest_follow_up_task',
            args: {'title': 'Share the album'},
            humanSummary: 'Follow-up task: Share the album',
            status: ChangeItemStatus.confirmed,
          ),
        ],
      );
      // The same suggestion again from a later wake: shown once.
      final repeat = makeTestChangeSet(
        id: 'cs-2',
        agentId: agent.agentId,
        taskId: 'event-001',
        items: const [person],
      );
      final resolved = makeLedgerEntry(
        changeSetId: 'cs-1',
        itemIndex: 1,
        toolName: 'suggest_follow_up_task',
        status: ChangeItemStatus.confirmed,
      );
      when(
        () => mockRepository.getProposalLedger(
          agent.agentId,
          taskId: 'event-001',
        ),
      ).thenAnswer(
        (_) async => ProposalLedger(
          open: const [],
          resolved: [resolved],
          pendingSets: [first, repeat],
        ),
      );

      final journal = MockJournalRepository();
      when(journal.getRelationships).thenAnswer(
        (_) async => [makeTestPerson(id: 'pip', title: 'Pip Penguin')],
      );
      final updateController = StreamController<Set<String>>.broadcast();
      addTearDown(updateController.close);
      final container = createEventAgentContainer(
        eventId: 'event-001',
        agent: agent,
        updateController: updateController,
        listenTo: eventSuggestionListProvider('event-001'),
        journal: journal,
      );

      final result = await container.read(
        eventSuggestionListProvider('event-001').future,
      );

      expect(result.open, hasLength(1));
      final row = result.open.single;
      expect(row.changeSet.id, 'cs-1');
      expect(row.itemIndex, 0);
      expect(row.item.toolName, 'suggest_person');
      expect(row.fingerprint, ChangeItem.fingerprint(person));
      expect(result.activity, [resolved]);
      expect(result.agentName, 'Gala recap');
    });

    test('reads no people while nothing proposed names one', () async {
      final agent = makeTestIdentity();
      when(
        () => mockRepository.getProposalLedger(
          agent.agentId,
          taskId: 'event-001',
        ),
      ).thenAnswer(
        (_) async => ProposalLedger(
          open: const [],
          resolved: const [],
          pendingSets: [
            makeTestChangeSet(
              agentId: agent.agentId,
              taskId: 'event-001',
              items: const [
                ChangeItem(
                  toolName: 'suggest_follow_up_task',
                  args: {'title': 'Share the album'},
                  humanSummary: 'Follow-up task: Share the album',
                ),
              ],
            ),
          ],
        ),
      );
      final journal = MockJournalRepository();
      final container = createEventAgentContainer(
        eventId: 'event-001',
        agent: agent,
        listenTo: eventSuggestionListProvider('event-001'),
        journal: journal,
      );

      final result = await container.read(
        eventSuggestionListProvider('event-001').future,
      );

      expect(result.open, hasLength(1));
      verifyNever(journal.getRelationships);
    });

    test('a person hidden as private leaves the card, rows and history, '
        'and comes back when private entries are shown', () async {
      final agent = makeTestIdentity();
      const oona = ChangeItem(
        toolName: 'suggest_person',
        args: {'personId': 'oona', 'personName': 'Oona'},
        humanSummary: 'Add Oona to the event',
      );
      final dismissedOona = makeLedgerEntry(
        changeSetId: 'cs-old',
        toolName: 'suggest_person',
        args: const {'personId': 'oona', 'personName': 'Oona'},
        status: ChangeItemStatus.rejected,
      );
      final dismissedGone = makeLedgerEntry(
        changeSetId: 'cs-older',
        toolName: 'suggest_person',
        args: const {'personId': 'gone', 'personName': 'Gone'},
        status: ChangeItemStatus.rejected,
      );
      when(
        () => mockRepository.getProposalLedger(
          agent.agentId,
          taskId: 'event-001',
        ),
      ).thenAnswer(
        (_) async => ProposalLedger(
          open: const [],
          resolved: [dismissedOona, dismissedGone],
          pendingSets: [
            makeTestChangeSet(
              agentId: agent.agentId,
              taskId: 'event-001',
              items: const [oona],
            ),
          ],
        ),
      );
      // Oona is private: absent from the filtered read while hidden. Gone
      // was deleted and stays out either way.
      var privateShown = false;
      final journal = MockJournalRepository();
      when(journal.getRelationships).thenAnswer(
        (_) async => [
          if (privateShown) makeTestPerson(id: 'oona', title: 'Oona'),
          makeTestPerson(id: 'gone', title: 'Gone', deletedAt: DateTime(2026)),
        ],
      );
      final notifications = StreamController<Set<String>>.broadcast();
      addTearDown(notifications.close);
      final container = createEventAgentContainer(
        eventId: 'event-001',
        agent: agent,
        listenTo: eventSuggestionListProvider('event-001'),
        journal: journal,
        notifications: notifications,
      );

      final hidden = await container.read(
        eventSuggestionListProvider('event-001').future,
      );
      expect(hidden.open, isEmpty);
      expect(hidden.activity, isEmpty);

      privateShown = true;
      notifications.add({privateToggleNotification});
      await pumpEventQueue();
      final shown = await container.read(
        eventSuggestionListProvider('event-001').future,
      );

      expect(shown.open.single.item, oona);
      expect(shown.activity, [dismissedOona]);
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
        overrides: withServiceOverrides([
          agentSyncServiceProvider.overrideWithValue(MockAgentSyncService()),
          journalDbProvider.overrideWithValue(MockJournalDb()),
          journalRepositoryProvider.overrideWithValue(MockJournalRepository()),
          labelsRepositoryProvider.overrideWithValue(MockLabelsRepository()),
          domainLoggerProvider.overrideWithValue(MockDomainLogger()),
        ]),
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
          overrides: withServiceOverrides([
            agentSyncServiceProvider.overrideWithValue(mockSyncService),
            journalDbProvider.overrideWithValue(MockJournalDb()),
            journalRepositoryProvider.overrideWithValue(
              MockJournalRepository(),
            ),
            labelsRepositoryProvider.overrideWithValue(MockLabelsRepository()),
            domainLoggerProvider.overrideWithValue(MockDomainLogger()),
          ]),
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
  group('selfTargetedPendingChangeSetsProvider', () {
    test('reads sets targeting the agent itself, deduplicated, and refetches '
        'on an agent update', () async {
      const agentId = 'goal-agent-001';
      const revision = ChangeItem(
        toolName: 'propose_goal_revision',
        args: {'title': 'Waddle to the feeder daily'},
        humanSummary: 'Revise the goal',
      );
      final older = makeTestChangeSet(
        id: 'cs-older',
        agentId: agentId,
        taskId: agentId,
        items: const [revision],
        createdAt: DateTime(2026, 3, 15, 9),
      );
      final newer = makeTestChangeSet(
        id: 'cs-newer',
        agentId: agentId,
        taskId: agentId,
        items: const [revision],
        createdAt: DateTime(2026, 3, 15, 10),
      );
      when(
        () => mockRepository.getPendingChangeSets(agentId, taskId: agentId),
      ).thenAnswer((_) async => [older, newer]);
      final updates = StreamController<Set<String>>.broadcast();
      addTearDown(updates.close);
      final container = ProviderContainer(
        overrides: withServiceOverrides([
          agentRepositoryProvider.overrideWithValue(mockRepository),
          agentUpdateStreamProvider(agentId).overrideWith(
            (ref) => updates.stream,
          ),
        ]),
      );
      addTearDown(container.dispose);
      final sub = container.listen(
        selfTargetedPendingChangeSetsProvider(agentId),
        (_, _) {},
      );
      addTearDown(sub.close);

      final result = await container.read(
        selfTargetedPendingChangeSetsProvider(agentId).future,
      );
      expect(result.map((e) => e.id), ['cs-newer']);

      updates.add({agentId});
      await container.read(
        selfTargetedPendingChangeSetsProvider(agentId).future,
      );
      await pumpEventQueue();
      verify(
        () => mockRepository.getPendingChangeSets(agentId, taskId: agentId),
      ).called(2);
    });
  });
}
