import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  setUpAll(registerAllFallbackValues);

  final now = DateTime(2026, 3, 22, 14, 5);
  late MockUpdateNotifications notifications;
  late MockAgentRepository repository;
  late MockAgentSyncService syncService;
  late StreamController<Set<String>> updateController;
  late ProjectActivityMonitor monitor;

  setUp(() {
    notifications = MockUpdateNotifications();
    repository = MockAgentRepository();
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

    monitor = ProjectActivityMonitor(
      notifications: notifications,
      agentRepository: repository,
      syncService: syncService,
      clock: Clock.fixed(now),
    );
  });

  tearDown(() async {
    await monitor.stop();
    await updateController.close();
  });

  group('ProjectActivityMonitor', () {
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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final captured =
          verify(
                () => syncService.upsertEntity(captureAny()),
              ).captured.single
              as AgentStateEntity;
      expect(captured.slots.activeProjectId, 'project-1');
      expect(captured.slots.pendingProjectActivityAt, now);
      expect(captured.revision, state.revision + 1);

      verify(
        () => notifications.notify(
          {'agent-1', agentNotification},
          fromSync: true,
        ),
      ).called(1);
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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      // Should not crash — error is caught and logged via developer.log
      verifyNever(() => syncService.upsertEntity(any()));
    });

    test('handles errors gracefully with domainLogger', () async {
      final mockLogger = MockDomainLogger();
      when(
        () => mockLogger.error(
          any(),
          any(),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).thenReturn(null);

      final loggedMonitor = ProjectActivityMonitor(
        notifications: notifications,
        agentRepository: repository,
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
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => mockLogger.error(
          any(),
          any(that: contains('failed to mark project activity')),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          subDomain: any(named: 'subDomain'),
        ),
      ).called(1);

      await loggedMonitor.stop();
    });

    test('ignores empty affected IDs batch', () async {
      monitor.start();

      updateController.add(<String>{});
      await Future<void>.delayed(Duration.zero);

      verifyNever(
        () => repository.getLinksTo(
          any(),
          type: any(named: 'type'),
        ),
      );
    });

    test('ignores affected ids that do not map to project agents', () async {
      when(
        () => repository.getLinksTo(
          'PROJECT',
          type: AgentLinkTypes.agentProject,
        ),
      ).thenAnswer((_) async => []);

      monitor.start();

      updateController.add({projectNotification});
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

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
