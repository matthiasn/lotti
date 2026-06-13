import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' as glados;
import 'package:lotti/features/agents/model/agent_config.dart';
import 'package:lotti/features/agents/model/agent_constants.dart';
import 'package:lotti/features/agents/model/agent_domain_entity.dart';
import 'package:lotti/features/agents/model/agent_link.dart';
import 'package:lotti/features/agents/service/project_activity_monitor.dart';
import 'package:lotti/services/db_notification.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/fallbacks.dart';
import '../../../mocks/mocks.dart';
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
  late ProjectActivityMonitor monitor;

  setUp(() {
    notifications = MockUpdateNotifications();
    repository = MockAgentRepository();
    projectRepository = MockProjectRepository();
    syncService = MockAgentSyncService();
    updateController = StreamController<Set<String>>.broadcast();

    when(() => notifications.localUpdateStream).thenAnswer(
      (_) => updateController.stream,
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
  });

  group('ProjectActivityMonitor', () {
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

      verify(
        () => notifications.notifyUiOnly({'agent-1', agentNotification}),
      ).called(1);
    });

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
    });

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
