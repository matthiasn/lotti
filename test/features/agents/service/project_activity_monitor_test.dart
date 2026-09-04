import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/features/agents/service/project_agent_service.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
import '../../projects/test_utils.dart' as projects;
import '../test_utils.dart';
import 'project_activity_monitor_test_helpers.dart';

void main() {
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 3, 22, 14, 5);
  late MockUpdateNotifications notifications;
  late MockAgentRepository repository;
  late MockProjectRepository projectRepository;
  late MockAgentSyncService syncService;
  late StreamController<Set<String>> updateController;
  late StreamController<Set<String>> syncUpdateController;
  late ProjectActivityMonitor monitor;

  setUp(() {
    notifications = MockUpdateNotifications();
    repository = MockAgentRepository();
    projectRepository = MockProjectRepository();
    syncService = MockAgentSyncService();
    updateController = StreamController<Set<String>>.broadcast();
    syncUpdateController = StreamController<Set<String>>.broadcast();

    when(() => notifications.localUpdateStream).thenAnswer(
      (_) => updateController.stream,
    );
    when(() => notifications.syncUpdateStream).thenAnswer(
      (_) => syncUpdateController.stream,
    );
    when(
      () => notifications.notify(
        any(),
        fromSync: any(named: 'fromSync'),
      ),
    ).thenReturn(null);
    when(() => syncService.upsertEntity(any())).thenAnswer((_) async {});
    when(
      () => projectRepository.resolveAffectedProjectIds(any()),
    ).thenAnswer((invocation) async {
      final affectedIds = invocation.positionalArguments.first as Set<String>;
      return affectedIds.where((id) => id.startsWith('project-')).toSet();
    });
    when(
      () => repository.getEntity(any()),
    ).thenAnswer((_) async => makeTestIdentity(kind: AgentKinds.projectAgent));

    monitor = ProjectActivityMonitor(
      notifications: notifications,
      agentRepository: repository,
      projectRepository: projectRepository,
      syncService: syncService,
      clock: Clock.fixed(now),
    );
  });

  tearDown(() async {
    await monitor.stop();
    await updateController.close();
    await syncUpdateController.close();
  });

  group('ProjectActivityMonitor', () {
    test(
      'retires every linked agent when sync tombstones its project',
      () async {
        final retiredAgentIds = <String>[];
        final tombstoneMonitor = ProjectActivityMonitor(
          notifications: notifications,
          agentRepository: repository,
          projectRepository: projectRepository,
          syncService: syncService,
          retireProjectAgent: (agentId) async {
            retiredAgentIds.add(agentId);
          },
          clock: Clock.fixed(now),
        );
        addTearDown(tombstoneMonitor.stop);
        when(
          () => projectRepository.getProjectById('project-tombstoned'),
        ).thenAnswer((_) async => null);
        when(
          () => repository.getLinksTo(
            'project-tombstoned',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.agentProject(
              id: 'link-1',
              fromId: 'agent-1',
              toId: 'project-tombstoned',
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            ),
            AgentLink.agentProject(
              id: 'link-2',
              fromId: 'agent-2',
              toId: 'project-tombstoned',
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            ),
            AgentLink.agentProject(
              id: 'duplicate-link',
              fromId: 'agent-1',
              toId: 'project-tombstoned',
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            ),
          ],
        );

        tombstoneMonitor.start();
        syncUpdateController.add({
          'project-tombstoned',
          projectNotification,
          labelUsageNotification,
        });
        await pumpEventQueue(times: 3);

        expect(retiredAgentIds, ['agent-1', 'agent-2']);
        verifyNever(() => syncService.upsertEntity(any()));
      },
    );

    test(
      'keeps agents when a project is restored during link lookup',
      () async {
        var restored = false;
        final retired = <String>[];
        final scopes = <Set<String>>[];
        final reconciliationMonitor = ProjectActivityMonitor(
          notifications: notifications,
          agentRepository: repository,
          projectRepository: projectRepository,
          syncService: syncService,
          retireProjectAgent: (id) async => retired.add(id),
          updateProjectAgentScopes: (_, categories) async =>
              scopes.add(categories),
        );
        addTearDown(reconciliationMonitor.stop);
        when(
          () => projectRepository.getProjectById('project-restored'),
        ).thenAnswer(
          (_) async => restored
              ? projects.makeTestProject(
                  id: 'project-restored',
                  categoryId: 'restored-category',
                )
              : null,
        );
        when(
          () => repository.getLinksTo(
            'project-restored',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async {
          restored = true;
          return [
            AgentLink.agentProject(
              id: 'restored-link',
              fromId: 'agent-1',
              toId: 'project-restored',
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            ),
          ];
        });
        reconciliationMonitor.start();
        syncUpdateController.add({'project-restored', projectNotification});
        await pumpEventQueue(times: 3);
        expect(retired, isEmpty);
        expect(scopes, [
          const {'restored-category'},
        ]);
      },
    );

    test(
      'reconciliation waits for the shared project mutation coordinator',
      () async {
        final coordinator = ProjectAgentMutationCoordinator();
        final entered = Completer<void>();
        final release = Completer<void>();
        final blocker = coordinator.run('project-live', () async {
          entered.complete();
          await release.future;
        });
        await entered.future;
        final updates = <Set<String>>[];
        final reconciliationMonitor = ProjectActivityMonitor(
          notifications: notifications,
          agentRepository: repository,
          projectRepository: projectRepository,
          syncService: syncService,
          mutationCoordinator: coordinator,
          updateProjectAgentScopes: (projectId, categories) =>
              coordinator.run(projectId, () async => updates.add(categories)),
        );
        addTearDown(reconciliationMonitor.stop);
        when(() => projectRepository.getProjectById('project-live')).thenAnswer(
          (_) async => projects.makeTestProject(
            id: 'project-live',
            categoryId: 'restored',
          ),
        );
        reconciliationMonitor.start();
        syncUpdateController.add({'project-live', projectNotification});
        await pumpEventQueue(times: 3);
        verifyNever(() => projectRepository.getProjectById('project-live'));
        expect(updates, isEmpty);
        release.complete();
        await blocker;
        await pumpEventQueue(times: 3);
        expect(updates, [
          const {'restored'},
        ]);
      },
    );

    test(
      'a failed synced lookup does not block later project updates',
      () async {
        final updates = <String>[];
        final reconciliationMonitor = ProjectActivityMonitor(
          notifications: notifications,
          agentRepository: repository,
          projectRepository: projectRepository,
          syncService: syncService,
          updateProjectAgentScopes: (id, _) async => updates.add(id),
        );
        addTearDown(reconciliationMonitor.stop);
        when(
          () => projectRepository.getProjectById('project-failed'),
        ).thenThrow(StateError('read failed'));
        when(
          () => projectRepository.getProjectById('project-live'),
        ).thenAnswer((_) async => projects.makeTestProject(id: 'project-live'));
        reconciliationMonitor.start();
        syncUpdateController.add({
          'project-failed',
          'project-live',
          projectNotification,
        });
        await pumpEventQueue(times: 3);
        verify(
          () => projectRepository.getProjectById('project-failed'),
        ).called(1);
        expect(updates, ['project-live']);
      },
    );

    test(
      'continues retiring linked agents after one retirement fails',
      () async {
        final attemptedAgentIds = <String>[];
        final tombstoneMonitor = ProjectActivityMonitor(
          notifications: notifications,
          agentRepository: repository,
          projectRepository: projectRepository,
          syncService: syncService,
          retireProjectAgent: (agentId) async {
            attemptedAgentIds.add(agentId);
            if (agentId == 'agent-1') {
              throw StateError('first retirement failed');
            }
          },
          clock: Clock.fixed(now),
        );
        addTearDown(tombstoneMonitor.stop);
        when(
          () => projectRepository.getProjectById('project-tombstoned'),
        ).thenAnswer((_) async => null);
        when(
          () => repository.getLinksTo(
            'project-tombstoned',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer(
          (_) async => [
            AgentLink.agentProject(
              id: 'link-1',
              fromId: 'agent-1',
              toId: 'project-tombstoned',
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            ),
            AgentLink.agentProject(
              id: 'link-2',
              fromId: 'agent-2',
              toId: 'project-tombstoned',
              createdAt: now,
              updatedAt: now,
              vectorClock: null,
            ),
          ],
        );

        tombstoneMonitor.start();
        syncUpdateController.add({'project-tombstoned', projectNotification});
        await pumpEventQueue(times: 3);

        expect(attemptedAgentIds, ['agent-1', 'agent-2']);
      },
    );

    test(
      're-scopes linked agents when the synced project still exists',
      () async {
        final retiredAgentIds = <String>[];
        final scopeUpdates = <(String, Set<String>)>[];
        final reconciliationMonitor = ProjectActivityMonitor(
          notifications: notifications,
          agentRepository: repository,
          projectRepository: projectRepository,
          syncService: syncService,
          retireProjectAgent: (agentId) async {
            retiredAgentIds.add(agentId);
          },
          updateProjectAgentScopes: (projectId, categoryIds) async {
            scopeUpdates.add((projectId, categoryIds));
          },
          clock: Clock.fixed(now),
        );
        addTearDown(reconciliationMonitor.stop);
        when(
          () => projectRepository.getProjectById('project-live'),
        ).thenAnswer(
          (_) async => projects.makeTestProject(
            id: 'project-live',
            categoryId: 'synced-category',
          ),
        );

        reconciliationMonitor.start();
        syncUpdateController.add({'project-live', projectNotification});
        await pumpEventQueue(times: 3);

        expect(retiredAgentIds, isEmpty);
        expect(scopeUpdates, hasLength(1));
        expect(scopeUpdates.single.$1, 'project-live');
        expect(scopeUpdates.single.$2, {'synced-category'});
        verifyNever(
          () => repository.getLinksTo(
            'project-live',
            type: AgentLinkTypes.agentProject,
          ),
        );
      },
    );

    test(
      'failed cancellation restores eligibility for the older activity batch',
      () async {
        final coordinator = ProjectActivityCancellationCoordinator();
        final observedSequence = coordinator.captureActivity();

        await expectLater(
          coordinator.runCancellation<void>(
            agentId: 'agent-1',
            action: (_) async => throw StateError('rollback'),
          ),
          throwsA(isA<StateError>()),
        );

        var activityPersisted = false;
        final accepted = await coordinator.runActivityWrite(
          agentId: 'agent-1',
          observedSequence: observedSequence,
          action: () async => activityPersisted = true,
        );

        expect(accepted, isTrue);
        expect(activityPersisted, isTrue);
      },
    );

    test(
      'confirmed commit keeps the cutoff when later work throws',
      () async {
        final coordinator = ProjectActivityCancellationCoordinator();
        final observedSequence = coordinator.captureActivity();

        await expectLater(
          coordinator.runCancellation<void>(
            agentId: 'agent-1',
            action: (confirmCommit) async {
              confirmCommit();
              throw StateError('outbox flush failed');
            },
          ),
          throwsA(isA<StateError>()),
        );

        var activityPersisted = false;
        final accepted = await coordinator.runActivityWrite(
          agentId: 'agent-1',
          observedSequence: observedSequence,
          action: () async => activityPersisted = true,
        );

        expect(accepted, isFalse);
        expect(activityPersisted, isFalse);
      },
    );

    test(
      'overlapping failed cancellations leave no stale activity cutoff',
      () async {
        final coordinator = ProjectActivityCancellationCoordinator();
        final observedSequence = coordinator.captureActivity();
        final firstStarted = Completer<void>();
        final releaseFirst = Completer<void>();
        final secondStarted = Completer<void>();
        final releaseSecond = Completer<void>();

        final firstExpectation = expectLater(
          coordinator.runCancellation<void>(
            agentId: 'agent-1',
            action: (_) async {
              firstStarted.complete();
              await releaseFirst.future;
              throw StateError('first rollback');
            },
          ),
          throwsA(isA<StateError>()),
        );
        await firstStarted.future;
        final secondExpectation = expectLater(
          coordinator.runCancellation<void>(
            agentId: 'agent-1',
            action: (_) async {
              secondStarted.complete();
              await releaseSecond.future;
              throw StateError('second rollback');
            },
          ),
          throwsA(isA<StateError>()),
        );

        releaseFirst.complete();
        await firstExpectation;
        await secondStarted.future;
        releaseSecond.complete();
        await secondExpectation;

        var activityPersisted = false;
        final accepted = await coordinator.runActivityWrite(
          agentId: 'agent-1',
          observedSequence: observedSequence,
          action: () async => activityPersisted = true,
        );

        expect(accepted, isTrue);
        expect(activityPersisted, isTrue);
      },
    );

    test(
      'cancellation rejects an older batch still resolving project links',
      () async {
        final coordinator = ProjectActivityCancellationCoordinator();
        final linksStarted = Completer<void>();
        final releaseLinks = Completer<void>();
        final link = AgentLink.agentProject(
          id: 'link-cancel-race',
          fromId: 'agent-1',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        var state = makeTestState(
          agentId: 'agent-1',
          slots: AgentSlots(
            activeProjectId: 'project-1',
            pendingProjectActivityAt: now.subtract(
              const Duration(minutes: 5),
            ),
          ),
          nextWakeAt: now.add(const Duration(minutes: 2)),
          scheduledWakeAt: DateTime(2026, 3, 23, 6),
        );
        when(
          () => repository.getLinksTo(
            'project-1',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async {
          linksStarted.complete();
          await releaseLinks.future;
          return [link];
        });
        when(
          () => repository.getAgentState('agent-1'),
        ).thenAnswer((_) async => state);
        when(() => syncService.upsertEntity(any())).thenAnswer((
          invocation,
        ) async {
          state = invocation.positionalArguments.single as AgentStateEntity;
        });

        final orchestrator = MockWakeOrchestrator();
        when(() => orchestrator.clearThrottle('agent-1')).thenReturn(null);
        when(
          () => orchestrator.cancelPendingWakes(
            'agent-1',
            allWorkspaces: true,
          ),
        ).thenReturn(const []);
        final projectService = ProjectAgentService(
          agentService: MockAgentService(),
          repository: repository,
          orchestrator: orchestrator,
          syncService: syncService,
          projectScopeIsCurrent: (_, _) async => true,
          mutationCoordinator: ProjectAgentMutationCoordinator(),
          cancellationCoordinator: coordinator,
        );
        final raceMonitor = ProjectActivityMonitor(
          notifications: notifications,
          agentRepository: repository,
          projectRepository: projectRepository,
          syncService: syncService,
          clock: Clock.fixed(now),
          cancellationCoordinator: coordinator,
        );
        addTearDown(raceMonitor.stop);

        raceMonitor.start();
        updateController.add({'project-1'});
        await linksStarted.future;

        await withClock(
          Clock.fixed(now.add(const Duration(minutes: 1))),
          () => projectService.cancelScheduledWake('agent-1'),
        );
        releaseLinks.complete();
        await pumpEventQueue(times: 3);

        expect(state.slots.pendingProjectActivityAt, isNull);
        expect(state.nextWakeAt, isNull);
        expect(state.scheduledWakeAt, isNull);
        verify(() => syncService.upsertEntity(any())).called(1);
      },
    );

    glados.Glados(
      glados.any.projectActivityScenario,
      glados.ExploreConfig(numRuns: 180),
    ).test('matches generated project activity marking semantics', (
      scenario,
    ) async {
      final bench = GeneratedProjectActivityBench(scenario);

      try {
        bench.monitor.start();
        bench.controller.add(scenario.affectedIds);
        await pumpEventQueue(times: 4);

        final expectedWrittenAgentIds = <String>[
          for (var i = 0; i < scenario.specs.length; i++)
            if (scenario.resolvedProjectIds.contains(
                  scenario.specs[i].projectId(i),
                ) &&
                scenario.specs[i].hasWritableState)
              scenario.specs[i].primaryAgentId(i),
        ];
        expect(
          bench.writtenStates.map((state) => state.agentId).toList(),
          expectedWrittenAgentIds,
          reason: '$scenario',
        );

        for (final state in bench.writtenStates) {
          final index = scenario.indexForAgentId(state.agentId);
          expect(index, isNonNegative, reason: '$scenario');
          final original = scenario.specs[index].state(index)!;
          expect(
            state.slots.activeProjectId,
            original.slots.activeProjectId,
            reason: '$scenario',
          );
          expect(
            state.slots.pendingProjectActivityAt,
            hGeneratedProjectActivityNow,
            reason: '$scenario',
          );
          expect(
            state.scheduledWakeAt,
            DateTime(2026, 4, 4, 6),
            reason: '$scenario',
          );
          expect(state.updatedAt, hGeneratedProjectActivityNow);
        }

        final expectedUiNotifications = <Set<String>>[
          for (var i = 0; i < scenario.specs.length; i++)
            if (scenario.resolvedProjectIds.contains(
                  scenario.specs[i].projectId(i),
                ) &&
                scenario.specs[i].expectsUiNotification)
              {scenario.specs[i].primaryAgentId(i), agentNotification},
        ];
        expect(
          bench.uiNotifications,
          expectedUiNotifications,
          reason: '$scenario',
        );

        if (scenario.affectedIds.isEmpty) {
          verifyNever(
            () => bench.projectRepository.resolveAffectedProjectIds(any()),
          );
        } else {
          verify(
            () => bench.projectRepository.resolveAffectedProjectIds(
              scenario.affectedIds,
            ),
          ).called(1);
        }
      } finally {
        await bench.dispose();
      }
    }, tags: 'glados');

    test('marks pending activity for linked project agents', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final state = makeTestState(
        agentId: 'agent-1',
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => state);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      final captured =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(captured.slots.activeProjectId, 'project-1');
      expect(captured.slots.pendingProjectActivityAt, now);
      expect(captured.scheduledWakeAt, DateTime(2026, 3, 23, 6));

      verify(
        () => notifications.notifyUiOnly({'agent-1', agentNotification}),
      ).called(1);
    });

    test(
      'preserves a stale watermark written while activity is resolved',
      () async {
        final link = AgentLink.agentProject(
          id: 'link-stale-race',
          fromId: 'agent-1',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final snapshot = makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeProjectId: 'project-1'),
        );
        final staleAt = now.subtract(const Duration(minutes: 1));
        final concurrent = snapshot.copyWith(reportStaleAt: staleAt);
        var stateRead = 0;
        when(
          () => repository.getLinksTo(
            'project-1',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => repository.getAgentState('agent-1'),
        ).thenAnswer((_) async => stateRead++ == 0 ? snapshot : concurrent);

        monitor.start();
        updateController.add({'project-1'});
        await pumpEventQueue(times: 3);

        final persisted =
            verify(
                  () => syncService.upsertEntity(captureAny()),
                ).captured.single
                as AgentStateEntity;
        expect(persisted.reportStaleAt, staleAt);
        expect(persisted.slots.pendingProjectActivityAt, now);
      },
    );

    test(
      'does not rearm activity already covered by a completed wake',
      () async {
        final link = AgentLink.agentProject(
          id: 'link-completed-wake',
          fromId: 'agent-1',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final beforeWake = makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeProjectId: 'project-1'),
        );
        final completedWake = beforeWake.copyWith(
          lastWakeAt: now.add(const Duration(minutes: 1)),
        );
        var stateRead = 0;
        when(
          () => repository.getLinksTo(
            'project-1',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => repository.getAgentState('agent-1'),
        ).thenAnswer(
          (_) async => stateRead++ == 0 ? beforeWake : completedWake,
        );

        monitor.start();
        updateController.add({'project-1'});
        await pumpEventQueue(times: 3);

        verifyNever(() => syncService.upsertEntity(any()));
        verifyNever(
          () => notifications.notifyUiOnly(any()),
        );
      },
    );

    test('resolves project IDs from updated task IDs', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final state = makeTestState(
        agentId: 'agent-1',
        slots: const AgentSlots(activeProjectId: 'project-1'),
      );

      when(
        () => projectRepository.resolveAffectedProjectIds({'task-1'}),
      ).thenAnswer((_) async => {'project-1'});
      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => state);

      monitor.start();

      updateController.add({'task-1'});
      await pumpEventQueue(times: 2);

      final captured =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(captured.slots.pendingProjectActivityAt, now);
      expect(captured.scheduledWakeAt, DateTime(2026, 3, 23, 6));
    });

    test(
      'preserves an existing explicit wake while refreshing activity',
      () async {
        final link = AgentLink.agentProject(
          id: 'link-existing-wake',
          fromId: 'agent-1',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final existingWake = DateTime(2026, 3, 22, 18);
        final state = makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeProjectId: 'project-1'),
          scheduledWakeAt: existingWake,
        );

        when(
          () => repository.getLinksTo(
            'project-1',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => repository.getAgentState('agent-1'),
        ).thenAnswer((_) async => state);

        monitor.start();
        updateController.add({'project-1'});
        await pumpEventQueue(times: 2);

        final captured =
            verify(
                  () => syncService.upsertEntity(captureAny()),
                ).captured.single
                as AgentStateEntity;
        expect(captured.scheduledWakeAt, existingWake);
        expect(captured.slots.pendingProjectActivityAt, now);
      },
    );

    test(
      'marks activity stale without arming a wake when automation is off',
      () async {
        final link = AgentLink.agentProject(
          id: 'link-automation-off',
          fromId: 'agent-1',
          toId: 'project-1',
          createdAt: kAgentTestDate,
          updatedAt: kAgentTestDate,
          vectorClock: null,
        );
        final state = makeTestState(
          agentId: 'agent-1',
          slots: const AgentSlots(activeProjectId: 'project-1'),
        );

        when(
          () => repository.getLinksTo(
            'project-1',
            type: AgentLinkTypes.agentProject,
          ),
        ).thenAnswer((_) async => [link]);
        when(
          () => repository.getAgentState('agent-1'),
        ).thenAnswer((_) async => state);
        when(
          () => repository.getEntity('agent-1'),
        ).thenAnswer(
          (_) async => makeTestIdentity(
            agentId: 'agent-1',
            kind: AgentKinds.projectAgent,
            config: const AgentConfig(automaticUpdatesEnabled: false),
          ),
        );

        monitor.start();
        updateController.add({'project-1'});
        await pumpEventQueue(times: 2);

        final captured =
            verify(
                  () => syncService.upsertEntity(captureAny()),
                ).captured.single
                as AgentStateEntity;
        expect(captured.slots.pendingProjectActivityAt, now);
        expect(captured.scheduledWakeAt, isNull);
      },
    );

    test('skips deleted agents', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final deletedState = makeTestState(
        agentId: 'agent-1',
        slots: const AgentSlots(activeProjectId: 'project-1'),
      ).copyWith(deletedAt: DateTime(2026, 3, 20));

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => deletedState);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('skips when agent state is null', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => null);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('skips when pending activity is already set in the future', () async {
      final link = AgentLink.agentProject(
        id: 'link-1',
        fromId: 'agent-1',
        toId: 'project-1',
        createdAt: kAgentTestDate,
        updatedAt: kAgentTestDate,
        vectorClock: null,
      );
      final futureActivity = now.add(const Duration(hours: 1));
      final state = makeTestState(
        agentId: 'agent-1',
        slots: AgentSlots(
          activeProjectId: 'project-1',
          pendingProjectActivityAt: futureActivity,
        ),
      );

      when(
        () => repository.getLinksTo(
          'project-1',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => [link]);
      when(
        () => repository.getAgentState('agent-1'),
      ).thenAnswer((_) async => state);

      monitor.start();

      updateController.add({'project-1'});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('handles errors gracefully without domainLogger', () async {
      when(
        () => repository.getLinksTo(
          'project-err',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenThrow(Exception('DB down'));

      monitor.start();

      updateController.add({'project-err'});
      await pumpEventQueue(times: 2);

      // Should not crash — error is caught and logged via developer.log
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('handles errors gracefully with domainLogger', () async {
      final mockLogger = MockDomainLogger();
      when(
        () => mockLogger.error(
          any(),
          any(),
          message: any(named: 'message'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      final loggedMonitor = ProjectActivityMonitor(
        notifications: notifications,
        agentRepository: repository,
        projectRepository: projectRepository,
        syncService: syncService,
        domainLogger: mockLogger,
        clock: Clock.fixed(now),
      );

      when(
        () => repository.getLinksTo(
          'project-err2',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenThrow(Exception('DB down'));

      loggedMonitor.start();

      updateController.add({'project-err2'});
      await pumpEventQueue(times: 2);

      verify(
        () => mockLogger.error(
          any(),
          any(),
          message: any(
            named: 'message',
            that: contains('failed to mark project activity'),
          ),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);

      await loggedMonitor.stop();
    });

    test('ignores empty affected IDs batch', () async {
      monitor.start();

      updateController.add(<String>{});
      await pumpEventQueue();

      verifyNever(
        () => projectRepository.resolveAffectedProjectIds(any()),
      );
      verifyNever(
        () => repository.getLinksTo(
          any(),
          type: any(named: 'type'),
        ),
      );
    });

    test('ignores affected ids that do not map to project agents', () async {
      when(
        () =>
            projectRepository.resolveAffectedProjectIds({projectNotification}),
      ).thenAnswer((_) async => {});

      monitor.start();

      updateController.add({projectNotification});
      await pumpEventQueue(times: 2);

      verifyNever(() => syncService.upsertEntity(any()));
      verifyNever(
        () => notifications.notify(
          any(),
          fromSync: any(named: 'fromSync'),
        ),
      );
    });
  });
}
